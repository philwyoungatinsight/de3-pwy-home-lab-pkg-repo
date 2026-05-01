# Plan: Generate Local Per-Package Git Repos via fw-repo-mgr

## Objective

Create a local git repo for each of the 11 provider/infrastructure packages in de3-runner
(`de3-proxmox-pkg`, `de3-maas-pkg`, etc.), each containing one embedded package plus
`_framework-pkg` as an external dependency. Extend `fw-repo-mgr` to support a
`config_package` field that drives the config layout, and wire up `framework_repo_manager.yaml`
with all 11 target entries pointing at a local `file://` source clone of de3-runner.

## Context

### How fw-repo-mgr works today

`fw-repo-mgr -b <name>` runs a 6-step build:
1. Git-clone (or pull) a source repo into `$HOME/git/<name>/`
2. Prune `infra/` — removes real dirs NOT listed in `framework_packages`
3. Write `infra/_framework-pkg/_config/framework_packages.yaml` (hardcoded path)
4. Run `pkg-mgr --sync` to create external-package symlinks
5. Commit
6. Push to `upstream_url` if set

### Gap: config_package is not handled

For per-package repos we need:
- `config/_framework.yaml` → `config_package: <pkg>` so `set_env.sh` sets
  `_FRAMEWORK_CONFIG_PKG_DIR` to `infra/<pkg>/`
- `framework_packages.yaml` written to `infra/<pkg>/_config/_framework_settings/`
  (tier 2 in the 3-tier config lookup), not into `_framework-pkg/_config/` (tier 3)
- Two additional minimal settings files written alongside `framework_packages.yaml`:
  `framework_package_repositories.yaml` and `framework_package_management.yaml`

### Gap: external packages not pruned

`_prune_infra` currently keeps any dir whose name appears in `framework_packages` —
regardless of `package_type`. For per-package repos, `_framework-pkg` is listed as
`external`, but the initial clone from de3-runner puts it as a real dir. It must be
removed so `pkg-mgr --sync` can place the symlink.

### How pkg-mgr reuses the existing de3-runner clone

`external_package_dir: 'git/de3-ext-packages'` causes pkg-mgr to clone repos to
`$HOME/git/de3-ext-packages/<repo-slug>/<ref>/`. de3-runner is already there at
`$HOME/git/de3-ext-packages/de3-runner/main/`. Setting `source:` to the GitHub URL
(same URL that was used to originally clone it) means pkg-mgr verifies the existing
clone and creates symlinks — no re-download needed.

### set_env.sh safety without a backend

When `_framework-pkg` is external and not yet symlinked at `pkg-mgr --sync` time,
the `framework_backend.yaml` fallback in `set_env.sh` resolves to a non-existent path
and `_GCS_BUCKET` is set to empty string. This is safe — `pkg-mgr --sync` never uses
`_GCS_BUCKET`.

## Package Table

| Package | New Repo Name | Local Path | config_package |
|---------|--------------|-----------|----------------|
| aws-pkg | de3-aws-pkg | `~/git/de3-aws-pkg` | aws-pkg |
| azure-pkg | de3-azure-pkg | `~/git/de3-azure-pkg` | azure-pkg |
| de3-gui-pkg | de3-gui-pkg | `~/git/de3-gui-pkg` | de3-gui-pkg |
| demo-buckets-example-pkg | de3-demo-buckets-example-pkg | `~/git/de3-demo-buckets-example-pkg` | demo-buckets-example-pkg |
| gcp-pkg | de3-gcp-pkg | `~/git/de3-gcp-pkg` | gcp-pkg |
| image-maker-pkg | de3-image-maker-pkg | `~/git/de3-image-maker-pkg` | image-maker-pkg |
| maas-pkg | de3-maas-pkg | `~/git/de3-maas-pkg` | maas-pkg |
| mesh-central-pkg | de3-mesh-central-pkg | `~/git/de3-mesh-central-pkg` | mesh-central-pkg |
| mikrotik-pkg | de3-mikrotik-pkg | `~/git/de3-mikrotik-pkg` | mikrotik-pkg |
| proxmox-pkg | de3-proxmox-pkg | `~/git/de3-proxmox-pkg` | proxmox-pkg |
| unifi-pkg | de3-unifi-pkg | `~/git/de3-unifi-pkg` | unifi-pkg |

> **Open Question A**: `de3-gui-pkg` already has the `de3-` prefix. Should its repo be named
> `de3-gui-pkg` (no double prefix, as shown above) or `de3-de3-gui-pkg` (mechanical prefix)?

## Open Questions

**A** — Naming for `de3-gui-pkg`: see table note above. The plan assumes `de3-gui-pkg`
(no double prefix). Confirm or redirect.

**B** — Source URL for fw-repo-mgr. Two options:
  1. Local clone: `file:///home/pyoung/git/de3-ext-packages/de3-runner/main` — zero network, 
     uses the existing checkout but requires hardcoding the home dir in config.
  2. GitHub URL: `https://github.com/philwyoungatinsight/de3-runner.git` — network required 
     on first clone but already used everywhere else. fw-repo-mgr would pull to the 
     same `de3-ext-packages/de3-runner/main` path that pkg-mgr already owns.

  The plan assumes **option 2** (GitHub URL, same as existing) since that path is already
  maintained. If offline-only is required, use option 1 with `$HOME` expanded in the YAML.

**C** — Should `demo-buckets-example-pkg` be included? It is an example/demo package.
  The plan includes it for completeness; exclude if not desired.

## Files to Create / Modify

### `infra/pwy-home-lab-pkg/_config/_framework_settings/framework_repo_manager.yaml` — modify

Replace the current placeholder `framework_repos` examples with the 11 real entries.
Also add a `de3-runner-local` source_repos entry for future offline use (optional;
plan uses GitHub URL per Open Question B).

```yaml
framework_repo_manager:

  framework_repo_dir: 'git'

  source_repos:
    - name: de3-runner
      url: https://github.com/philwyoungatinsight/de3-runner.git
      ref: main

  framework_repos:

    - name: de3-aws-pkg
      source_repo: de3-runner
      config_package: aws-pkg
      framework_packages:
        - name: _framework-pkg
          package_type: external
          exportable: true
          repo: de3-runner
          source: https://github.com/philwyoungatinsight/de3-runner.git
          git_ref: main
          import_path: _framework-pkg
        - name: aws-pkg
          package_type: embedded
          exportable: true

    - name: de3-azure-pkg
      source_repo: de3-runner
      config_package: azure-pkg
      framework_packages:
        - name: _framework-pkg
          package_type: external
          exportable: true
          repo: de3-runner
          source: https://github.com/philwyoungatinsight/de3-runner.git
          git_ref: main
          import_path: _framework-pkg
        - name: azure-pkg
          package_type: embedded
          exportable: true

    - name: de3-gui-pkg
      source_repo: de3-runner
      config_package: de3-gui-pkg
      framework_packages:
        - name: _framework-pkg
          package_type: external
          exportable: true
          repo: de3-runner
          source: https://github.com/philwyoungatinsight/de3-runner.git
          git_ref: main
          import_path: _framework-pkg
        - name: de3-gui-pkg
          package_type: embedded
          exportable: true

    - name: de3-demo-buckets-example-pkg
      source_repo: de3-runner
      config_package: demo-buckets-example-pkg
      framework_packages:
        - name: _framework-pkg
          package_type: external
          exportable: true
          repo: de3-runner
          source: https://github.com/philwyoungatinsight/de3-runner.git
          git_ref: main
          import_path: _framework-pkg
        - name: demo-buckets-example-pkg
          package_type: embedded
          exportable: true

    - name: de3-gcp-pkg
      source_repo: de3-runner
      config_package: gcp-pkg
      framework_packages:
        - name: _framework-pkg
          package_type: external
          exportable: true
          repo: de3-runner
          source: https://github.com/philwyoungatinsight/de3-runner.git
          git_ref: main
          import_path: _framework-pkg
        - name: gcp-pkg
          package_type: embedded
          exportable: true

    - name: de3-image-maker-pkg
      source_repo: de3-runner
      config_package: image-maker-pkg
      framework_packages:
        - name: _framework-pkg
          package_type: external
          exportable: true
          repo: de3-runner
          source: https://github.com/philwyoungatinsight/de3-runner.git
          git_ref: main
          import_path: _framework-pkg
        - name: image-maker-pkg
          package_type: embedded
          exportable: true

    - name: de3-maas-pkg
      source_repo: de3-runner
      config_package: maas-pkg
      framework_packages:
        - name: _framework-pkg
          package_type: external
          exportable: true
          repo: de3-runner
          source: https://github.com/philwyoungatinsight/de3-runner.git
          git_ref: main
          import_path: _framework-pkg
        - name: maas-pkg
          package_type: embedded
          exportable: true

    - name: de3-mesh-central-pkg
      source_repo: de3-runner
      config_package: mesh-central-pkg
      framework_packages:
        - name: _framework-pkg
          package_type: external
          exportable: true
          repo: de3-runner
          source: https://github.com/philwyoungatinsight/de3-runner.git
          git_ref: main
          import_path: _framework-pkg
        - name: mesh-central-pkg
          package_type: embedded
          exportable: true

    - name: de3-mikrotik-pkg
      source_repo: de3-runner
      config_package: mikrotik-pkg
      framework_packages:
        - name: _framework-pkg
          package_type: external
          exportable: true
          repo: de3-runner
          source: https://github.com/philwyoungatinsight/de3-runner.git
          git_ref: main
          import_path: _framework-pkg
        - name: mikrotik-pkg
          package_type: embedded
          exportable: true

    - name: de3-proxmox-pkg
      source_repo: de3-runner
      config_package: proxmox-pkg
      framework_packages:
        - name: _framework-pkg
          package_type: external
          exportable: true
          repo: de3-runner
          source: https://github.com/philwyoungatinsight/de3-runner.git
          git_ref: main
          import_path: _framework-pkg
        - name: proxmox-pkg
          package_type: embedded
          exportable: true

    - name: de3-unifi-pkg
      source_repo: de3-runner
      config_package: unifi-pkg
      framework_packages:
        - name: _framework-pkg
          package_type: external
          exportable: true
          repo: de3-runner
          source: https://github.com/philwyoungatinsight/de3-runner.git
          git_ref: main
          import_path: _framework-pkg
        - name: unifi-pkg
          package_type: embedded
          exportable: true
```

### `_ext_packages/de3-runner/main/infra/_framework-pkg/_framework/_fw-repo-mgr/run` — modify

> **NOTE**: This file lives in the external de3-runner clone. The change should be made
> there and committed to de3-runner. If de3-runner is managed externally and changes
> cannot be pushed, an alternative is to copy `fw-repo-mgr` into
> `infra/pwy-home-lab-pkg/_framework/` as a local override — but that's tech debt.
> The plan assumes direct modification of de3-runner's copy.

**Change 1 — `_prune_infra`: also remove real dirs for external-typed packages**

Current logic keeps everything in the `keep` set. Replace with a check that only keeps
`embedded` packages:

```python
# OLD
keep = {p['name'] for p in r.get('framework_packages', [])}
# ...
if entry.name not in keep:
    shutil.rmtree(entry)

# NEW — keep only embedded packages as real dirs; external ones will be symlinked by pkg-mgr
keep_embedded = {p['name'] for p in r.get('framework_packages', [])
                 if p.get('package_type') == 'embedded'}
# ...
if entry.name not in keep_embedded:
    shutil.rmtree(entry)
```

**Change 2 — `_write_framework_packages_yaml`: write to config_package path when set**

```bash
_write_framework_packages_yaml() {
  local repo_name="$1" out_path="$2"
  python3 - "$repo_name" "$out_path" "$FW_MGR_CFG" <<'PYEOF'
import sys, yaml, pathlib
repo_name, out_path, cfg_path = sys.argv[1], sys.argv[2], sys.argv[3]
d = yaml.safe_load(pathlib.Path(cfg_path).read_text()) or {}
repos = d.get('framework_repo_manager', {}).get('framework_repos', [])
pkgs = next((r.get('framework_packages', []) for r in repos if r.get('name') == repo_name), [])
out = {'framework_packages': pkgs}
pathlib.Path(out_path).parent.mkdir(parents=True, exist_ok=True)
pathlib.Path(out_path).write_text(yaml.dump(out, default_flow_style=False, sort_keys=False))
PYEOF
}
```

(The only real change is `mkdir(parents=True, exist_ok=True)` to handle deep paths.)

**Change 3 — new helper `_config_package`**

```bash
_config_package() {  # _config_package <repo_name>  →  prints config_package or ""
  local repo_name="$1"
  python3 - "$repo_name" "$FW_MGR_CFG" <<'PYEOF'
import sys, yaml, pathlib
repo_name, cfg_path = sys.argv[1], sys.argv[2]
d = yaml.safe_load(pathlib.Path(cfg_path).read_text()) or {}
for r in d.get('framework_repo_manager', {}).get('framework_repos', []):
    if r.get('name') == repo_name:
        print(r.get('config_package', ''))
        sys.exit(0)
print('')
PYEOF
}
```

**Change 4 — new helper `_write_config_framework_yaml`**

```bash
_write_config_framework_yaml() {  # _write_config_framework_yaml <repo_dir> <config_package>
  local repo_dir="$1" config_pkg="$2"
  mkdir -p "$repo_dir/config"
  cat > "$repo_dir/config/_framework.yaml" <<EOF
_framework:
  config_package: $config_pkg
EOF
  echo "  wrote: config/_framework.yaml (config_package: $config_pkg)"
}
```

**Change 5 — new helper `_write_minimal_framework_settings`**

Writes the three files that `pkg-mgr --sync` needs before `_framework-pkg` is symlinked:

```bash
_write_minimal_framework_settings() {
  local repo_name="$1" repo_dir="$2" config_pkg="$3"
  local settings_dir="$repo_dir/infra/$config_pkg/_config/_framework_settings"
  mkdir -p "$settings_dir"

  # framework_package_repositories.yaml — tell pkg-mgr where de3-runner is
  local source_info; source_info=$(_resolve_source "$repo_name")
  local source_url="${source_info%% *}"
  cat > "$settings_dir/framework_package_repositories.yaml" <<EOF
framework_package_repositories:
  - name: de3-runner
    url: $source_url
EOF

  # framework_package_management.yaml — where to clone external packages
  python3 -c "
import yaml, pathlib, os
# read from current repo's settings
candidates = [
    '$_FRAMEWORK_CONFIG_PKG_DIR/_config/_framework_settings/framework_package_management.yaml',
    '$_FRAMEWORK_PKG_DIR/_config/_framework_settings/framework_package_management.yaml',
]
for c in candidates:
    p = pathlib.Path(c)
    if p.exists():
        print(p.read_text())
        break
" > "$settings_dir/framework_package_management.yaml"

  echo "  wrote: infra/$config_pkg/_config/_framework_settings/{framework_package_repositories,framework_package_management}.yaml"
}
```

**Change 6 — update `_build_repo` to call new helpers**

Between step 2 (prune) and step 4 (pkg-mgr sync), insert:

```bash
  # Resolve config_package for this repo
  local config_pkg; config_pkg=$(_config_package "$repo_name")

  # Step 3a: write config/_framework.yaml when config_package is set
  if [[ -n "$config_pkg" ]]; then
    _write_config_framework_yaml "$repo_dir" "$config_pkg"
  fi

  # Step 3b: determine framework_packages.yaml output path
  local fw_pkgs_out
  if [[ -n "$config_pkg" ]]; then
    fw_pkgs_out="$repo_dir/infra/$config_pkg/_config/_framework_settings/framework_packages.yaml"
    _write_minimal_framework_settings "$repo_name" "$repo_dir" "$config_pkg"
  else
    fw_pkgs_out="$repo_dir/infra/_framework-pkg/_config/framework_packages.yaml"
  fi
  mkdir -p "$(dirname "$fw_pkgs_out")"
  _write_framework_packages_yaml "$repo_name" "$fw_pkgs_out"
  echo "Wrote: $fw_pkgs_out"
```

(The existing hardcoded `fw_pkgs_out` line and its `mkdir -p` are removed.)

## Execution Order

1. **Modify `fw-repo-mgr`** — changes to the de3-runner clone at
   `_ext_packages/de3-runner/main/infra/_framework-pkg/_framework/_fw-repo-mgr/run`.
   Must be done before running the tool.

2. **Update `framework_repo_manager.yaml`** — replace placeholder entries with the 11
   real repo entries in
   `infra/pwy-home-lab-pkg/_config/_framework_settings/framework_repo_manager.yaml`.

3. **Commit both changes** to pwy-home-lab-pkg (the fw-repo-mgr change is in the
   de3-runner subtree — also commit there if de3-runner is writable).

4. **Run fw-repo-mgr** for all repos:
   ```bash
   source set_env.sh
   $_FRAMEWORK_DIR/_fw-repo-mgr/run -b
   ```
   Or individually: `fw-repo-mgr -b de3-proxmox-pkg`

5. **Verify** each repo (see Verification section).

## Verification

After running `fw-repo-mgr -b`:

```bash
# Check status table
source set_env.sh && $_FRAMEWORK_DIR/_fw-repo-mgr/run status

# For each new repo (e.g. de3-proxmox-pkg):
REPO=~/git/de3-proxmox-pkg

# 1. config_package is set
grep config_package $REPO/config/_framework.yaml
# Expected: config_package: proxmox-pkg

# 2. _framework-pkg is a symlink (external), not a real dir
ls -la $REPO/infra/_framework-pkg
# Expected: symlink → ../../de3-ext-packages/de3-runner/main/infra/_framework-pkg (or similar)

# 3. package dir is a real dir (embedded)
ls -la $REPO/infra/proxmox-pkg
# Expected: real directory (drwxr-xr-x, not a symlink)

# 4. framework_packages.yaml is in the right place
cat $REPO/infra/proxmox-pkg/_config/_framework_settings/framework_packages.yaml
# Expected: two entries — _framework-pkg (external) and proxmox-pkg (embedded)

# 5. pkg-mgr reports clean
(cd $REPO && source set_env.sh && infra/_framework-pkg/_framework/_pkg-mgr/run --status)
```
