# feat(wave-mgr): Extract Wave Execution into wave-mgr, Simplify Makefile and run

## Summary

Extracted all wave execution logic from the monolithic `run` script into a new dedicated
`wave-mgr` tool at `infra/_framework-pkg/_framework/_wave-mgr/wave-mgr`. The top-level
`run` is now a thin orchestration wrapper that handles bootstrap, package management, and
delegates all wave operations to `wave-mgr`. The Makefile was simplified to remove the
framework-Makefile delegation pattern.

## Changes

- **`infra/_framework-pkg/_framework/_wave-mgr/wave-mgr`** — new executable; contains all
  wave logic (apply/test/clean/clean-all/list-waves/unlock-gcs/app/retry). Sourced from
  `$_WAVE_MGR` env var. Has its own `parse_args()` and `main()` with only wave-relevant flags.
- **`infra/_framework-pkg/_framework/_git_root/set_env.sh`** (symlinked as `set_env.sh`) —
  added `export _WAVE_MGR` pointing to the new tool, between `_CLEAN_ALL` and `_FW_REPO_MGR`.
- **`infra/_framework-pkg/_framework/_git_root/run`** — replaced with thin template wrapper:
  keeps only package-management functions (`sync_packages`, `setup_packages`, `seed_packages`,
  `ensure_backend`) and delegates all wave ops to `wave-mgr`. No bootstrap logic (new repos
  created by `fw-repo-mgr` already have `_framework-pkg` set up).
- **`run`** (top-level, formerly a symlink — now a standalone file) — thin wrapper with
  bootstrap logic added: `_bootstrap()`, auto-bootstrap check before `_source_env()`,
  and `--bootstrap` CLI flag. Delegates wave ops to `wave-mgr`.
- **`Makefile`** — simplified: removed `FRAMEWORK_MAKEFILE` delegation, `_require_framework`
  guard, and bootstrap shell logic. All targets now call `./run --<flag>` directly.
- **`README.md`** — updated Quick start and Makefile targets table to reflect that bootstrap
  is now automatic and `make all` simply calls `make build`.
- **`infra/pwy-home-lab-pkg/_docs/ai-plans/archived/`** — archived `cleanup-top-makefile.md`.

## Notes

- `run` and `set_env.sh` were previously symlinks to their `_git_root/` counterparts. The
  `run` symlink was broken so the consumer repo's `run` can carry bootstrap logic while
  the template `_git_root/run` remains a no-bootstrap copy for new consumer repos.
- `set_env.sh` remains a symlink (consumer and template share the same export list).
- Framework changes commit to `_ext_packages/de3-runner/main/` (a separate git repo);
  consumer repo changes commit to this repo.
