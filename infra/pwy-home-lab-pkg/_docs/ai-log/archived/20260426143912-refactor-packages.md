# refactor-packages

## What was done

Refactored all `framework_repo_manager.framework_repos` entries to follow the
`de3-<package-name>-repo` naming convention and replaced the flat
`upstream_url` / `upstream_branch` fields with a structured
`new_repo_config.git-remotes` list.

### Changes in `pwy-home-lab-pkg`

**`infra/pwy-home-lab-pkg/_config/_framework_settings/framework_repo_manager.yaml`**
- Removed `proxmox-pkg-repo` (old naming, never existed as a real repo)
- Renamed all 11 existing entries: added `-repo` suffix to `de3-*-pkg` names,
  added `de3-` prefix to `proxmox-pkg-repo` → `de3-proxmox-pkg-repo`
- Merged the two duplicate proxmox entries (`proxmox-pkg-repo` + `de3-proxmox-pkg`)
  into single `de3-proxmox-pkg-repo` (with `unifi-pkg` as external dep)
- Added new `de3-_framework-pkg-repo` entry for the `_framework-pkg` package
- Replaced `upstream_url` / `upstream_branch` fields with `new_repo_config.git-remotes`
  structure on all 12 entries, pre-populated with expected GitHub URLs
- Updated `_docs` labels to reference new repo names

**`config/_framework.yaml`**
- Fixed typo: `_docs` label was `https://gitlab.com/pwyoung/pwy-home-pkg`;
  corrected to `https://github.com/philwyoungatinsight/pwy-home-lab-pkg`

### Changes in `de3-runner` (external package)

**`infra/_framework-pkg/_framework/_fw-repo-mgr/fw-repo-mgr`**
- Added `_resolve_remotes()` helper: reads `new_repo_config.git-remotes` from
  config; returns JSON array of remote objects
- Updated `_build_repo()` Step 6: replaces `upstream_url` push with a loop over
  all remotes from `_resolve_remotes()`; removes old `upstream_url` / `upstream_branch`
  locals entirely (hard cutover, no backward compat)
- Updated `_status()`: reads `new_repo_config.git-remotes[0].git-source` instead
  of `upstream_url`
- Updated `repo_names_must_not_contain_special_chars` regex from
  `^[a-z0-9][a-z0-9-]*$` to `^[a-z0-9_][a-z0-9_-]*$` (allow underscore, needed
  for `de3-_framework-pkg-repo`)
- Updated `package_names_must_not_contain_special_chars` regex with same change
  (needed for `_framework-pkg` package name)

### Verification

`fw-repo-mgr -v` → "Naming rules OK."
`fw-repo-mgr status` → all 12 repos shown with correct names and GitHub URLs.
