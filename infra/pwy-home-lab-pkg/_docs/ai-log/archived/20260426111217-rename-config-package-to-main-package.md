# rename: _framework.config_package → _framework.main_package

## Changes

- `config/_framework.yaml`: renamed key `config_package:` → `main_package:`
- `framework_repo_manager.yaml` comment: `_framework.config_package` → `_framework.main_package`

## de3-runner changes (committed separately)

- `read-set-env.py`: reads `main_package` from `_framework.yaml` (was `config_package`)
- `fw-repo-mgr` `_write_config_framework_yaml()`: writes `main_package:` key in generated repos
- `scanner.py`: all dict keys and YAML reads updated (`config_package` → `main_package`)
- `renderer.py`: `repo_data.get("main_package")` for cluster URL generation
- `_framework-pkg`: bumped 1.12.0 → 1.13.0

## Follow-up

Run `fw-repo-mgr -b` to push the new `main_package:` key into all managed repos, then
`fw-repos-visualizer --refresh` to regenerate `known-fw-repos.yaml`.
