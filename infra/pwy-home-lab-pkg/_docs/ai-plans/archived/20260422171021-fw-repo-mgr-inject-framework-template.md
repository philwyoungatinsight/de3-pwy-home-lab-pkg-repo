# Plan: fw-repo-mgr — Inject framework_package_template into generated repos

## Problem

After `fw-repo-mgr -b`, generated repos in `de3-source-packages/` are missing
`_framework-pkg`. For example:

```
de3-source-packages/de3-gui-pkg/infra/
└── de3-gui-pkg/    ← only the embedded package
    (no _framework-pkg symlink)
```

`set_env.sh` in each generated repo is a symlink to
`infra/_framework-pkg/_framework/_git_root/set_env.sh`, which is dangling because
`_framework-pkg` was never installed.

## Root Cause

`_write_framework_packages_yaml()` in `fw-repo-mgr/run` only copies the packages
explicitly listed in each repo's `framework_packages:` entry. It ignores the top-level
`framework_package_template` block in `framework_repo_manager.yaml`, which is supposed
to define `_framework-pkg` as an auto-injected external package for every repo:

```yaml
# framework_repo_manager.yaml (current)
framework_repo_manager:
  framework_package_template:
    name: _framework-pkg
    package_type: external
    exportable: true
    repo: de3-runner
    source: https://github.com/philwyoungatinsight/de3-runner.git
    git_ref: main
    import_path: _framework-pkg
```

The template is defined but never read by the code.

## Fix

### File: `infra/_framework-pkg/_framework/_fw-repo-mgr/run`

**Function `_write_framework_packages_yaml()`** (around line 197):

Read `framework_package_template` from the config and prepend it to the packages
list before writing. Skip if a package with the same name already appears in the
explicit list (explicit entries win).

Current code:
```python
d = yaml.safe_load(pathlib.Path(cfg_path).read_text()) or {}
repos = d.get('framework_repo_manager', {}).get('framework_repos', [])
pkgs = next((r.get('framework_packages', []) for r in repos if r.get('name') == repo_name), [])
out = {'framework_packages': pkgs}
```

Replacement:
```python
d = yaml.safe_load(pathlib.Path(cfg_path).read_text()) or {}
fm = d.get('framework_repo_manager', {})
repos = fm.get('framework_repos', [])
pkgs = next((r.get('framework_packages', []) for r in repos if r.get('name') == repo_name), [])

# Inject framework_package_template at the front unless already present by name
template = fm.get('framework_package_template')
explicit_names = {p['name'] for p in pkgs}
if template and template.get('name') not in explicit_names:
    pkgs = [template] + pkgs

out = {'framework_packages': pkgs}
```

No other code changes needed. `pkg-mgr --sync` in Step 4 already runs after this
function writes the file; once `_framework-pkg` appears in the list, pkg-mgr will
clone de3-runner to `~/git/de3-ext-packages/de3-runner/main/` (or reuse an existing
clone) and create `infra/_framework-pkg` as a symlink.

## Expected Result

After the fix, re-running `fw-repo-mgr -b` produces:

```
de3-source-packages/de3-gui-pkg/infra/
├── _framework-pkg -> ../_ext_packages/de3-runner/main/infra/_framework-pkg
└── de3-gui-pkg/
```

`set_env.sh` resolves, `./run` works, the generated repo is a fully functional
standalone repo.

## Open Questions

None — the fix is straightforward. Confirm to proceed with `/doit fw-repo-mgr-inject-framework-template`.
