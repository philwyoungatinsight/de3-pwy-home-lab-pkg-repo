# fw-repos-visualizer: new framework tool

## Summary

Added `fw-repos-visualizer`, a new framework tool that discovers all known framework
repos by BFS traversal and renders the repo/package graph in multiple formats
simultaneously. All framework changes committed to de3-runner (20d985d, 97d2f15);
consumer repo changes (set_env.sh) committed here.

## What changed

**New tool**: `infra/_framework-pkg/_framework/_fw-repos-visualizer/` (in de3-runner)

- `fw-repos-visualizer` — bash wrapper sourcing `set_env.sh` + `_activate_python_locally`
- `fw_repos_visualizer/config.py` — 3-tier config lookup; uses `_GIT_ROOT` env var to
  resolve consumer repo root (critical: tool cd's into framework dir before Python runs)
- `fw_repos_visualizer/scanner.py` — BFS repo discovery, cloning, `_framework_settings`
  scanning; reads `framework_package_repositories.yaml` and `framework_repo_manager.yaml`
  from each discovered dir; records `created_by` lineage for generated repos
- `fw_repos_visualizer/renderer.py` — renders yaml/json/text/dot simultaneously;
  DOT uses `compound=true` + `ltail/lhead` for cluster-level lineage edges
- `fw_repos_visualizer/main.py` — CLI with `-r/--refresh`, `-l/--list`, `-f/--format`,
  `--auto-refresh/--no-auto-refresh`, `-o/--output`

**New config file**: `_framework_settings/framework_repos_visualizer.yaml`
- `repos_cache_dir` — independent clone cache (not pkg-mgr's external_package_dir)
- `output_formats` — list of formats to render simultaneously (default: yaml, text)
- `show_repo_lineage` — annotate/draw created_by relationships (default: true)
- `show_capability_deps`, `show_capabilities_in_diagram` — optional cap visualization
- `auto_refresh.mode` — never/fixed_time/file_age (default: file_age)
- `auto_refresh.min_interval_seconds` — rate-limit gate (default: 10s)
- `auto_refresh_on_render` — auto-check before --list (default: true)

**State directory**: `config/tmp/fw-repos-visualizer/` (gitignored)
- `known-fw-repos.yaml` — tool writes `data.repos` key only; GUI can add sibling keys
- `last-refresh` — mtime-based rate-limit marker
- `output.<yaml|json|txt|dot>` — rendered outputs

**set_env.sh** (both template and consumer copy):
- Added `_FW_REPOS_VISUALIZER` export
- Added `_fw-repos-visualizer` dir to `_set_env_update_path` PATH list

**_framework-pkg.yaml**: bumped `_provides_capability` from 1.8.0 → 1.9.0

## Bug fixed during execution

`config.py:repo_root()` initially used `git rev-parse --show-toplevel` — but the bash
wrapper does `cd "${SCRIPT_DIR}"` before exec, so git resolved to de3-runner not the
consumer repo. Fixed by checking `_GIT_ROOT` env var first (already exported by
`set_env.sh`).

## Verified

- `fw-repos-visualizer --help` works
- `fw-repos-visualizer --refresh` populates `config/tmp/fw-repos-visualizer/`
- `fw-repos-visualizer --list` renders yaml + text with correct repo/package/lineage data
- `fw-repos-visualizer --list --format dot` produces valid DOT with lineage edges
- Rate-limiting: second `--list` within 10s does not re-scan
- Declared-only repos (from `framework_repo_manager.yaml`) appear with correct lineage
