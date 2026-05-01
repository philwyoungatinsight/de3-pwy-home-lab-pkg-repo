# fw-repos-visualizer: Fix Symlink Scanning

## Summary

Fixed `fw-repos-visualizer` scanner not finding `_framework_settings` dirs that are
reachable only through symlinks. In pwy-home-lab-pkg, `infra/_framework-pkg` is a
symlink to the de3-runner clone, so its `_config/_framework_settings/` was being silently
skipped. Replaced `Path.rglob()` with `os.walk(followlinks=True)` throughout `scanner.py`.
Also committed the user's IDE edits enabling all 4 output formats and capability visualization.

## Changes

- **`de3-runner: infra/_framework-pkg/_framework/_fw-repos-visualizer/fw_repos_visualizer/scanner.py`** —
  replaced `path.rglob("_framework_settings")` with `_find_settings_dirs()` helper that uses
  `os.walk(followlinks=True)` + a `seen_real` set to avoid infinite loops on circular symlinks;
  applied in both `needs_refresh()` and `_scan_dir()`
- **`de3-runner: infra/_framework-pkg/_config/_framework_settings/framework_repos_visualizer.yaml`** —
  enable all 4 output formats (yaml, text, json, dot) and capability visualization
  (`show_capability_deps`, `show_capabilities_in_diagram`)
- **`de3-runner: infra/_framework-pkg/_config/_framework-pkg.yaml`** — bumped to 1.9.1
- **`de3-runner: infra/_framework-pkg/_config/version_history.md`** — added 1.9.1 entry

## Root Cause

`pathlib.Path.rglob()` does not follow symlinks by default (Python standard behaviour).
`infra/_framework-pkg` → `../_ext_packages/de3-runner/main/infra/_framework-pkg` is a
symlink, so the entire `_framework-pkg/_config/_framework_settings/` subtree was invisible
to `rglob`, causing `<current-repo>` to show only one settings dir instead of two.

## Notes

- `os.walk(followlinks=True)` does follow symlinks, but can loop infinitely on circular
  symlinks. The `seen_real` guard (tracking `os.path.realpath(dirpath)`) prevents this.
- `Path(dirpath).relative_to(path)` still works correctly when `dirpath` is a symlink path
  (walk uses the link path, not the resolved path), so relative paths in output are readable.
- de3-runner commits: b73a4b3 (fix), fab3e2b (sha update); pushed to origin main.
