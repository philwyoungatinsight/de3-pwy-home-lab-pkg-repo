# Make `_framework-pkg` an External Package

## Summary

Converted `infra/_framework-pkg/` from an embedded tracked directory in
`pwy-home-lab-pkg` to an external package sourced from `de3-runner`, matching
the pattern already used by all other packages. `pkg-mgr --sync` is now the
single mechanism for updating the framework — no more manual rsync.

## Changes

- **`Makefile`** — replaced root symlink with a real file containing explicit
  targets (`build`, `clean`, `clean-all`, `setup`, `seed`, `test`) each
  delegating to the framework Makefile, plus a `bootstrap` target for fresh
  clones and a `_require_framework` guard that fails clearly if bootstrap hasn't run
- **`infra/pwy-home-lab-pkg/_config/_framework_settings/framework_packages.yaml`** —
  changed `_framework-pkg` from `package_type: embedded` to `external` with
  `repo: de3-runner`, `git_ref: main`, `import_path: _framework-pkg`
- **`infra/_framework-pkg/` (git untracked)** — removed from git tracking via
  `git rm -r --cached`; physical directory removed and replaced with symlink to
  `_ext_packages/de3-runner/main/infra/_framework-pkg`

## Root Cause

`_framework-pkg` was embedded in `pwy-home-lab-pkg`, requiring manual rsync to
keep it in sync with de3-runner. Converting it to external eliminates that burden.

## Notes

- pkg-mgr refuses to replace a real directory with a symlink (`[[ -d "$link" && ! -L "$link" ]]`
  exits 1). The real directory must be removed manually before `pkg-mgr --sync`.
- A stale tmpfs mount on `infra/_framework-pkg/_config/tmp/dynamic/ephemeral`
  (from the old ephemeral dir path) blocked `rm -rf`. Required `sudo umount` first.
- The `_require_framework` guard was verified to show a clear error message
  (`ERROR: infra/_framework-pkg not found. Run 'make bootstrap' first.`) on a
  fresh clone before bootstrap runs.
- ai-logs for pwy-home-lab-pkg now go in `infra/pwy-home-lab-pkg/_docs/ai-log/`
  (not `infra/_framework-pkg/_docs/ai-log/`) since `_framework-pkg` is now external.
