# Plan: change-source-repo-use

## Objective

Change `framework_repo_manager.framework_repos[].source_repo` from a string
reference (name lookup only) to an **inline object** that carries `name`, `url`,
and `ref` directly.  Rename the top-level `source_repos` registry to
`source_repo_defaults` so it acts as a fallback: if a per-repo `source_repo` block
omits `url` or `ref`, those values are looked up from the matching defaults entry
by name.  Update all affected `framework_repo_manager.yaml` files and the
`_resolve_source()` + `_build_repo()` logic in `fw-repo-mgr`.

---

## Context

### Current design

```yaml
source_repos:               # named lookup table
  - name: de3-runner
    url: https://github.com/philwyoungatinsight/de3-runner.git
    ref: main

framework_repos:
  - name: de3-aws-pkg-repo
    source_repo: de3-runner  # <── string: name key only
```

`_resolve_source()` in `fw-repo-mgr` builds a `source_registry` dict from
`source_repos`, then looks up the `source_repo` string to get url/ref.  A
separate legacy path reads `source_url` / `source_ref` siblings for one-off URLs.

### Target design

```yaml
source_repo_defaults:        # renamed; values used when per-repo block is partial
  - name: de3-runner
    url: https://github.com/philwyoungatinsight/de3-runner.git
    ref: main

framework_repos:
  - name: de3-aws-pkg-repo
    source_repo:             # <── object; name-only → lookup from defaults
      name: de3-runner
    # OR fully explicit (no lookup needed):
    # source_repo:
    #   name: de3-runner
    #   url: https://github.com/philwyoungatinsight/de3-runner.git
    #   ref: main
```

Resolution rules (in priority order):
1. `source_repo.url` / `source_repo.ref` if present — used directly.
2. `source_repo.name` — lookup in `source_repo_defaults`; fill in missing url/ref.
3. Neither present → error.

### Files affected

| File | Change |
|---|---|
| `infra/pwy-home-lab-pkg/_config/_framework_settings/framework_repo_manager.yaml` | Rename key, expand all `source_repo:` strings to objects |
| `infra/_framework-pkg/_config/_framework_settings/framework_repo_manager.yaml` (de3-runner tier-3) | Same rename + update example entry |
| `_ext_packages/de3-runner/main/infra/_framework-pkg/_framework/_fw-repo-mgr/fw-repo-mgr` | Update `_resolve_source()`, `_build_repo()` update branch, `usage()` |

### Touchpoints in `fw-repo-mgr`

1. **`_resolve_source()` line 201**: reads `fm.get('source_repos', [])` and
   `r.get('source_repo', '')` as a string.
2. **`_build_repo()` line 485**: `_repo_field "$repo_name" source_repo` reads the
   scalar string to determine the git remote name for fetching.
3. **`usage()` line 637**: references `source_repos` in workflow docs.

The legacy `source_url` / `source_ref` sibling fields are removed (clean cutover —
both config files are updated atomically).

---

## Open Questions

None — ready to proceed.

---

## Files to Create / Modify

### 1. `infra/pwy-home-lab-pkg/_config/_framework_settings/framework_repo_manager.yaml` — modify

**a)** Rename `source_repos:` → `source_repo_defaults:` and add explanatory comment:

```yaml
  # Default source repo parameters looked up by name.
  # Each entry supplies the url and ref used when a per-repo source_repo block
  # references only the name without explicit url/ref.
  source_repo_defaults:
    - name: de3-runner
      url: https://github.com/philwyoungatinsight/de3-runner.git
      ref: main          # default ref when not overridden per target
```

**b)** Expand every `source_repo: de3-runner` string entry to an object.
Example (apply to all 12 repos):

```yaml
    source_repo:
      name: de3-runner
```

Add a comment block before the first entry to document the lookup behaviour:

```yaml
  # Per-package repos — one embedded package per repo.
  # source_repo: specifies the template source for this repo.
  #   name: (required) — used as the git remote name when fetching updates;
  #         if url/ref are absent, looked up from source_repo_defaults above.
  #   url:  (optional) — explicit clone URL; overrides source_repo_defaults.
  #   ref:  (optional) — explicit git ref; overrides source_repo_defaults.
```

### 2. `infra/_framework-pkg/_config/_framework_settings/framework_repo_manager.yaml` (de3-runner tier-3) — modify

Same two changes as §1:
- `source_repos:` → `source_repo_defaults:` with updated comment.
- Commented-out example entry: change `source_repo: de3-runner` to the object form:
  ```yaml
  #  source_repo:
  #    name: de3-runner          # resolved via source_repo_defaults above
  ```
- Real entry (`pwy-home-lab-pkg`): `source_repo: de3-runner` → object form.
- Update inline code comment on line 120 from `# resolved via source_repos registry above`
  to `# resolved via source_repo_defaults above`.

### 3. `_ext_packages/de3-runner/main/infra/_framework-pkg/_framework/_fw-repo-mgr/fw-repo-mgr` — modify

**a) Rewrite `_resolve_source()` Python block** (replace lines 196–217):

```python
import sys, yaml, pathlib
repo_name, cfg_path = sys.argv[1], sys.argv[2]
d = yaml.safe_load(pathlib.Path(cfg_path).read_text()) or {}
fm = d.get('framework_repo_manager', {})
# Build defaults registry from source_repo_defaults (renamed from source_repos)
defaults = {s['name']: s for s in fm.get('source_repo_defaults', [])}
repos = fm.get('framework_repos', [])
for r in repos:
    if r.get('name') != repo_name:
        continue
    src = r.get('source_repo') or {}
    if isinstance(src, str):
        # Should not occur after migration, but guard against it
        src = {'name': src}
    sname = src.get('name', '')
    fallback = defaults.get(sname, {}) if sname else {}
    url = src.get('url') or fallback.get('url', '')
    ref = src.get('ref') or fallback.get('ref', 'main')
    print(url + ' ' + ref)
    sys.exit(0)
print(' ')
```

Update the function comment above it:
```bash
# Resolve source URL + ref for a target repo name.
# Reads source_repo.url/ref directly; falls back to source_repo_defaults by name.
```

**b) Update `_build_repo()` update-branch** (lines 485–486):

The current code reads `source_repo` as a scalar to get the remote name:
```bash
local source_repo_name; source_repo_name=$(_repo_field "$repo_name" source_repo)
```

`_repo_field` reads a top-level scalar field — it will now return an empty string
(since `source_repo` is an object, not a scalar).  Replace with a targeted Python
read:

```bash
    local source_repo_name
    source_repo_name=$(python3 -c "
import yaml, pathlib, sys
d = yaml.safe_load(pathlib.Path('$FW_MGR_CFG').read_text()) or {}
for r in d.get('framework_repo_manager', {}).get('framework_repos', []):
    if r.get('name') == '$repo_name':
        src = r.get('source_repo') or {}
        if isinstance(src, str): src = {'name': src}
        print(src.get('name', ''))
        sys.exit(0)
print('')
" 2>/dev/null || echo "")
```

**c) Update `usage()` workflow docs** (line 637):

```bash
  1. Add entries to framework_repo_manager.yaml (source_repo_defaults + framework_repos)
```

---

## Execution Order

1. Modify tier-2 `framework_repo_manager.yaml` (pwy-home-lab-pkg).
2. Modify tier-3 `framework_repo_manager.yaml` (de3-runner, in `_ext_packages`).
3. Update `fw-repo-mgr` script (de3-runner, in `_ext_packages`):
   a. Rewrite `_resolve_source()`.
   b. Update `_build_repo()` update-branch.
   c. Update `usage()` docs.
4. Run `fw-repo-mgr -v` — should still pass (naming rules unaffected).
5. Run `fw-repo-mgr status` — should show all 12 repos with correct upstream URLs.

---

## Verification

```bash
# 1. Naming rules still pass
source set_env.sh && fw-repo-mgr -v

# 2. Status table shows all repos (source_repo.name lookup still works)
fw-repo-mgr status

# 3. Confirm old key is gone from both YAML files
grep -r 'source_repos:' \
  infra/pwy-home-lab-pkg/_config/_framework_settings/framework_repo_manager.yaml \
  infra/_framework-pkg/_config/_framework_settings/framework_repo_manager.yaml

# 4. Confirm source_repo entries are now objects (not strings)
grep -A1 'source_repo:' \
  infra/pwy-home-lab-pkg/_config/_framework_settings/framework_repo_manager.yaml \
  | grep 'name:'
```
