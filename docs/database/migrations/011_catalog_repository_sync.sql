BEGIN;

ALTER TABLE public.catalog_publications
  ADD COLUMN repository_sync_status text NOT NULL DEFAULT 'pending'
    CHECK (repository_sync_status IN ('pending', 'in_progress', 'synchronized', 'failed', 'superseded')),
  ADD COLUMN repository_commit_sha text,
  ADD COLUMN repository_sync_error text,
  ADD COLUMN repository_synced_at timestamptz;

COMMIT;
