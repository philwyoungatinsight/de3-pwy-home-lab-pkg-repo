---
session: highlight-framework-package-git-source-url-link
date: 2026-04-26
---

# fw-repos-visualizer: clickable hyperlinks in DOT output

Added two types of clickable hyperlinks to the DOT output of `fw-repos-visualizer`. When
the DOT file is rendered to SVG (`dot -Tsvg`), all links become clickable in a browser.

## Changes

**`fw_repos_visualizer/renderer.py`**
- Added `_to_browse_url(git_url)` helper: normalizes git remote URLs to browseable HTTPS
  form (strips `.git`, converts `git@github.com:org/repo` → `https://github.com/org/repo`)
- Added `_fw_repo_mgr_url(browse_url, config_package)` helper: constructs a GitHub blob
  URL to `framework_repo_manager.yaml` using `/blob/HEAD/` for branch-agnostic links
- In `_render_dot()`: each package node (ellipse) now carries `URL="<browse_url>"` and
  `target="_blank"` when the repo has an upstream URL
- In `_render_dot()`: each repo cluster now carries `URL="<fw_repo_mgr_url>"` and
  `target="_blank"` when the repo has both an upstream URL and a `main_package` set

**`fw_repos_visualizer/scanner.py`**
- Fixed a missing backfill: `main_package` from declared stubs was not being propagated
  into scan results (unlike `notes` and `labels` which already had backfill). Repos with
  URLs (e.g. `proxmox-pkg-repo`, `pwy-home-lab-pkg`) now correctly carry the
  `main_package` derived from their declaring repo's `framework_repo_manager.yaml`

## Verification

```
grep 'URL=' config/tmp/fw-repos-visualizer/output.dot
```

Confirms:
- Package nodes: `URL="https://github.com/philwyoungatinsight/<repo>"` (no `.git`)
- Cluster labels (proxmox-pkg-repo, pwy-home-lab-pkg): `URL="https://github.com/.../blob/HEAD/infra/<pkg>/_config/_framework_settings/framework_repo_manager.yaml"`

## Package version

`_framework-pkg`: `1.13.0` → `1.14.0`
