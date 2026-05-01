# Plan: Add GitLab Remotes to All Framework Repos

## Objective

Add a `gitlab` remote to every entry in `framework_repo_manager.yaml` so that when
`fw-repo-mgr` builds or refreshes a repo it sets up both an `origin` (GitHub) and a
`gitlab` (GitLab) remote. GitLab URLs follow the pattern
`git@gitlab.com:pwyoung/<repo-name>.git`.

## Context

- `new_repo_config.git-remotes` is already a list; `fw-repo-mgr` iterates over every
  entry and calls `git remote add` for each one — multiple remotes are fully supported.
- `git-auth-check.py` extracts hostnames from all `git-remotes[*].git-source` entries
  and looks them up in `host_type_map`. `gitlab.com: glab` is already present in
  `framework_git_config.yaml`, so auth checking will work once the user runs
  `glab auth login`.
- There are 13 repos in `framework_repos`; all need the new remote.

## Open Questions

None — ready to proceed.

## Files to Create / Modify

### `infra/pwy-home-lab-pkg/_config/_framework_settings/framework_repo_manager.yaml` — modify

For each of the 13 `framework_repos` entries, append a second item to
`new_repo_config.git-remotes`:

```yaml
- name: gitlab
  git-source: git@gitlab.com:pwyoung/<repo-name>.git
  git-ref: main
```

The 13 additions (repo name → GitLab URL):

| Repo name | GitLab URL |
|---|---|
| `de3-_framework-pkg-repo` | `git@gitlab.com:pwyoung/de3-_framework-pkg-repo.git` |
| `de3-aws-pkg-repo` | `git@gitlab.com:pwyoung/de3-aws-pkg-repo.git` |
| `de3-azure-pkg-repo` | `git@gitlab.com:pwyoung/de3-azure-pkg-repo.git` |
| `de3-gui-pkg-repo` | `git@gitlab.com:pwyoung/de3-gui-pkg-repo.git` |
| `de3-gcp-pkg-repo` | `git@gitlab.com:pwyoung/de3-gcp-pkg-repo.git` |
| `de3-image-maker-pkg-repo` | `git@gitlab.com:pwyoung/de3-image-maker-pkg-repo.git` |
| `de3-maas-pkg-repo` | `git@gitlab.com:pwyoung/de3-maas-pkg-repo.git` |
| `de3-mesh-central-pkg-repo` | `git@gitlab.com:pwyoung/de3-mesh-central-pkg-repo.git` |
| `de3-mikrotik-pkg-repo` | `git@gitlab.com:pwyoung/de3-mikrotik-pkg-repo.git` |
| `de3-proxmox-pkg-repo` | `git@gitlab.com:pwyoung/de3-proxmox-pkg-repo.git` |
| `de3-unifi-pkg-repo` | `git@gitlab.com:pwyoung/de3-unifi-pkg-repo.git` |
| `de3-pwy-home-lab-pkg-repo` | `git@gitlab.com:pwyoung/de3-pwy-home-lab-pkg-repo.git` |
| `de3-central-index-repo` | `git@gitlab.com:pwyoung/de3-central-index-repo.git` |

Each entry in the file changes from:

```yaml
new_repo_config:
  git-remotes:
    - name: origin
      git-source: https://github.com/philwyoungatinsight/<repo-name>.git
      git-ref: main
```

to:

```yaml
new_repo_config:
  git-remotes:
    - name: origin
      git-source: https://github.com/philwyoungatinsight/<repo-name>.git
      git-ref: main
    - name: gitlab
      git-source: git@gitlab.com:pwyoung/<repo-name>.git
      git-ref: main
```

## Execution Order

1. Edit `framework_repo_manager.yaml` — add the `gitlab` remote block to each of the
   13 repos in order.
2. Commit the change with an appropriate message and ai-log entry.

## Verification

After executing, confirm:

```bash
# Each repo block should show both remotes
grep -c 'gitlab' infra/pwy-home-lab-pkg/_config/_framework_settings/framework_repo_manager.yaml
# Expected: 13

# Run auth check to confirm gitlab.com is now in scope
python3 infra/pwy-home-lab-pkg/_setup/git-auth-check.py --force
# Expected output includes: check-git-auth [PASS/FAIL] gitlab.com (glab)
# FAIL is expected until `glab auth login` is run
```
