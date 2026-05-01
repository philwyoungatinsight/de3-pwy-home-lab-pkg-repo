# Fix: fw-repo-mgr update step fails when source repo has no remote

## Summary

`fw-repo-mgr -b` failed when updating repos that were created by rsync+git-init (no
origin remote). Two bugs fixed:

1. Update path tried `git fetch origin` unconditionally — repos created locally have no
   remotes. Fixed: skip fetch when no remote is configured.

2. `_config_package()` only read the legacy `config_package:` key at repo level. It
   missed repos that use the new `is_config_package: true` per-package flag, so those
   repos fell into the else branch that sources a dangling `set_env.sh`. Fixed: if no
   repo-level `config_package:`, fall back to the first package entry with
   `is_config_package: true`.

## Changes

- **`infra/_framework-pkg/_framework/_fw-repo-mgr/run`** — update path: wrap
  `git fetch` / `checkout` / `pull` in `if git remote get-url "$fetch_remote"`; skip
  with a message when no remote exists
- **`infra/_framework-pkg/_framework/_fw-repo-mgr/run`** — `_config_package()`:
  after the legacy `config_package:` lookup, scan `framework_packages` for the first
  entry with `is_config_package: true` and return that name

## Result

All 11 repos in `framework_repo_manager.yaml` now process to `Done:` without errors.
