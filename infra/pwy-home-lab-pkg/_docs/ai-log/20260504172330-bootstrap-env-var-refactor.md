# Bootstrap Env-Var Refactor: _FRAMEWORK_PKG_DIR + _MAIN_PKG_DIR as Primary Anchors

## Summary

Consumer-side changes from the framework bootstrap refactor. The bulk of the work is
in de3-framework-pkg-repo (see its ai-log for full details). The two consumer-side
changes are a one-line fix to `run` and one line in `git-auth-check.py`.

## Changes

- **`run`** — line 42: replaced `git rev-parse --show-toplevel` with
  `Path(__file__).parent.resolve()` (no subprocess, always correct)
- **`infra/pwy-home-lab-pkg/_setup/git-auth-check.py`** — `_FRAMEWORK_CONFIG_PKG_DIR`
  → `_MAIN_PKG_DIR` (legacy alias removed from framework exports)
