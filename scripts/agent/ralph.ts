import { spawn } from 'node:child_process';
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

export type Issue = {
  number: number;
  title: string;
  body: string;
  createdAt?: string;
};

const MAX_ATTEMPTS = 3;
const READY_ISSUE_LIMIT = 100;

type RunResult = {
  exitCode: number;
  output: string;
};

type RunOptions = {
  stream?: boolean;
};

export type BlockerReference = {
  number: number;
  repo?: string;
};

type BlockedByParseResult =
  | {
      status: 'unblocked';
      blockers: [];
    }
  | {
      status: 'blocked';
      blockers: BlockerReference[];
    }
  | {
      status: 'malformed';
      blockers: [];
      reason: string;
    };

type BlockerLookupResult = {
  state: string;
  title?: string;
  labels?: { name: string }[];
};

export type IssueReadiness =
  | {
      ready: true;
    }
  | {
      ready: false;
      reason: string;
    };

type VerificationResult = {
  passed: boolean;
  log: string;
  repairable: boolean;
};

async function run(
  command: string,
  args: string[],
  cwd: string,
  options: RunOptions = {}
): Promise<RunResult> {
  return new Promise<RunResult>((resolve) => {
    const child = spawn(command, args, {
      cwd,
      stdio: ['ignore', 'pipe', 'pipe'],
    });

    let output = '';

    child.stdout.on('data', (data) => {
      const text = data.toString();
      output += text;
      if (options.stream !== false) {
        process.stdout.write(text);
      }
    });

    child.stderr.on('data', (data) => {
      const text = data.toString();
      output += text;
      if (options.stream !== false) {
        process.stderr.write(text);
      }
    });

    child.on('close', (code) => {
      resolve({
        exitCode: code ?? 1,
        output,
      });
    });
  });
}

export function isPrdIssue(issue: Issue) {
  const body = issue.body || '';
  const prdHeaders = [
    '## Problem Statement',
    '## Solution',
    '## User Stories',
    '## Implementation Decisions',
    '## Testing Decisions',
  ];

  return prdHeaders.every((header) => body.includes(header));
}

function getMarkdownSection(body: string, heading: string) {
  const lines = body.split(/\r?\n/);
  const headingPattern = new RegExp(`^##\\s+${escapeRegExp(heading)}\\s*$`, 'i');
  const nextHeadingPattern = /^##\s+\S/;
  const startIndex = lines.findIndex((line) => headingPattern.test(line.trim()));

  if (startIndex === -1) {
    return null;
  }

  const sectionLines: string[] = [];

  for (let index = startIndex + 1; index < lines.length; index++) {
    const line = lines[index];

    if (nextHeadingPattern.test(line.trim())) {
      break;
    }

    sectionLines.push(line);
  }

  return sectionLines.join('\n').trim();
}

function escapeRegExp(value: string) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function isNoneBlockedBySection(section: string) {
  const normalized = section
    .split(/\r?\n/)
    .map((line) => line.replace(/^\s*[-*]\s*/, '').trim())
    .filter(Boolean)
    .join(' ')
    .toLowerCase();

  return /^none\b/.test(normalized);
}

function dedupeBlockers(blockers: BlockerReference[]) {
  const seen = new Set<string>();

  return blockers.filter((blocker) => {
    const key = `${blocker.repo || ''}#${blocker.number}`;

    if (seen.has(key)) {
      return false;
    }

    seen.add(key);
    return true;
  });
}

export function parseBlockerReferences(section: string): BlockerReference[] {
  const indexedBlockers: { index: number; blocker: BlockerReference }[] = [];
  const githubIssueUrlPattern = /https:\/\/github\.com\/([\w.-]+\/[\w.-]+)\/issues\/(\d+)/g;
  const shorthandPattern = /(?:([\w.-]+\/[\w.-]+))?#(\d+)/g;
  let match: RegExpExecArray | null;

  while ((match = githubIssueUrlPattern.exec(section)) !== null) {
    indexedBlockers.push({
      index: match.index ?? 0,
      blocker: {
        repo: match[1],
        number: Number(match[2]),
      },
    });
  }

  while ((match = shorthandPattern.exec(section)) !== null) {
    indexedBlockers.push({
      index: match.index ?? 0,
      blocker: {
        ...(match[1] ? { repo: match[1] } : {}),
        number: Number(match[2]),
      },
    });
  }

  return dedupeBlockers(
    indexedBlockers.sort((left, right) => left.index - right.index).map(({ blocker }) => blocker)
  );
}

export function parseBlockedBy(issue: Issue): BlockedByParseResult {
  const section = getMarkdownSection(issue.body || '', 'Blocked by');

  if (!section || isNoneBlockedBySection(section)) {
    return {
      status: 'unblocked',
      blockers: [],
    };
  }

  const blockers = parseBlockerReferences(section);

  if (blockers.length > 0) {
    return {
      status: 'blocked',
      blockers,
    };
  }

  return {
    status: 'malformed',
    blockers: [],
    reason: `unparseable Blocked by section: ${section}`,
  };
}

async function resolveBlockerIssue(blocker: BlockerReference): Promise<BlockerLookupResult | null> {
  const args = ['issue', 'view', String(blocker.number), '--json', 'state,title,number,labels'];

  if (blocker.repo) {
    args.push('--repo', blocker.repo);
  }

  const result = await run('gh', args, process.cwd(), { stream: false });

  if (result.exitCode !== 0) {
    return null;
  }

  return JSON.parse(result.output || '{}');
}

function hasAgentDoneLabel(issue: BlockerLookupResult) {
  return issue.labels?.some((label) => label.name === 'agent:done') ?? false;
}

export async function getIssueReadiness(
  issue: Issue,
  resolveBlocker: (
    blocker: BlockerReference
  ) => Promise<BlockerLookupResult | null> = resolveBlockerIssue
): Promise<IssueReadiness> {
  if (isPrdIssue(issue)) {
    return {
      ready: false,
      reason: 'PRD parent issue',
    };
  }

  const blockedBy = parseBlockedBy(issue);

  if (blockedBy.status === 'unblocked') {
    return {
      ready: true,
    };
  }

  if (blockedBy.status === 'malformed') {
    return {
      ready: false,
      reason: blockedBy.reason,
    };
  }

  for (const blocker of blockedBy.blockers) {
    const blockerIssue = await resolveBlocker(blocker);
    const label = blocker.repo ? `${blocker.repo}#${blocker.number}` : `#${blocker.number}`;

    if (!blockerIssue) {
      return {
        ready: false,
        reason: `could not resolve blocker ${label}`,
      };
    }

    if (hasAgentDoneLabel(blockerIssue)) {
      continue;
    }

    if (blockerIssue.state.toUpperCase() !== 'CLOSED') {
      return {
        ready: false,
        reason: `blocked by open issue ${label}`,
      };
    }
  }

  return {
    ready: true,
  };
}

async function getNextReadyIssue(): Promise<Issue | null> {
  const result = await run(
    'gh',
    [
      'issue',
      'list',
      '--label',
      'agent:ready',
      '--state',
      'open',
      '--search',
      'sort:created-asc',
      '--json',
      'number,title,body,createdAt',
      '--limit',
      String(READY_ISSUE_LIMIT),
    ],
    process.cwd(),
    { stream: false }
  );

  if (result.exitCode !== 0) {
    throw new Error(result.output);
  }

  const createdTime = (issue: Issue) => {
    const timestamp = Date.parse(issue.createdAt || '');

    return Number.isNaN(timestamp) ? Number.MAX_SAFE_INTEGER : timestamp;
  };
  const issues = (JSON.parse(result.output || '[]') as Issue[]).sort((a, b) => {
    return createdTime(a) - createdTime(b);
  });

  for (const issue of issues) {
    const readiness = await getIssueReadiness(issue);

    if (readiness.ready) {
      return issue;
    }

    const reason = 'reason' in readiness ? readiness.reason : 'not ready';

    console.log(`Skipping issue #${issue.number}: ${reason}`);
  }

  return null;
}

async function createBranch(issue: Issue) {
  const branchName = `agent/issue-${issue.number}`;

  await run('git', ['checkout', 'main'], process.cwd());
  await run('git', ['pull'], process.cwd());

  const checkoutResult = await run('git', ['checkout', '-b', branchName], process.cwd());

  if (checkoutResult.exitCode !== 0) {
    throw new Error(checkoutResult.output);
  }

  return branchName;
}

function buildPrompt(issue: Issue, previousFailure?: string) {
  return `
Use the implement-gh-issue skill if available.

You are the IMPLEMENTOR agent.

Implement GitHub issue #${issue.number} only.

Title:
${issue.title}

Issue body:
${issue.body}

Rules:
- Follow AGENTS.md.
- Keep the diff minimal.
- Do not implement unrelated features.
- Do not add new dependencies unless absolutely necessary.
- Run verification before finishing.
- Ralph already selected this as an unblocked non-PRD implementation issue.

${previousFailure ? `Previous verification failure:\n${previousFailure}` : ''}

Final response format:
- Summary
- Files changed
- Verification results
- Risks or follow-ups
`;
}

async function runCodex(prompt: string) {
  return run(
    'codex',
    ['exec', '--profile', 'implementor', '--output-last-message', '.agent-result.md', prompt],
    process.cwd()
  );
}

async function readPackageScripts(cwd: string) {
  const packageJson = JSON.parse(await readFile(`${cwd}/package.json`, 'utf8'));
  return new Set(Object.keys(packageJson.scripts || {}));
}

function lines(value: string) {
  return value
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean);
}

async function getChangedFiles(cwd: string) {
  const diffResult = await run(
    'git',
    ['diff', '--name-only', '--diff-filter=ACMRTUXB', 'HEAD'],
    cwd,
    { stream: false }
  );
  const untrackedResult = await run('git', ['ls-files', '--others', '--exclude-standard'], cwd, {
    stream: false,
  });

  return Array.from(new Set([...lines(diffResult.output), ...lines(untrackedResult.output)]));
}

function normalizePath(filePath: string) {
  return filePath.replace(/^\.\//, '');
}

function isPrettierTarget(filePath: string) {
  return /\.(js|jsx|ts|tsx|json)$/.test(filePath);
}

export function parsePrettierWarningFiles(output: string) {
  return output
    .split(/\r?\n/)
    .map((line) => line.match(/^\[warn\]\s+(.+)$/)?.[1]?.trim())
    .filter((file): file is string => Boolean(file))
    .filter((file) => !file.startsWith('Code style issues'))
    .map(normalizePath);
}

export function markAcceptanceCriteriaDoneInBody(body: string) {
  const lines = body.split(/\r?\n/);
  let inAcceptanceCriteria = false;
  let changed = false;

  const updatedLines = lines.map((line) => {
    const trimmedLine = line.trim();

    if (/^##\s+Acceptance criteria\s*$/i.test(trimmedLine)) {
      inAcceptanceCriteria = true;
      return line;
    }

    if (inAcceptanceCriteria && /^##\s+\S/.test(trimmedLine)) {
      inAcceptanceCriteria = false;
      return line;
    }

    if (!inAcceptanceCriteria) {
      return line;
    }

    const updatedLine = line.replace(/^(\s*(?:[-*]|\d+\.)\s+\[) \](.*)$/, '$1x]$2');

    if (updatedLine !== line) {
      changed = true;
    }

    return updatedLine;
  });

  return {
    body: updatedLines.join('\n'),
    changed,
  };
}

export function buildIssueChangeTitle(issue: Pick<Issue, 'number' | 'title'>) {
  const title = issue.title.replace(/\s+/g, ' ').trim() || 'Untitled issue';

  return `Implement #${issue.number}: ${title}`;
}

async function runPrettierOnFiles(files: string[], cwd: string) {
  if (files.length === 0) {
    return {
      exitCode: 0,
      output: '',
    };
  }

  return run('npx', ['prettier', '--write', ...files], cwd);
}

async function verifyLint(cwd: string, changedFiles: string[]): Promise<VerificationResult> {
  let fullLog = '\n\n$ npm run lint\n';
  const lintResult = await run('npm', ['run', 'lint'], cwd);

  fullLog += lintResult.output;

  if (lintResult.exitCode === 0) {
    return {
      passed: true,
      repairable: true,
      log: fullLog.slice(-8000),
    };
  }

  const prettierWarningFiles = parsePrettierWarningFiles(lintResult.output);
  const changedFileSet = new Set(changedFiles.map(normalizePath));
  const changedPrettierFailures = prettierWarningFiles.filter((file) => changedFileSet.has(file));
  const changedPrettierTargets = changedFiles.filter(isPrettierTarget);

  if (changedPrettierFailures.length > 0) {
    fullLog += `\n\n$ npx prettier --write ${changedPrettierTargets.join(' ')}\n`;
    const formatResult = await runPrettierOnFiles(changedPrettierTargets, cwd);

    fullLog += formatResult.output;

    if (formatResult.exitCode !== 0) {
      return {
        passed: false,
        repairable: true,
        log: fullLog.slice(-8000),
      };
    }

    fullLog += '\n\n$ npm run lint\n';
    const rerunResult = await run('npm', ['run', 'lint'], cwd);

    fullLog += rerunResult.output;

    if (rerunResult.exitCode === 0) {
      return {
        passed: true,
        repairable: true,
        log: fullLog.slice(-8000),
      };
    }

    const remainingPrettierFailures = parsePrettierWarningFiles(rerunResult.output);
    const changedRemainingFailures = remainingPrettierFailures.filter((file) =>
      changedFileSet.has(file)
    );

    if (remainingPrettierFailures.length > 0 && changedRemainingFailures.length === 0) {
      fullLog += '\n\nLint still reports formatting warnings in unchanged baseline files only.\n';

      return {
        passed: true,
        repairable: false,
        log: fullLog.slice(-8000),
      };
    }

    return {
      passed: false,
      repairable: true,
      log: fullLog.slice(-8000),
    };
  }

  if (prettierWarningFiles.length > 0) {
    fullLog += '\n\nLint failed because of formatting warnings in unchanged baseline files only.\n';

    return {
      passed: true,
      repairable: false,
      log: fullLog.slice(-8000),
    };
  }

  return {
    passed: false,
    repairable: true,
    log: fullLog.slice(-8000),
  };
}

async function verify() {
  const cwd = process.cwd();
  const scripts = await readPackageScripts(cwd);
  const changedFiles = await getChangedFiles(cwd);
  const commands: [string, string[]][] = [];

  let fullLog = '';

  if (scripts.has('lint')) {
    const lintVerification = await verifyLint(cwd, changedFiles);

    fullLog += lintVerification.log;

    if (!lintVerification.passed) {
      return {
        passed: false,
        repairable: lintVerification.repairable,
        log: fullLog.slice(-8000),
      };
    }
  } else {
    fullLog += '\n\nSkipped npm run lint: package.json has no lint script.\n';
  }

  if (scripts.has('typecheck')) {
    commands.push(['npm', ['run', 'typecheck']]);
  } else {
    fullLog += '\n\nSkipped npm run typecheck: package.json has no typecheck script.\n';
  }

  if (scripts.has('test')) {
    commands.push(['npm', ['test']]);
  } else {
    fullLog += '\n\nSkipped npm test: package.json has no test script.\n';
  }

  for (const [command, args] of commands) {
    const result = await run(command, args, process.cwd());

    fullLog += `\n\n$ ${command} ${args.join(' ')}\n`;
    fullLog += result.output;

    if (result.exitCode !== 0) {
      return {
        passed: false,
        repairable: true,
        log: fullLog.slice(-8000),
      };
    }
  }

  return {
    passed: true,
    repairable: true,
    log: fullLog.slice(-8000),
  };
}

async function commitAndCreatePr(issue: Issue, branchName: string) {
  await run('git', ['add', '.'], process.cwd());
  const changeTitle = buildIssueChangeTitle(issue);

  const commitResult = await run('git', ['commit', '-m', changeTitle], process.cwd());

  if (commitResult.exitCode !== 0) {
    throw new Error(commitResult.output);
  }

  await run('git', ['push', '-u', 'origin', branchName], process.cwd());

  await run(
    'gh',
    ['pr', 'create', '--title', changeTitle, '--body', `Closes #${issue.number}`],
    process.cwd()
  );
}

async function updateAcceptanceCriteria(issue: Issue) {
  const issueResult = await run(
    'gh',
    ['issue', 'view', String(issue.number), '--json', 'body'],
    process.cwd(),
    { stream: false }
  );

  if (issueResult.exitCode !== 0) {
    throw new Error(issueResult.output);
  }

  const latestIssue = JSON.parse(issueResult.output || '{}') as Pick<Issue, 'body'>;
  const update = markAcceptanceCriteriaDoneInBody(latestIssue.body || '');

  if (!update.changed) {
    console.log(`No unchecked acceptance criteria found for issue #${issue.number}.`);
    return;
  }

  const tempDirectory = await mkdtemp(join(tmpdir(), 'ralph-issue-'));
  const bodyFile = join(tempDirectory, 'body.md');

  try {
    await writeFile(bodyFile, update.body, 'utf8');

    const editResult = await run(
      'gh',
      ['issue', 'edit', String(issue.number), '--body-file', bodyFile],
      process.cwd()
    );

    if (editResult.exitCode !== 0) {
      throw new Error(editResult.output);
    }

    console.log(`Marked acceptance criteria complete for issue #${issue.number}.`);
  } finally {
    await rm(tempDirectory, { recursive: true, force: true });
  }
}

async function updateLabels(issue: Issue, labelsToAdd: string[], labelsToRemove: string[]) {
  for (const label of labelsToAdd) {
    await run('gh', ['issue', 'edit', String(issue.number), '--add-label', label], process.cwd());
  }

  for (const label of labelsToRemove) {
    await run(
      'gh',
      ['issue', 'edit', String(issue.number), '--remove-label', label],
      process.cwd()
    );
  }
}

async function main() {
  const issue = await getNextReadyIssue();

  if (!issue) {
    console.log('No issue with label agent:ready found.');
    return;
  }

  console.log(`Working on issue #${issue.number}: ${issue.title}`);

  await updateLabels(issue, ['agent:in-progress'], ['agent:ready']);

  const branchName = await createBranch(issue);

  let previousFailure: string | undefined;

  for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
    console.log(`Codex attempt ${attempt}/${MAX_ATTEMPTS}`);

    const prompt = buildPrompt(issue, previousFailure);
    const codexResult = await runCodex(prompt);

    if (codexResult.exitCode !== 0) {
      previousFailure = codexResult.output.slice(-8000);
      continue;
    }

    console.log('Running verification...');

    const verification = await verify();

    if (verification.passed) {
      console.log('Verification passed.');

      await commitAndCreatePr(issue, branchName);

      await updateAcceptanceCriteria(issue);

      await updateLabels(issue, ['agent:done'], ['agent:in-progress']);

      console.log(`Done. PR created for issue #${issue.number}.`);
      return;
    }

    if (!verification.repairable) {
      console.log('Verification failed outside this issue. Skipping repair retry.');
      previousFailure = verification.log;
      break;
    }

    console.log('Verification failed. Asking Codex to repair.');
    previousFailure = verification.log;
  }

  await updateLabels(issue, ['agent:needs-human'], ['agent:in-progress']);

  console.log(`Issue #${issue.number} needs human review.`);
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error);
    process.exit(1);
  });
}
