# Rename `_FRAMEWORK_CONFIG_PKG` to `_FRAMEWORK_MAIN_PACKAGE`

## Summary

Renamed the two framework env vars from `_FRAMEWORK_CONFIG_PKG` / `_FRAMEWORK_CONFIG_PKG_DIR`
to `_FRAMEWORK_MAIN_PACKAGE` / `_FRAMEWORK_MAIN_PACKAGE_DIR`. The old names
were confusing because "config package" is not what the feature actually means — it's the
*main* (deployment) package. Additionally, `_FRAMEWORK_MAIN_PACKAGE_DIR` is now
realpath-resolved so all tools get a canonical absolute path that survives symlinks.

## Changes

All changes are in de3-runner at `/home/pyoung/git/de3-ext-packages/de3-runner/main/`:

- **`set_env.sh`** — exports `_FRAMEWORK_MAIN_PACKAGE` and `_FRAMEWORK_MAIN_PACKAGE_DIR` (realpath-resolved); accepts `_FRAMEWORK_CONFIG_PKG` as legacy alias on input; re-exports old names as aliases for backward compat
- **`root.hcl`** — local var renamed `_framework_config_pkg_dir` → `_framework_main_package_dir`; reads new var with fallback to old
- **`fw-repo-mgr`** — all 3-tier lookups updated; generated shim `set_env.sh` now exports both new and legacy names
- **`pkg-mgr`** — `_fw_cfg()` reads new var with fallback to old
- **`packages.py` (config-mgr)** — `_fw_cfg_path()` reads new var with fallback to old
- **`framework_config.py`** — `find_framework_config_dirs()` / `fw_cfg_path()` read new var with fallback
- **`config.py` (fw_repos_diagram_exporter)** — `_fw_cfg_path()` reads new var with fallback
- **`config-overview.md`**, **`config-files.md`** — updated to use new names; legacy aliases noted

## Notes

The fallback pattern (`_FRAMEWORK_MAIN_PACKAGE_DIR` or `_FRAMEWORK_CONFIG_PKG_DIR`) in
Python tools provides safety for shell sessions that sourced an older `set_env.sh` without
re-sourcing. Since `set_env.sh` now always exports both vars with the same value, the
fallback is redundant in practice but harmless. The aliases in `set_env.sh` are the primary
compat mechanism and can be removed in the next major version.
