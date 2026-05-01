# Rename `_fw-repos-visualizer` to `_fw_repos_diagram_exporter`

## What changed

Renamed the framework tool throughout all live code and config in de3-runner and pwy-home-lab-pkg.

### de3-runner changes

- Tool directory: `_fw-repos-visualizer` → `_fw_repos_diagram_exporter`
- Python package: `fw_repos_visualizer/` → `fw_repos_diagram_exporter/`
- Bash entry-point: `fw-repos-visualizer` → `fw-repos-diagram-exporter` (hyphens retained per framework script convention to avoid name collision with the Python package dir)
- Config YAML: `framework_repos_visualizer.yaml` → `framework_repos_diagram_exporter.yaml` (top-level key + `repos_cache_dir` + inline comment updated)
- State dir: `config/tmp/fw-repos-visualizer` → `config/tmp/fw_repos_diagram_exporter`
- Repos cache dir default: `git/fw-repos-visualizer-cache` → `git/fw_repos_diagram_exporter_cache`
- `set_env.sh`: env var `_FW_REPOS_VISUALIZER` → `_FW_REPOS_DIAGRAM_EXPORTER`; PATH loop dir updated
- `_framework/README.md`: tool table entry updated
- `homelab_gui.py`: `_FW_REPOS_YAML` and `_FW_REPOS_VIZ_BIN` constants updated; tooltip text updated
- `fw_repos_mermaid_viewer.html`: "no repos found" error message updated
- `de3-gui/README.md`: Framework Repos section updated
- `_framework-pkg` bumped `1.15.0` → `1.16.0`
- ai-screwups: added entry documenting the mistake of claiming the GUI didn't exist

### pwy-home-lab-pkg changes

- `CLAUDE.md`: "fw-repos visualizer" reference updated
- `framework_repo_manager.yaml`: comment at `framework_repos:` updated

## Notes

- Historical ai-log and archived ai-plan files retain the old name (correct — they record what happened at that time)
- Existing cached state at `config/tmp/fw-repos-visualizer/` is not migrated; run `fw-repos-diagram-exporter --refresh` after sourcing `set_env.sh` to regenerate
