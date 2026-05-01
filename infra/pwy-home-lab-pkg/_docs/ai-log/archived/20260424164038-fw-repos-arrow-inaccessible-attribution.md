# Fix fw-repos: arrow direction, inaccessible coloring, and attribution

## Summary

Three bugs in the fw-repos Mermaid diagram were fixed. The "creates" arrows were pointing in the wrong direction, inaccessible repo coloring never activated, and proxmox-pkg-repo was attributed to de3-runner instead of pwy-home-lab-pkg.

## Changes

- **`assets/fw_repos_mermaid_viewer.html`** — changed `creator <|-- created : creates` to `creator --> created : creates`; the `<|--` arrowhead is at the LEFT so it read as "created creates creator"
- **`scanner.py`** — `_clone_or_pull` now returns bool; clone failures set `accessible: false` in state automatically (was only set when `check_accessibility: true` in config, which defaults to false); `_scan_dir` handles missing clone path
- **`scanner.py`** — `_load_repo_manager` now enqueues framework_repos with `upstream_url` for BFS cloning, so pwy-home-lab-pkg's own settings are scanned and can declare proxmox-pkg-repo with correct attribution; changed lineage to last-write-wins so cloned deployment repos override template claims

## Root Cause

- Arrow: Mermaid classDiagram `A <|-- B` draws the arrowhead at A (left side), so the arrow goes FROM B TO A, making the label read "B creates A" — opposite of intent
- Inaccessible coloring: `accessible: false` requires `check_accessibility: true` in config, which defaults to false; no repos ever had the field set, so the appearance option did nothing
- Attribution: framework_repos were added to `declared_repos` but never enqueued for BFS cloning. pwy-home-lab-pkg's own `framework_repo_manager.yaml` (which correctly attributes proxmox-pkg-repo to pwy-home-lab-pkg) was never reached

## Notes

- With the new BFS expansion, pwy-home-lab-pkg will be cloned to the visualizer cache on next refresh, and its own sub-repos (de3-aws-pkg etc.) will appear in declared_repos with correct attribution
- `check_accessibility: false` in config now means "don't run an explicit ls-remote probe" — but clone failures during BFS still set `accessible: false` automatically
