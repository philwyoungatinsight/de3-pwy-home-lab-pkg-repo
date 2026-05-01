# feat(pwy-home-lab-pkg): add gh/glab OAuth login via _setup; add framework_git_config

**Date**: 2026-04-26
**Plan**: gh-glab-oauth-login (archived)

## What changed

### `infra/pwy-home-lab-pkg/_config/_framework_settings/framework_git_config.yaml` — new

New consumer-package framework settings file. Controls periodic git auth validation,
analogous to `framework_validate_config.yaml`. Key options:

- `mode: every_n_minutes` / `interval_minutes: 60` — rate-limits checks (flag file at
  `$_CONFIG_TMP_DIR/check-git-auth-last-run`)
- `validation_type: current-repos` — scans git remotes + `framework_repo_manager.yaml`
  for unique hostnames and checks auth for each
- `on_failure: warn` — non-blocking by default; set to `fail` to gate builds
- `host_type_map` — maps hostname → CLI tool (`github.com: gh`, `gitlab.com: glab`)
- `gh_scopes` — expected token scopes; missing ones are reported

### `infra/pwy-home-lab-pkg/_setup/check-git-auth` — new

Python script invoked by `_setup/run` after tool installation and by `_setup/seed --test`.
Implements the 3-tier settings lookup, `current-repos` hostname collection, gh/glab auth
checks, and rate-limiting. `--force` bypasses the rate limit.

Bug fixed during implementation: `framework_repo_manager.yaml` uses a list-of-objects
structure for `source_repo_defaults` and `git-remotes`, not dicts — parsing was updated
to match the actual schema.

### `infra/pwy-home-lab-pkg/_setup/run` — new

Installs `gh` (via apt or brew) and `glab` (via brew, or GitHub Releases `.deb` for
Debian). Runs `check-git-auth` after installation. Delegates all seed-style flags
(`--login`, `--seed`, `--test`, etc.) to `./seed`.

### `infra/pwy-home-lab-pkg/_setup/seed` — new

Interactive OAuth login for `gh` and `glab`. Follows the `seed_packages()` interface:
`--login`, `--seed`, `--test`, `--status`, `--clean`, `--clean-all`. Reads `host_type_map`
dynamically so adding a new host to the config is all that's needed.

### `infra/pwy-home-lab-pkg/_setup/.gitkeep` — deleted

## Verification

```
python3 infra/pwy-home-lab-pkg/_setup/check-git-auth --force
→ check-git-auth [PASS] github.com (gh)
→ gitlab.com: glab not installed — skipping  ✓

infra/pwy-home-lab-pkg/_setup/seed --status
→ ✓ Logged in to github.com account philwyoungatinsight  ✓

infra/pwy-home-lab-pkg/_setup/seed --test
→ check-git-auth [PASS] github.com (gh)  ✓

Rate-limit: second invocation within interval is a no-op  ✓
```
