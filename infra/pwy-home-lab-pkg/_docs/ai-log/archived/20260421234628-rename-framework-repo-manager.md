# Rename framework_manager.yaml → framework_repo_manager.yaml

## Summary

Renamed `framework_manager.yaml` to `framework_repo_manager.yaml` in both
`_framework-pkg/_config/_framework_settings/` (canonical) and
`pwy-home-lab-pkg/_config/_framework_settings/` (deployment override), and updated
`fw-repo-mgr/run` to match. The old name was ambiguous — the file configures the
`fw-repo-mgr` tool specifically, so the new name makes that clear.

## Changes

- **`infra/_framework-pkg/_config/_framework_settings/framework_repo_manager.yaml`** — renamed from `framework_manager.yaml`; top-level key renamed from `framework_manager:` to `framework_repo_manager:`
- **`infra/_framework-pkg/_framework/_fw-repo-mgr/run`** — updated `FW_MGR_CFG` filename, all `d.get('framework_manager', {})` Python calls → `d.get('framework_repo_manager', {})`, and usage string
- **`infra/pwy-home-lab-pkg/_config/_framework_settings/framework_repo_manager.yaml`** — renamed from `framework_manager.yaml`; top-level key updated to match
