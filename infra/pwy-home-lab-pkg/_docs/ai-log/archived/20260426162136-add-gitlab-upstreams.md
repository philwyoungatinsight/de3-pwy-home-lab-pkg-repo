# add-gitlab-upstreams — 2026-04-26

## What was done

Added a `gitlab` remote entry to all 13 repos in
`infra/pwy-home-lab-pkg/_config/_framework_settings/framework_repo_manager.yaml`.

Each repo in `framework_repos` now has two remotes under `new_repo_config.git-remotes`:
- `origin` → existing GitHub URL (`https://github.com/philwyoungatinsight/<repo-name>.git`)
- `gitlab` → new GitLab URL (`git@gitlab.com:pwyoung/<repo-name>.git`)

`framework_git_config.yaml` already had `gitlab.com: glab` in `host_type_map`, so
`git-auth-check.py` will automatically validate GitLab authentication once the user
runs `glab auth login`.

## Files changed

- `infra/pwy-home-lab-pkg/_config/_framework_settings/framework_repo_manager.yaml`
  — added `gitlab` remote to all 13 `framework_repos` entries
