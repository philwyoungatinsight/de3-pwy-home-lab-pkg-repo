# chore: Remove import_path from packages; consolidate root files into _git_root

## Summary

Two related cleanup efforts shipped in this session. First, `import_path` was removed from
all external package entries in `framework_packages.yaml` and `framework_repo_manager.yaml`
since `pkg-mgr` no longer uses that field. Second, all six consumer-repo root files (`run`,
`set_env.sh`, `Makefile`, `README.md`, `CLAUDE.md`, `TODO.md`) are now canonical in
`_git_root/` and symlinked from the repo root, making the framework the single source of
truth for all repo-root templates.

## Changes

- **`infra/pwy-home-lab-pkg/_config/_framework_settings/framework_packages.yaml`** —
  removed `import_path` from all external package entries; reclassified `_framework-pkg`
  from `package_type: external` to `package_type: embedded` (it is provided by the
  framework itself, not imported as an external package).
- **`infra/pwy-home-lab-pkg/_config/_framework_settings/framework_repo_manager.yaml`** —
  removed `import_path` from all package entries in the framework template and per-repo
  package lists.
- **`_git_root/`** (de3-runner) — added `CLAUDE.md` and `TODO.md`; `Makefile` and
  `README.md` already moved there. All six root files now live in `_git_root/`.
- **`CLAUDE.md`, `TODO.md`, `Makefile`, `README.md`, `run`** (consumer repo root) —
  converted from real files to symlinks pointing into `_git_root/`.

## Notes

- `set_env.sh` was already a symlink to `_git_root/`; this session completed the pattern
  for all remaining root files.
- The `import_path` removal is a cleanup following `pkg-mgr` changes that made the field
  redundant — packages are now identified by name, not a separate import path.
