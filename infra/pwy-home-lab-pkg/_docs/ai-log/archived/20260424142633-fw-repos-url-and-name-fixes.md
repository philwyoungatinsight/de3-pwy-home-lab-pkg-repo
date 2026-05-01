# Fix fw-repos Diagram: Source URLs and Correct Repo Names

## Summary

Fixed three remaining issues in the fw-repos Mermaid diagram: source URLs not appearing,
wrong repo name (`main` instead of `de3-runner`) for the local repo, and the Refresh
button not actually rescanning. All three root causes were in `scanner.py` and the GUI
Refresh handler.

## Changes

- **`scanner.py` (`_repo_name_from_git`)** — new helper derives repo name from
  `git config --get remote.origin.url` so repos checked out into oddly-named dirs
  (e.g. `de3-runner/main/`) get the correct name (`de3-runner`) instead of the
  directory name (`main`). Falls back to `root.name` if no remote is configured.

- **`scanner.py` (`_load_repo_manager`)** — `declared_repos` stubs now store
  `fr.get("upstream_url") or None` instead of hardcoded `None`. Previously the
  `upstream_url` field from `framework_repo_manager.yaml` was discarded, so
  `proxmox-pkg-repo` and `pwy-home-lab-pkg` had no URL in the state file.

- **`scanner.py` (`run_scan`)** — after scanning the current repo (which passes
  `url=None` to preserve `source="local"`), back-fill the URL from the declared stub
  if one exists. This gives `pwy-home-lab-pkg` its GitHub URL without changing its
  `source` field to `"cloned"`.

- **`homelab_gui.py` (`refresh_fw_repos_data`)** — changed `--list` to
  `--refresh --list` so the Refresh button actually rescans and git-pulls the cache
  instead of only reloading the existing (stale) state file.

## Root Cause

- The `"main"` repo name: `root.name` returns the directory name, which is `main` when
  de3-runner is checked out into `.../de3-runner/main/`. Git remote URL is the reliable
  source of the canonical repo name.
- Missing URLs: `_load_repo_manager` always set `url: None` in declared stubs, ignoring
  the `upstream_url` field that was already populated in `framework_repo_manager.yaml`.
- Refresh button only called `--list` which renders from cached state without rescanning.

## Notes

- The GUI reads state from `_STACK_DIR/config/tmp/fw-repos-visualizer/known-fw-repos.yaml`
  where `_STACK_DIR` is the de3-runner directory. Running `fw-repos-visualizer --refresh`
  from `pwy-home-lab-pkg` writes to a different path — must run from de3-runner's context.
- The `de3-*` repos (de3-gui-pkg, de3-aws-pkg, etc.) intentionally have no `upstream_url`
  because they are packages within de3-runner, not separate GitHub repos.
