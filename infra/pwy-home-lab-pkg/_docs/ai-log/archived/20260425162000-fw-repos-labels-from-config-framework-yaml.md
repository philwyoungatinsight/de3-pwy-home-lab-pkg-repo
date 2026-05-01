# fw-repos-labels-from-config-framework-yaml — Read repo labels from config/_framework.yaml

**Date**: 2026-04-25

## Summary

Moved repo labels to their authoritative location: each repo's own `config/_framework.yaml`.
Previously labels were only read from `framework_repo_manager.yaml` stubs in the declaring repo
— which made them externally-declared metadata rather than self-declared repo identity.

## Changes

### `de3-runner` — `scanner.py` (commit `63d3f15`)

Extended the `config/_framework.yaml` read block in `_scan_dir` to also pick up `labels`:

```python
fw_cfg = cfg_raw.get("_framework", {})
cp = fw_cfg.get("config_package", "")
if cp:
    entry["config_package"] = cp
repo_labels = fw_cfg.get("labels", [])
if repo_labels:
    entry["labels"] = repo_labels
```

Labels from `config/_framework.yaml` are **authoritative** — they override any labels
inherited from the declaring repo's `framework_repo_manager.yaml`. This matches how
`config_package` works: the repo declares its own identity, and external declarations
are only a fallback for repos that haven't been cloned yet.

### `pwy-home-lab-pkg` — `config/_framework.yaml`

Added pwy-home-lab-pkg's own labels:

```yaml
labels:
  - name: _purpose
    value: Home lab deployment — orchestrates all infrastructure packages
  - name: _docs
    value: infra/pwy-home-lab-pkg/_docs/
```

## How to pick up the change

```bash
# In pwy-home-lab-pkg:
source set_env.sh
fw-repos-visualizer --refresh
# Then open the GUI and verify Labels section shows for pwy-home-lab-pkg
```
