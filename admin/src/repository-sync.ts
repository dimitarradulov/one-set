import { catalogSourceFiles } from '../../worker/src/catalog-generation';
import { validateCatalogSource } from '../../worker/src/catalog-validation';
import type { DashboardEnvironment } from './dashboard';

export interface RepositorySyncEnvironment extends DashboardEnvironment {
  CATALOG_REPOSITORY_OWNER?: string;
  CATALOG_REPOSITORY_NAME?: string;
  CATALOG_REPOSITORY_BRANCH?: string;
  CATALOG_REPOSITORY_TOKEN?: string;
}

export interface RepositorySyncDependencies {
  apiFetch?: typeof fetch;
  githubFetch?: typeof fetch;
  beforeReferenceUpdate?: () => Promise<void>;
}

export interface RepositorySyncResult {
  status: 'synchronized' | 'failed' | 'superseded';
  publicationID: string;
  commitSHA?: string;
  detail?: string;
}

interface PublishedOperation {
  publication_id: string;
  source_fingerprint: string;
  source: unknown;
  is_current: boolean;
  current_publication_id?: string | null;
  repository_sync_status: string;
  repository_commit_sha?: string | null;
}

function repoConfig(environment: RepositorySyncEnvironment) {
  const owner = environment.CATALOG_REPOSITORY_OWNER?.trim();
  const repository = environment.CATALOG_REPOSITORY_NAME?.trim();
  const branch = environment.CATALOG_REPOSITORY_BRANCH?.trim();
  const token = environment.CATALOG_REPOSITORY_TOKEN;
  if (!owner || !repository || !branch || !token) return undefined;
  if (!/^[A-Za-z0-9_.-]+$/.test(owner) || !/^[A-Za-z0-9_.-]+$/.test(repository)
    || branch.startsWith('-') || branch.includes('..') || branch.includes(' ')) return undefined;
  return { owner, repository, branch, token };
}

function apiBase(environment: DashboardEnvironment): string | undefined {
  const base = environment.CATALOG_API_BASE_URL?.trim().replace(/\/$/, '');
  return base || undefined;
}

async function apiRequest(path: string, environment: RepositorySyncEnvironment, fetcher: typeof fetch,
  init: RequestInit = {}): Promise<Response> {
  const base = apiBase(environment);
  if (!base || !environment.CATALOG_PUBLISH_TOKEN) throw new Error('The catalog publication service is not configured.');
  return fetcher(`${base}${path}`, {
    ...init,
    headers: {
      Authorization: `Bearer ${environment.CATALOG_PUBLISH_TOKEN}`,
      ...(init.body ? { 'Content-Type': 'application/json' } : {}),
      ...init.headers,
    },
  });
}

async function operation(publicationID: string, environment: RepositorySyncEnvironment,
  fetcher: typeof fetch): Promise<PublishedOperation> {
  const response = await apiRequest(`/v1/maintenance/catalog/publications/${encodeURIComponent(publicationID)}`,
    environment, fetcher);
  if (!response.ok) throw new Error(`Could not load published catalog ${publicationID} (${response.status}).`);
  return await response.json() as PublishedOperation;
}

async function status(publicationID: string, next: 'in_progress' | 'synchronized' | 'failed',
  environment: RepositorySyncEnvironment, fetcher: typeof fetch, commitSHA?: string, detail?: string): Promise<boolean> {
  const response = await apiRequest(`/v1/maintenance/catalog/publications/${encodeURIComponent(publicationID)}/repository-sync`,
    environment, fetcher, {
      method: 'POST', body: JSON.stringify({ status: next, repository_commit_sha: commitSHA, error: detail }),
    });
  return response.ok;
}

async function github(path: string, config: NonNullable<ReturnType<typeof repoConfig>>, fetcher: typeof fetch,
  init: RequestInit = {}): Promise<Response> {
  return fetcher(`https://api.github.com/repos/${encodeURIComponent(config.owner)}/${encodeURIComponent(config.repository)}${path}`,
    {
      ...init,
      headers: {
        Authorization: `Bearer ${config.token}`,
        'User-Agent': 'OneSetCatalogDashboard',
        Accept: 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        ...(init.body ? { 'Content-Type': 'application/json' } : {}),
        ...init.headers,
      },
    });
}

async function githubJSON<T>(response: Response, action: string): Promise<T> {
  if (!response.ok) throw new Error(`${action} failed (${response.status}).`);
  return await response.json() as T;
}

function branchRef(branch: string): string {
  return `/git/ref/heads/${branch.split('/').map(encodeURIComponent).join('/')}`;
}

function updateBranchRef(branch: string): string {
  return `/git/refs/heads/${branch.split('/').map(encodeURIComponent).join('/')}`;
}

async function existingMarker(config: NonNullable<ReturnType<typeof repoConfig>>, fetcher: typeof fetch,
  headSHA: string): Promise<{ marker?: { publication_id?: string; source_fingerprint?: string }; programPaths: string[] }> {
  const tree = await githubJSON<{ tree?: Array<{ path: string; sha: string }> }>(
    await github(`/git/trees/${encodeURIComponent(headSHA)}?recursive=1`, config, fetcher), 'Read repository tree');
  const programPaths = (tree.tree ?? []).map(item => item.path)
    .filter(path => /^worker\/catalog\/programs\/[^/]+\.yaml$/.test(path));
  const marker = tree.tree?.find(item => item.path === 'worker/catalog/.publication.json');
  if (!marker) return { programPaths };
  const blob = await githubJSON<{ content?: string; encoding?: string }>(
    await github(`/git/blobs/${encodeURIComponent(marker.sha)}`, config, fetcher), 'Read publication marker');
  if (blob.encoding !== 'base64' || !blob.content) return { programPaths };
  try {
    const bytes = Uint8Array.from(atob(blob.content.replace(/\s/g, '')), character => character.charCodeAt(0));
    return { marker: JSON.parse(new TextDecoder().decode(bytes)) as { publication_id?: string; source_fingerprint?: string }, programPaths };
  } catch { return { programPaths }; }
}

function errorText(error: unknown): string {
  return error instanceof Error ? error.message.slice(0, 500) : 'Repository synchronization failed.';
}

/** Syncs only the catalog source and generated fallback, based on the retained publication. */
export async function synchronizePublication(publicationID: string,
  environment: RepositorySyncEnvironment, dependencies: RepositorySyncDependencies = {}): Promise<RepositorySyncResult> {
  const apiFetch = dependencies.apiFetch ?? fetch;
  const githubFetch = dependencies.githubFetch ?? fetch;
  const config = repoConfig(environment);
  if (!config || environment.CATALOG_ENVIRONMENT !== 'development') {
    const detail = environment.CATALOG_ENVIRONMENT !== 'development'
      ? 'Repository writes are disabled outside the development catalog environment.'
      : 'Repository target or server-side credential is not configured.';
    await status(publicationID, 'failed', environment, apiFetch, undefined, detail).catch(() => false);
    return { status: 'failed', publicationID, detail };
  }
  try {
    const initial = await operation(publicationID, environment, apiFetch);
    if (!initial.is_current) {
      return { status: 'superseded', publicationID, detail: 'A newer catalog publication is current. Reload before synchronizing.' };
    }
    if (!await status(publicationID, 'in_progress', environment, apiFetch)) {
      return { status: 'superseded', publicationID, detail: 'A newer catalog publication became current before synchronization started.' };
    }
    const validation = validateCatalogSource(initial.source);
    if (!validation.catalog || validation.errors.length) throw new Error(`Published source failed validation: ${validation.errors.join('; ')}`);
    const files = catalogSourceFiles(validation.catalog, publicationID, initial.source_fingerprint);
    let lastError = 'Repository branch changed during synchronization.';

    for (let attempt = 0; attempt < 3; attempt++) {
      const current = await operation(publicationID, environment, apiFetch);
      if (!current.is_current) {
        return { status: 'superseded', publicationID, detail: 'A newer catalog publication is current. Its source must be synchronized instead.' };
      }
      const reference = await githubJSON<{ object?: { sha?: string } }>(
        await github(branchRef(config.branch), config, githubFetch), 'Read repository branch');
      const headSHA = reference.object?.sha;
      if (!headSHA) throw new Error('Repository branch did not return a commit.');
      const headCommit = await githubJSON<{ tree?: { sha?: string } }>(
        await github(`/git/commits/${encodeURIComponent(headSHA)}`, config, githubFetch), 'Read repository commit');
      if (!headCommit.tree?.sha) throw new Error('Repository commit did not return its source tree.');
      const existing = await existingMarker(config, githubFetch, headCommit.tree.sha);
      if (existing.marker?.publication_id === publicationID && existing.marker.source_fingerprint === initial.source_fingerprint) {
        const saved = await status(publicationID, 'synchronized', environment, apiFetch, headSHA);
        const verified = await operation(publicationID, environment, apiFetch);
        if (!verified.is_current) {
          if (verified.current_publication_id) {
            await synchronizePublication(verified.current_publication_id, environment, {
              ...dependencies, beforeReferenceUpdate: undefined,
            });
          }
          return { status: 'superseded', publicationID, detail: 'A newer catalog publication is current. Its repository sync has been started.' };
        }
        if (!saved) return { status: 'failed', publicationID, commitSHA: headSHA, detail: 'Repository files match this publication, but its sync status could not be recorded. Retry is safe.' };
        return { status: 'synchronized', publicationID, commitSHA: headSHA };
      }
      const expectedProgramPaths = new Set(Object.keys(files).filter(path => path.startsWith('worker/catalog/programs/')));
      const treeEntries: Array<{ path: string; mode?: string; type?: string; content?: string; sha?: string | null }> =
        Object.entries(files).map(([path, content]) => ({ path, mode: '100644', type: 'blob', content }));
      for (const path of existing.programPaths) {
        if (!expectedProgramPaths.has(path)) treeEntries.push({ path, sha: null });
      }
      const tree = await githubJSON<{ sha?: string }>(await github('/git/trees', config, githubFetch, {
        method: 'POST', body: JSON.stringify({
          base_tree: headCommit.tree.sha,
          tree: treeEntries,
        }),
      }), 'Create catalog source tree');
      if (!tree.sha) throw new Error('GitHub did not return the generated source tree.');
      const commit = await githubJSON<{ sha?: string }>(await github('/git/commits', config, githubFetch, {
        method: 'POST', body: JSON.stringify({
          message: `Sync catalog publication ${publicationID}`,
          tree: tree.sha,
          parents: [headSHA],
        }),
      }), 'Create catalog commit');
      if (!commit.sha) throw new Error('GitHub did not return the catalog commit.');
      await dependencies.beforeReferenceUpdate?.();
      const stillCurrent = await operation(publicationID, environment, apiFetch);
      if (!stillCurrent.is_current) {
        return { status: 'superseded', publicationID, detail: 'A newer catalog publication arrived before repository update; no stale commit was applied.' };
      }
      const update = await github(updateBranchRef(config.branch), config, githubFetch, {
        method: 'PATCH', body: JSON.stringify({ sha: commit.sha, force: false }),
      });
      if (update.ok) {
        const latest = await operation(publicationID, environment, apiFetch);
        if (!latest.is_current) {
          const latestID = latest.current_publication_id;
          if (latestID) {
            const reconciliation = await synchronizePublication(latestID, environment, {
              ...dependencies, beforeReferenceUpdate: undefined,
            });
            return {
              status: 'superseded', publicationID,
              detail: reconciliation.status === 'synchronized'
                ? `A newer publication arrived during the update; current publication ${latestID} was synchronized.`
                : `A newer publication arrived during the update. Synchronization of current publication ${latestID} needs attention.`,
              ...(reconciliation.commitSHA ? { commitSHA: reconciliation.commitSHA } : {}),
            };
          }
          return { status: 'superseded', publicationID, detail: 'A newer catalog publication arrived during repository update. Reload before retrying.' };
        }
        const saved = await status(publicationID, 'synchronized', environment, apiFetch, commit.sha);
        const verified = await operation(publicationID, environment, apiFetch);
        if (!verified.is_current) {
          const latestID = verified.current_publication_id;
          if (latestID) {
            const reconciliation = await synchronizePublication(latestID, environment, {
              ...dependencies, beforeReferenceUpdate: undefined,
            });
            return {
              status: 'superseded', publicationID,
              detail: reconciliation.status === 'synchronized'
                ? `A newer publication arrived during the update; current publication ${latestID} was synchronized.`
                : `A newer publication arrived during the update. Synchronization of current publication ${latestID} needs attention.`,
              ...(reconciliation.commitSHA ? { commitSHA: reconciliation.commitSHA } : {}),
            };
          }
          return { status: 'superseded', publicationID, detail: 'A newer catalog publication arrived during repository update. Reload before retrying.' };
        }
        if (!saved) return { status: 'failed', publicationID, commitSHA: commit.sha, detail: 'Repository files were updated, but the sync status could not be recorded. Retry is safe.' };
        return { status: 'synchronized', publicationID, commitSHA: commit.sha };
      }
      lastError = `Repository branch update failed (${update.status}).`;
      if (update.status !== 409 && update.status !== 422) throw new Error(lastError);
    }
    throw new Error(lastError);
  } catch (error) {
    const detail = errorText(error);
    await status(publicationID, 'failed', environment, apiFetch, undefined, detail).catch(() => false);
    return { status: 'failed', publicationID, detail };
  }
}
