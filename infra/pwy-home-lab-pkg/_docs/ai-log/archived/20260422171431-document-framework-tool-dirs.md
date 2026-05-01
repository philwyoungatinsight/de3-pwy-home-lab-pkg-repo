# _framework README: Document _config-mgr, _fw-repo-mgr, _git_root

## Summary

The `_framework/README.md` table listed 8 of 11 subdirectories but was missing
`_config-mgr`, `_fw-repo-mgr`, and `_git_root`. These three directories were added
during the fw-repo-mgr config redesign era but the README was never updated to include
them.

## Changes

- **`infra/_framework-pkg/_framework/README.md`** — added rows for `_config-mgr` (config pre-processor/reader/writer, called from `set_env.sh`), `_fw-repo-mgr` (framework repo manager that builds/syncs consumer repos), and `_git_root` (canonical scaffold files for consumer repo roots)

## Notes

The file lives in the de3-runner external package repo, committed and pushed there
(`45d12cf`). The pwy-home-lab-pkg repo sees it via the `infra/_framework-pkg` symlink.
