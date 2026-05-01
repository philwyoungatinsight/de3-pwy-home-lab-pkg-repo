# Add new_repo_config_defaults with Branch Protection Schema

## Summary

Added `new_repo_config_defaults` section to `framework_repo_manager.yaml` so that
branch protection settings can be declared once and inherited by all repos, with
per-repo overrides for individual repos that need different settings.

## Changes

- **`infra/pwy-home-lab-pkg/_config/_framework_settings/framework_repo_manager.yaml`**
  — new `new_repo_config_defaults` section with `git-refs` list; ships with `main`
  explicitly set to `allow_direct_push: true` / `allow_force_push: true` (open by
  default); merge semantics documented in comments: per-repo overrides are per-branch,
  per-field — only specified fields win, unspecified fields fall back to defaults

## Notes

- `fw-repo-mgr` will need to be updated separately to read and apply these settings
  when creating repos on GitHub/GitLab.
- Per-repo override example is shown in a comment block directly above `framework_repos`
  so it is visible when editing repo entries.
