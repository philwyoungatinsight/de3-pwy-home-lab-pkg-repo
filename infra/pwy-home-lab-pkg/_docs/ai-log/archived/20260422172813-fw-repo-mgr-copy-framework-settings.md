# fw-repo-mgr: Copy Full Framework Settings into Generated Repos

## Summary

Generated repos were missing all framework settings files except `framework_packages.yaml`,
`framework_package_repositories.yaml`, and `framework_package_management.yaml`. The missing
files — `framework_backend.yaml`, `waves_ordering.yaml`, `framework_config_mgr.yaml`, etc. —
caused `./run` to fail immediately with "neither framework_backend.yaml nor
framework_backend.sops.yaml found."

Two root causes: (1) `_write_minimal_framework_settings` only wrote 2 files; and (2)
`_find_component_config` in bash used `maxdepth 3`, which cannot reach files inside
`_config/_framework_settings/` (depth 4).

## Changes

- **`infra/_framework-pkg/_framework/_fw-repo-mgr/run`** — added `_copy_framework_settings()` to bulk-copy all non-excluded `*.yaml` files from source `_framework_settings/` dirs (framework defaults → config-pkg overrides); added `_write_settings_template()` to apply `framework_settings_template` overrides from config after the copy; wired both into `_build_repo`
- **`infra/_framework-pkg/_framework/_utilities/bash/framework-utils.sh`** — `_find_component_config`: `maxdepth 3 → 4` so files inside `_config/_framework_settings/` are found by the bash backend check
- **`infra/pwy-home-lab-pkg/_config/_framework_settings/framework_repo_manager.yaml`** — added `framework_settings_template` block with the shared GCS backend config; added comment noting `framework_settings_sops_template` is the SOPS equivalent for encrypted settings
- **`infra/_framework-pkg/_config/_framework-pkg.yaml`** / **`version_history.md`** — bumped to 1.4.9

## Root Cause

`_write_minimal_framework_settings` was intentionally minimal (just enough for `pkg-mgr --sync`
to run). The bulk of the settings were never copied. The fix extends the scaffolding step to
include the full set of files the generated repo needs to operate.

## Notes

SOPS files (e.g. `gcp_seed_secrets.sops.yaml`) are copied as-is — same SOPS key assumption.
The `framework_settings_sops_template` pattern (noted in comments) allows injecting encrypted
settings via the `.sops.yaml` variant of `framework_repo_manager` in future.
