# ai-log: sops-config-override-support

**Date**: 2026-04-29
**Plan**: `infra/pwy-home-lab-pkg/_docs/ai-plans/sops-config-override-support.md`

## What was done

Renamed `framework_repo_manager.framework_settings_sops_template` (single dict) to
`framework_settings_sops_templates` (list of named dicts) to support multiple SOPS key
configurations per repo.

### Changes

**`de3-ext-packages/de3-runner` (commit e9eb03d):**
- `_fw-repo-mgr/run`: rewrote `_write_sops_yaml()` to accept a second `repo_name` arg,
  look up `framework_settings_sops_templates` list by `name:`, strip the `name:` key before
  writing `.sops.yaml`, and error clearly when the named template is not found.
  Updated call site to pass `$repo_name`.
- `_config/_framework_settings/framework_repo_manager.yaml`: updated commented-out example
  to show the new `framework_settings_sops_templates` list format.

**`infra/pwy-home-lab-pkg/_config/_framework_settings/framework_repo_manager.yaml`:**
- Renamed `framework_settings_sops_template` → `framework_settings_sops_templates`.
- Wrapped the existing content as `- name: default`.
- Added `sops-template: default` to all 13 repos in `framework_repos`.
- Updated two comments that referenced the old key name.

## Outcome

Behaviour is identical to before: all repos use the `default` template. The data model now
supports adding further named templates and pointing specific repos at them via `sops-template:`.
