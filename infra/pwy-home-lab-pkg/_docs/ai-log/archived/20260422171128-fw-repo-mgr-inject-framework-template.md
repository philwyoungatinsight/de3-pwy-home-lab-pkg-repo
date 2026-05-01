# fw-repo-mgr: Inject framework_package_template into generated repos

## Summary

`_write_framework_packages_yaml()` in `fw-repo-mgr/run` was ignoring the top-level
`framework_package_template` block in `framework_repo_manager.yaml`. This block defines
`_framework-pkg` as an auto-injected external package for every generated repo, but was
never read by the code. Generated repos were therefore missing `_framework-pkg`, leaving
`set_env.sh` as a dangling symlink and making `./run` non-functional.

## Changes

- **`infra/_framework-pkg/_framework/_fw-repo-mgr/run`** — `_write_framework_packages_yaml()` now reads `framework_package_template` from config and prepends it to the package list; skips injection if a package with the same name is already explicitly listed (explicit entries win)
- **`infra/_framework-pkg/_config/_framework-pkg.yaml`** — bumped to 1.4.8
- **`infra/_framework-pkg/_config/version_history.md`** — added 1.4.8 entry
- **`infra/pwy-home-lab-pkg/_docs/ai-plans/archived/`** — plan archived

## Root Cause

The `framework_package_template` feature was added in config and documented in the YAML
(version 1.4.5–1.4.7 era) but `_write_framework_packages_yaml()` was never updated to
read it — it only extracted the per-repo `framework_packages:` list, not the top-level
template.

## Notes

The fix is minimal: three lines of Python inside the heredoc. `pkg-mgr --sync` already
runs after this function in the build flow, so once `_framework-pkg` appears in the
written YAML, pkg-mgr handles the clone and symlink automatically.
