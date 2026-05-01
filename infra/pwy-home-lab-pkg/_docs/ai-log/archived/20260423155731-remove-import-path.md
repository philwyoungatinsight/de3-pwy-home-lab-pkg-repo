# Remove import_path from package config

**Date**: 2026-04-23
**Plan**: remove-import_path (archived in de3-runner repo)

## What changed

Removed the `import_path` field from all package configuration files and enforced that
the symlink path for any external package is always derived from the package `name`.

### de3-runner repo (3 commits: 8c8cdcd, 5b75ce5, 2b73a16)

- `pkg-mgr`: dropped `import_path` parameter from `_create_symlink`, `_check_unit_collisions`,
  `_check_config_collisions`, `_check_collisions`; all now use `$pkg_name` directly
- `pkg-mgr`: simplified `_resolve_pkg_repo()` to output only the repo slug (no import_path)
- `pkg-mgr`: added validation error if `import_path` is present in any package entry
- `pkg-mgr`: removed `import_path` from `_cmd_sync` ENTRY line and shell loop field list
- `pkg-mgr`: removed `import_path` from `_cmd_import` entry dict and Python argv
- `pkg-mgr` README: updated schema examples and symlink description
- `framework_packages.yaml` (de3-runner): removed 12 `import_path:` fields + updated example comment
- `framework_repo_manager.yaml` (de3-runner): removed `import_path` from template comment and example entry
- `homelab_gui.py`: updated docstring to remove `import_path` from return shape
- Version bumped: 1.5.4 → 1.6.0

### pwy-home-lab-pkg repo (this commit)

- `framework_packages.yaml`: removed 13 `import_path:` fields (12 packages + comment example)
- `framework_repo_manager.yaml`: removed 10 `import_path:` fields (template + 9 framework_repos entries)

## Verification

- `pkg-mgr sync` ran successfully; all symlinks intact including `infra/_framework-pkg`
- No `import_path` remains in active config or scripts (only in version_history.md and ai-log)
