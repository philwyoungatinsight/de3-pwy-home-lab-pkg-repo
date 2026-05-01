# sops-mgr + fw-repo-mgr integration

**Date**: 2026-04-26
**Plan**: `use-sops-mgr-after-new-git-repo` (archived)

## What changed

- **`sops-mgr`**: added `-d|--infra-dir PATH` argument so callers can scope file
  discovery to a specific directory rather than the current repo's `INFRA_DIR`.
  Threaded through `_find_sops_files()`, `cmd_re_encrypt()`, `cmd_verify()`, and
  `main()`.

- **`sops-mgr README.md`**: removed "not called by automation" claim; replaced "Why
  automation does not use this" section with "When automation calls this"; updated CLI
  reference to include `-d|--infra-dir`.

- **`fw-repo-mgr`**: added call to `"$_SOPS_MGR" --re-encrypt --infra-dir
  "$repo_dir/infra"` immediately after `_write_sops_yaml`, so any `*.sops.yaml` files
  already present in a generated repo are re-encrypted to the new key recipients before
  the commit step. No-op for new repos with no secrets files.

- **`CLAUDE.md`**: added "Why Use Framework Tools" section documenting the traceability,
  single-source-of-truth, and consistency rationale for using framework tools over raw
  shell equivalents.

- **`_framework-pkg` version**: bumped 1.16.0 → 1.17.0.

## Why

`fw-repo-mgr` was already writing a `.sops.yaml` (from `framework_settings_sops_template`)
into target repos, but was never re-encrypting the SOPS files already present in those
repos. Any `*.sops.yaml` copied from `_framework_settings/` would remain encrypted to the
old key set — silently inaccessible to new key holders.

The re-encryption is done via `sops-mgr` (not `sops updatekeys` directly) so that every
SOPS re-encryption in the codebase is findable with `grep -r sops-mgr`.
