# refactor(config-mgr): replace direct sops --set calls with config-mgr

## What changed

Reviewed all `sops --set` usage across the codebase. Found two categories of issues:

**1. Direct `sops --set` calls in cloud seed scripts (aws-pkg, azure-pkg, gcp-pkg)**

Each `_setup/seed` script had private helper functions (`_write_credentials_to_sops`,
`_clear_credentials_from_sops` / `_clear_sops_credentials` / `_clear_sa_key_from_sops`)
that called `sops --set` directly, duplicating the quoting/escaping logic that already
lives in `config_mgr/sops.py`. Replaced with `"$_CONFIG_MGR" set-raw <pkg> <dot.path>
"$value" --sops`. For clear operations (empty string), passed `'""'` so YAML parses it
as an empty string rather than null.

**2. Stale `_config-mgr/run` path in 5 Ansible tg-script task files**

The c41cabb commit renamed framework tools from `run` to descriptive names (config-mgr,
pkg-mgr, etc.) and exported `_CONFIG_MGR` in set_env.sh, but five Ansible task files
still referenced `{{ lookup('env', '_FRAMEWORK_DIR') }}/_config-mgr/run` (broken path).
Fixed all five to use `{{ lookup('env', '_CONFIG_MGR') }}`.

## Files changed (de3-ext-packages/de3-runner/main)

- `infra/aws-pkg/_setup/seed`
- `infra/azure-pkg/_setup/seed`
- `infra/gcp-pkg/_setup/seed`
- `infra/proxmox-pkg/_tg_scripts/proxmox/configure/tasks/configure-api-token.yaml`
- `infra/maas-pkg/_tg_scripts/maas/configure-server/tasks/install-maas.yaml`
- `infra/maas-pkg/_tg_scripts/maas/sync-api-key/playbook.yaml`
- `infra/maas-pkg/_tg_scripts/maas/configure-region/tasks/install-maas.yaml`
- `infra/_framework-pkg/_config/_framework-pkg.yaml` (bumped to 1.5.2)
- `infra/_framework-pkg/_config/version_history.md`

## Commit

`de3-ext-packages/de3-runner/main` @ ece766c
