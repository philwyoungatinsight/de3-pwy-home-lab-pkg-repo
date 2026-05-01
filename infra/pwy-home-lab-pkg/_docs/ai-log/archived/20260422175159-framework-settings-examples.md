# _framework-pkg: Improve framework_settings examples and placeholder comments

## Summary

The framework default `_framework_settings/` files in de3-runner had deployment-specific
values (real bucket names, project IDs, package names) with no placeholder guidance for
new users. Added commented-out example blocks showing the expected shape, and fixed
`framework_clean_all.yaml` which had the deployment-specific `pwy-home-lab-pkg` hardcoded
in what should be a generic framework default.

## Changes

- **`infra/_framework-pkg/_config/_framework_settings/framework_repo_manager.yaml`** (de3-runner) — added commented-out `framework_package_template`, `framework_settings_template`, and `framework_settings_sops_template` example blocks; updated Example A/B to use `is_config_package` and drop the now-redundant explicit `_framework-pkg` entries
- **`infra/_framework-pkg/_config/_framework_settings/framework_backend.yaml`** (de3-runner) — added commented-out placeholder shape showing `<your-state-bucket>` / `<your-gcp-project-id>`
- **`infra/_framework-pkg/_config/_framework_settings/gcp_seed.yaml`** (de3-runner) — added commented-out placeholder shape with notes on each field
- **`infra/_framework-pkg/_config/_framework_settings/framework_clean_all.yaml`** (de3-runner) — replaced hardcoded `pwy-home-lab-pkg` in `pre_destroy_order` with empty list `[]` and a commented-out example; deployment override supplies the real value
- **`infra/pwy-home-lab-pkg/_config/_framework_settings/framework_repo_manager.yaml`** — added `framework_settings_sops_template` commented-out example block

## Root Cause

The framework defaults were copy-pasted from pwy-home-lab-pkg's deployment config and
never genericised. New deployments forking de3-runner would inherit real values with no
guidance on what to change.

## Notes

`_framework-pkg` bumped to 1.4.10 (de3-runner `98f7ca4`/`8f1f0fa`).
