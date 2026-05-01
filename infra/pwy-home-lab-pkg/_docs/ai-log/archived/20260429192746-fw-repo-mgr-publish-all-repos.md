# ai-log: fw-repo-mgr — publish all framework repos

**Date**: 2026-04-29
**Session continuation**: fw-repo-mgr debugging + full repo publishing run

## What was done

### Previous session (summarised)
- Fixed multiple bugs in `fw-repo-mgr` (GitLab auth, project creation, SOPS re-encryption)
- Renamed `de3-_framework-pkg-repo` → `de3-framework-pkg-repo` (GitLab rejects `-_` in paths)
- Fixed `write_sops_yaml()` to `unlink(missing_ok=True)` before writing — de3-runner tracks
  `.sops.yaml` as a symlink (git mode `120000`); without the unlink, it becomes dangling in
  generated repos where `default-pkg` is pruned, causing `sops updatekeys` to fail
- Fixed GitLab API calls to use direct urllib (bypassing `glab` which has broken JSON parser
  and false-positive exit codes on 404)
- Fixed `_check_glab_auth()` to probe `glab api user` instead of `glab auth status` (latter
  shows "Invalid token" even with valid tokens)
- Fixed `~/.config/glab-cli/config.yml` — `!!null` YAML tag caused Python to read token as None
- Changed all `local_only: true` → `local_only: false` for all 13 repos in
  `framework_repo_manager.yaml`

### This session
- Committed `local_only: false` change (`d2d4b6f`)
- Successfully built and published all 13 framework repos to GitHub + GitLab:

| Repo | GitHub | GitLab |
|------|--------|--------|
| de3-framework-pkg-repo | ✓ exists | ✓ exists |
| de3-aws-pkg-repo | ✓ exists | ✓ exists |
| de3-azure-pkg-repo | ✓ created | ✓ created |
| de3-gui-pkg-repo | ✓ created | ✓ created |
| de3-gcp-pkg-repo | ✓ created | ✓ created |
| de3-image-maker-pkg-repo | ✓ created | ✓ created |
| de3-maas-pkg-repo | ✓ created | ✓ created |
| de3-mesh-central-pkg-repo | ✓ created | ✓ created |
| de3-mikrotik-pkg-repo | ✓ created | ✓ created |
| de3-proxmox-pkg-repo | ✓ created | ✓ created |
| de3-unifi-pkg-repo | ✓ created | ✓ created |
| de3-pwy-home-lab-pkg-repo | ✓ created | ✓ created |
| de3-central-index-repo | ✓ created | ✓ created |

## Key learnings / rules

- Always run `fw-repo-mgr` from the repo root with `source set_env.sh` sourced first.
  Running from inside `_fw-repo-mgr/` (which is physically inside de3-runner via symlink)
  causes `git rev-parse --show-toplevel` to return de3-runner's path, breaking sops-mgr.
- The correct invocation: `source set_env.sh 2>/dev/null; fw-repo-mgr -b <repo-name>`
