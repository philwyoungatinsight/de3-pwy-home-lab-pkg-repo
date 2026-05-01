---
date: 2026-04-23
task: ensure-package-names-end-in-pkg
---

# ensure-package-names-end-in-pkg

## What was done

Added enforcement that all framework package names must end with `-pkg`, at every point
where a new name is first accepted.

**Changes:**

- `infra/_framework-pkg/_framework/_pkg-mgr/pkg-mgr`:
  - Added `_assert_pkg_name()` bash helper (exits 1 with clear message if name doesn't end in `-pkg`)
  - Called it in `_cmd_import()` after the `--git-ref` required check
  - Called it in `_cmd_rename()` after the usage check (validates the destination name)
  - Called it in `_cmd_copy()` after the `--skip-state/--with-state` required check (validates dst)
  - Added a name check in `_cmd_sync()`'s Python heredoc — runs over all packages in
    `framework_packages.yaml` before any symlink work, using the existing `invalid`/`sys.exit(1)` pattern

- `infra/_framework-pkg/_framework/_fw-repo-mgr/fw-repo-mgr`:
  - Added name validation inside `_write_framework_packages_yaml()` Python heredoc, before the
    `out = ...` write, catching hand-edits to `framework_repo_manager.yaml`

- `infra/_framework-pkg/_config/_framework_settings/framework_repo_manager.yaml`:
  - Updated example package name `my-homelab` → `my-homelab-pkg` in the Example B
    `framework_packages` list so the example itself satisfies the rule

## Verification

All four guards confirmed working:
- `pkg-mgr --import de3-runner badname --git-ref main` → `ERROR: package name 'badname' must end in '-pkg'`
- `pkg-mgr --rename aws-pkg notpkg` → `ERROR: package name 'notpkg' must end in '-pkg'`
- `pkg-mgr --copy aws-pkg also-bad --skip-state` → `ERROR: package name 'also-bad' must end in '-pkg'`
- Adding `bad-name` to `framework_packages.yaml` then running `--sync` → exits 1 with error

Normal `--sync` continues to pass.
