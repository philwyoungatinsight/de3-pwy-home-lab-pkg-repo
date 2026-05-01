# Clean Up Defunct Repos in fw-repos Visualizer

**Date**: 2026-04-26  
**Plan**: `infra/_framework-pkg/_docs/ai-plans/clean-up-defunct-repos.md`

## What was done

Removed stale/defunct repo entries (`de3-aws-pkg`, `de3-proxmox-pkg`, `proxmox-pkg-repo`,
`de3-demo-buckets-example-pkg`, etc.) from the fw-repos visualizer by fixing the two root
causes rather than patching the cache.

### Root cause 1 — de3-runner template triggered a stale GitHub clone

`de3-runner/infra/_framework-pkg/_config/_framework_settings/framework_repo_manager.yaml`
had an active (uncommented) entry for `pwy-home-lab-pkg` with `upstream_url`. On every
scan the `fw-repos-visualizer` cloned that GitHub URL, read the old `framework_repo_manager.yaml`
there (which still had the pre-rename `de3-aws-pkg`, `proxmox-pkg-repo`, etc. naming),
and wrote those names into `known-fw-repos.yaml`. Fixed by commenting out the entry and
replacing it with a generic commented example using the new schema.

### Root cause 2 — scanner read `upstream_url`; new schema uses `new_repo_config.git-remotes`

`scanner._load_repo_manager()` extracted repo URLs from the legacy `upstream_url` field.
The new `framework_repo_manager.yaml` schema uses `new_repo_config.git-remotes[0].git-source`.
Result: new `de3-*-repo` declared stubs had no URL in the diagram, and there was no single
authoritative way to declare a repo's remote. Fixed by rewriting the URL extraction to read
`new_repo_config.git-remotes[0].git-source` exclusively; `upstream_url` removed from all
config files.

### Root cause 3 — scanner tried to clone `local_only: true` repos

With the scanner now reading `git-remotes` URLs, repos marked `local_only: true` (which
don't exist on remote yet) would be enqueued for cloning and marked `accessible: false`.
Fixed by skipping enqueue for any repo entry with `local_only: true`. The `local_only`
flag is also propagated into the declared stub so the visualizer can render it distinctively.

## Files changed (de3-runner)

- `infra/_framework-pkg/_config/_framework_settings/framework_repo_manager.yaml` — commented
  out the active `pwy-home-lab-pkg` entry; removed stale `upstream_url`/`upstream_branch`
  from old commented example; replaced both with a new correct example using `new_repo_config.git-remotes`
- `infra/_framework-pkg/_framework/_fw-repos-visualizer/fw_repos_visualizer/scanner.py` —
  URL extraction now reads `new_repo_config.git-remotes[0].git-source`; local_only repos
  skipped from BFS queue; local_only flag stored in declared stub

## Stale cache cleared

Both `config/tmp/fw-repos-visualizer/known-fw-repos.yaml` files deleted to force a fresh
scan on next GUI load.

## Not changed

`pwy-home-pkg` (local repo name from GitLab origin URL) is left as-is — `de3-pwy-home-lab-pkg-repo`
will be built from `pwy-home-lab-pkg` by `fw-repo-mgr`, after which the old repo retires.
