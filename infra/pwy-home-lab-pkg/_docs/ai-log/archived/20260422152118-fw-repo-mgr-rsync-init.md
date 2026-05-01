# fw-repo-mgr: Use rsync+git-init for New Repos

## Summary

Fixed `fw-repo-mgr` so that new per-package repos are created via rsync (excluding `.git`)
plus `git init` rather than `git clone`. This means new repos start with zero git history
— no de3-runner commits are carried over. The previous `git clone` approach copied the full
de3-runner history into every new repo.

## Changes

- **`infra/_framework-pkg/_framework/_fw-repo-mgr/run`** (in de3-runner, commit `4fc85ea`):
  - Added `_ext_pkg_base()`: reads `external_package_dir` from `framework_package_management.yaml`
    using the same 3-tier lookup pattern used elsewhere in the script
  - Added `_find_source_clone()`: resolves the local pkg-mgr cache path
    (`$HOME/<ext_pkg_base>/<slug>/<ref>/`) to avoid a network clone when the source is already present
  - Replaced `git clone` in Step 1 (new-repo path) with: rsync from source clone (excluding `.git`),
    then `git init -b main`; if source clone is not cached locally, falls back to a shallow clone
    that is cleaned up after the rsync
  - Removed `source_remote` rename logic from the new-repo path (no remote is added at all for
    local-only repos with no `upstream_url`)

## Root Cause

`git clone` copies the full git history of the template repo (de3-runner). Per-package repos
built from de3-runner had 100+ commits of de3-runner history that had nothing to do with the
package. The fix uses rsync to copy file content only, then `git init` to start a fresh
history.

## Notes

`_find_source_clone` looks up `$HOME/git/de3-ext-packages/<slug>/<ref>/` — the path where
pkg-mgr caches external repo clones. In the standard setup this already exists (de3-runner was
cloned by pkg-mgr when setting up pwy-home-lab-pkg), so no network call is needed.
