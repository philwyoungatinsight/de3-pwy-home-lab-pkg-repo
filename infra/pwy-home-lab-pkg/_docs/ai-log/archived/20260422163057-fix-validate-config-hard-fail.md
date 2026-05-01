# Fix: Hard-fail on config validation violations

## Summary

`validate-config` was called from `set_env.sh` with `|| true`, making all violations advisory warnings that never blocked anything. Moved the call out of `set_env.sh` into the two entry-point scripts that actually run builds, so violations now abort execution. Also fixed two GUI startup errors found during testing.

## Changes

- **`infra/_framework-pkg/_framework/_git_root/set_env.sh`** — removed `validate-config` call and ephemeral-mounts trigger from `_set_env_run_startup_checks`; function now only runs `config-mgr/generate`
- **`infra/_framework-pkg/_framework/_git_root/run`** — added `_run_validate_config()` called at startup; hard-exits on violations; also triggers ephemeral mounts if the flag is fresh (once-per-session behaviour preserved)
- **`infra/_framework-pkg/_framework/_fw-repo-mgr/run`** — added `validate-config` call right after `source set_env.sh`; `set -euo pipefail` handles the hard fail
- **`infra/de3-gui-pkg/_config/arch_diagram_config.yaml`** — renamed top-level key `arch_diagram:` → `arch_diagram_config:` to satisfy the validator (key must match filename stem)
- **`infra/de3-gui-pkg/_application/de3-gui/homelab_gui/homelab_gui.py`** — fixed `_load_arch_diagram_config()` to read `arch_diagram_config` key; fixed `rx.foreach` string concatenation error in `_arch_export_menu_item` (`"prefix" + var` → `rx.text("prefix", var)`)

## Root Cause

`set_env.sh` is `source`d, so a failing subprocess can't abort the caller shell. The `|| true` was added defensively to prevent `source set_env.sh` from returning non-zero, but was never revisited. Result: every violation for months printed a warning that no one acted on.

## Notes

`_config-mgr/run` intentionally does NOT get the hard-fail validation — it's the tool used to fix violations, so blocking it would be circular. The 60-minute throttle (`mode: every_n_minutes`) in `framework_validate_config.yaml` still applies; delete `config/tmp/validate-config-last-run` to force an immediate recheck.
