# Fix config-mgr _repo_root() Using Wrong Git Root

## Summary

`config-mgr generate` was producing only `_framework-pkg.yaml` in `$_CONFIG_DIR`, never
scanning the consumer repo's packages. Root cause: the `generate` bash script `cd`s into
the framework repo directory before invoking `python3 -m config_mgr.main`, so
`git rev-parse --show-toplevel` returned the framework repo root rather than the consumer
repo root. Fixed by checking `$_GIT_ROOT` (set by `set_env.sh`) before falling back to
`git rev-parse`.

## Changes

- **`de3-framework-pkg-repo: infra/_framework-pkg/_framework/_config-mgr/config_mgr/main.py`** — `_repo_root()` now checks `os.environ.get("_GIT_ROOT")` first; falls back to `git rev-parse` only when the env var is absent (e.g. direct invocation outside of `set_env.sh`)

## Root Cause

The `generate` entry-point script at `_config-mgr/generate` does `cd "${SCRIPT_DIR}"` to
locate its Python module, which changes the working directory to the framework repo. Any
subsequent `git rev-parse --show-toplevel` from that process returns the framework repo root.
`set_env.sh` already exports `_GIT_ROOT` pointing to the consumer repo — using it directly
avoids the `cd`-induced confusion.

## Notes

Discovered while debugging `terragrunt apply` from `de3-aws-pkg-repo` — the apply failed
with `no file exists at config/tmp/dynamic/config/aws-pkg.yaml` because `config-mgr generate`
only wrote `_framework-pkg.yaml`. After the fix, `source set_env.sh` correctly generates
both `_framework-pkg.yaml` and `aws-pkg.yaml`.
