# Generate Local Per-Package Repos via fw-repo-mgr

## Summary

Extended `fw-repo-mgr` with `config_package` support and wired `framework_repo_manager.yaml`
with 11 per-package repo entries. Running `fw-repo-mgr -b` now creates `~/git/de3-<pkg>`
for each provider package with the embedded package as its `config_package` and
`_framework-pkg` as an external symlink dependency.

## Changes

- **`infra/pwy-home-lab-pkg/_config/_framework_settings/framework_repo_manager.yaml`** — replaced
  placeholder examples with 11 real per-package repo entries (`de3-aws-pkg` through `de3-unifi-pkg`),
  each with `config_package` set and `_framework-pkg` listed as external
- **`_ext_packages/de3-runner/main/infra/_framework-pkg/_framework/_fw-repo-mgr/run`** — four fixes:
  1. Fixed `FW_MGR_CFG` to use 3-tier config lookup (`_framework_settings/` tier was never reached)
  2. Fixed `_prune_infra` to remove real dirs for `external`-typed packages (not just unlisted ones)
  3. Added `_config_package`, `_write_config_framework_yaml`, `_write_minimal_framework_settings`
     helpers for config_package support
  4. Fixed `_build_repo` Step 4: when `_framework-pkg` is pruned its root symlinks dangle; install
     a minimal `set_env.sh` shim before running `pkg-mgr --sync`, restore symlink after

## Root Cause

`fw-repo-mgr` had three pre-existing bugs that were never triggered because the tool was only
documented with examples (never run against real configs):
- `FW_MGR_CFG` pointed to `_framework-pkg/_config/` (missing `_framework_settings/` subdirectory),
  so the tool silently read no config
- `_prune_infra` kept real dirs for packages listed as `external`, conflicting with `pkg-mgr`'s
  refusal to symlink over existing real directories
- `set_env.sh` in cloned repos is a symlink into `_framework-pkg/`; pruning `_framework-pkg`
  before `pkg-mgr --sync` makes it dangling

## Notes

The shim approach for `set_env.sh` is self-cleaning: after pkg-mgr creates `_framework-pkg`
as a symlink, the real `set_env.sh` symlink is restored, so it resolves correctly going forward.
Each per-package repo shares `$HOME/git/de3-ext-packages/de3-runner/main` via `_ext_packages`
symlink — no redundant clones.
