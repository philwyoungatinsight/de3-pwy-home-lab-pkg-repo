# fw-repos: config_package second attribute + framework_repo_manager.yaml link

## What changed

**`fw_repos_visualizer/scanner.py`** (in `_framework-pkg`):
- `_scan_dir`: reads `config/_framework.yaml` from each cloned/local repo root and stores
  `config_package` in the result entry
- `_load_repo_manager`: derives `config_package` from `is_config_package: true` on the
  framework_packages list (falls back to sole embedded package if none flagged); stored
  in declared_repos stub
- `run_scan`: back-fills `config_package` from the declared stub for the current (local) repo

**`fw_repos_mermaid_viewer.html`** (in `de3-gui-pkg`, both assets/ and .web/public/ copies):
- Shows `config_package` value as a second attribute line in each class node (after the URL)
- `link` directive now targets
  `infra/<config_pkg>/_config/_framework_settings/framework_repo_manager.yaml` in the repo
  (GitHub: `/blob/main/…`, GitLab: `/-/blob/main/…`) when `config_package` is known;
  falls back to repo root URL when not

## Version bumps

- `_framework-pkg`: 1.9.1 → 1.10.0 (new feature — config_package scanning)
- `de3-gui-pkg`: 0.5.0 → 0.5.1 (patch — second attribute + updated link)
