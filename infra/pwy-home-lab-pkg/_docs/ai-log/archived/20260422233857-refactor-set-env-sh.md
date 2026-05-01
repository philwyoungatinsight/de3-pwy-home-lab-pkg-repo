# refactor(set_env.sh): extract Python heredocs + rename framework tool scripts

**Date**: 2026-04-22
**de3-runner commits**: `829ead3`, `4e955ee`

## What changed

Executed two plans in de3-runner (`_ext_packages/de3-runner/main`):

1. **refactor-set-env-sh** — replaced the two inline Python heredocs in `set_env.sh`
   with a named helper `_utilities/python/read-set-env.py`:
   - `config-pkg` subcommand: reads `config/_framework.yaml` → `_FRAMEWORK_CONFIG_PKG`
   - `gcs-bucket` subcommand: reads backend YAML → `_GCS_BUCKET`

2. **use-script-names-that-are-unique** — applied the naming convention
   ("run only when sibling Makefile exists") to all framework tool scripts:

   | Old path | New name |
   |---|---|
   | `_config-mgr/run` | `config-mgr` |
   | `_pkg-mgr/run` | `pkg-mgr` |
   | `_unit-mgr/run` | `unit-mgr` |
   | `_ephemeral/run` | `ephemeral` |
   | `_clean_all/run` | `clean-all` |
   | `_fw-repo-mgr/run` | `fw-repo-mgr` |
   | `write-exit-status/run` | `write-exit-status` |
   | `setup-ephemeral-dirs/run` | `setup-ephemeral-dirs` |
   | `purge-gcs-status/run` | `purge-gcs-status` |
   | `fix-git-index-bits/run` | `fix-git-index-bits` |
   | `upgrade-routeros/run` | `upgrade-routeros` |

   And exported 6 new env vars from `set_env.sh` so callers don't need to hardcode paths:
   `_PKG_MGR`, `_UNIT_MGR`, `_CLEAN_ALL`, `_EPHEMERAL`, `_CONFIG_MGR`, `_FW_REPO_MGR`

   Callers updated: `_git_root/run` (Python constants), `fw-repo-mgr` (bash vars),
   `homelab_gui.py` (4 hardcoded `default-pkg` paths replaced with env vars).

## Versions bumped
- `_framework-pkg`: 1.4.11 → 1.5.0
- `de3-gui-pkg`: 0.3.0 → 0.3.1
