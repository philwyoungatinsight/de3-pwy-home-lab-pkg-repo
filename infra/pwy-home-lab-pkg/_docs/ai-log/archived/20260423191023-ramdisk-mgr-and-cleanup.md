# chore: rename ephemeral → ramdisk; clean up default-only framework_settings files

**Date**: 2026-04-23

## What changed

### framework_settings cleanup

Removed 6 files from `infra/pwy-home-lab-pkg/_config/_framework_settings/` that were
byte-identical to framework defaults (the README now explains that only overrides need
to live here):
- `framework_ansible_inventory.yaml` — identical default
- `framework_config_mgr.yaml` — identical default
- `framework_ephemeral_dirs.yaml` — deleted; replaced by `framework_ramdisk.yaml`
- `framework_external_capabilities.yaml` — identical default
- `framework_pre_apply_unlock.yaml` — identical default
- `framework_validate_config.yaml` — identical default

Kept (meaningful overrides):
- `framework_clean_all.yaml` — `pre_destroy_order: [pwy-home-lab-pkg]`
- `framework_ramdisk.yaml` — new; `size_mb: 0` skips ramdisk for this deployment

### Other

- `README.md` — added "Overrides are per-file, not per-directory" section
- `framework_repo_manager.yaml` — reverted `framework_repo_dir` to
  `git/de3-generated-framework-repos`; fixed comment typo (repo manager)
- `_docs/tech-debt/gpg/README.gpg-setup.md` — new; options for reducing GPG passphrase
  prompts (increasing cache TTL, switching to AGE, cycling gpg-agent)
