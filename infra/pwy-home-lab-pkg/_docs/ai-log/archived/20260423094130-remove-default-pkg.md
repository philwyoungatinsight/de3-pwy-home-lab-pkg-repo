---
date: 2026-04-23
session: remove-default-pkg
---

# Remove all `default-pkg` references

Executed plan `remove-default-pkg.md`. Replaced every surviving `default-pkg` reference with
the correct `_framework-pkg` (or correct new path where the file was also reorganised).

## Changes

- `infra/de3-gui-pkg/_setup/run` — updated fallback path and message
- `infra/image-maker-pkg/_setup/run` — updated fallback path and message
- `infra/maas-pkg/_setup/run` — updated fallback path and message
- `infra/mesh-central-pkg/_setup/run` — updated fallback path and message
- `infra/proxmox-pkg/_setup/run` — updated fallback path and message
- `infra/unifi-pkg/_setup/run` — updated fallback path and message
- `infra/maas-pkg/_wave_scripts/test-ansible-playbooks/maas/maas-lifecycle-gate/playbook.yaml` — corrected `include_vars` path to `_FRAMEWORK_PKG_DIR/_config/_framework_settings/framework_backend.yaml`
- `infra/maas-pkg/_wave_scripts/test-ansible-playbooks/maas/maas-lifecycle-sanity/playbook.yaml` — same fix
- `infra/_framework-pkg/_framework/_ai-only-scripts/archived/query-unifi-switch/run` — updated inventory path
- `infra/de3-gui-pkg/_application/de3-gui/state/defaults.yaml` — renamed package filter key `default-pkg` → `_framework-pkg`
- `.gitignore` — updated comment to reference `pkg-mgr` at its new path
- `.claude/settings.local.json` — removed four stale sed allow-list entries
- `infra/_framework-pkg/_config/_framework-pkg.yaml` — bumped to 1.5.1
- `infra/_framework-pkg/_config/version_history.md` — appended 1.5.1 entry
