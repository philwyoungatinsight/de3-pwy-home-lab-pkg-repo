# Plan: SOPS Config Override Support — Multiple Templates

## Objective

Rename `framework_repo_manager.framework_settings_sops_template` (a single dict) to
`framework_repo_manager.framework_settings_sops_templates` (a list of named dicts). Each list
entry has a `name:` field; the existing config becomes `name: default`. Each entry in
`framework_repos` gains `sops-template: default`, explicitly naming which template to use. The
`_write_sops_yaml()` function in `fw-repo-mgr` is updated to look up the named template, write
its content (minus the `name:` key) to `.sops.yaml`, and error clearly when a named template
is not found. Behaviour is identical to today, but the data model now supports additional named
templates for repos that need different SOPS keys.

## Context

- **Config file** (active, in this repo):
  `infra/pwy-home-lab-pkg/_config/_framework_settings/framework_repo_manager.yaml`
  — has `framework_settings_sops_template` (singular, dict), 12 repos in `framework_repos`
  (none currently has a `sops-template:` key).

- **Code file** (in de3-runner external package):
  `de3-ext-packages/de3-runner/main/infra/_framework-pkg/_framework/_fw-repo-mgr/run`
  — `_write_sops_yaml()` (lines 484–499) reads `framework_settings_sops_template`, writes
  the whole dict to `.sops.yaml`. Called at line 627: `_write_sops_yaml "$repo_dir"`.
  The enclosing function `_build_repo()` has `$repo_name` already in scope.

- **de3-runner default template** (commented-out example):
  `de3-ext-packages/de3-runner/main/infra/_framework-pkg/_config/_framework_settings/framework_repo_manager.yaml`
  — has `framework_settings_sops_template` commented out as an example. Comment needs
  updating to show the new plural list syntax; no functional change (no repos in this file).

- **No backward compat needed**: both config files will be updated atomically with the code
  change. No other consumer of `framework_settings_sops_template` was found in the codebase.

## Open Questions

None — ready to proceed.

## Files to Create / Modify

### `infra/pwy-home-lab-pkg/_config/_framework_settings/framework_repo_manager.yaml` — modify

Two changes:

**1. Rename key and wrap in list:**

```yaml
# Before:
  framework_settings_sops_template:
    stores:
      yaml:
        indent: 2
    creation_rules:
      ...

# After:
  framework_settings_sops_templates:
    - name: default
      stores:
        yaml:
          indent: 2
      creation_rules:
        ...
```

Update the comment above the block from:
```
# Template written as .sops.yaml at the git root of every generated repo.
# Content is not secret (PGP fingerprints are public) — lives in plaintext config.
# fw-repo-mgr writes this after rsync/pull, overriding any .sops.yaml inherited
# from the source template.
```
to:
```
# List of named SOPS templates written as .sops.yaml at the git root of generated repos.
# Each entry has a "name:" field; repos reference a template via "sops-template: <name>".
# The "default" entry is used when sops-template is absent. Content is not secret
# (PGP fingerprints are public) — lives in plaintext config.
# fw-repo-mgr writes the matching template after rsync/pull, overriding any .sops.yaml
# inherited from the source template.
```

**2. Add `sops-template: default` to every entry under `framework_repos`:**

Each of the 12 repo entries gains one line immediately after `name:`:
```yaml
    - name: de3-_framework-pkg-repo
      sops-template: default
      local_only: true
      ...
```

Add it consistently on the line after `name:` for each repo entry. All 12 repos:
`de3-_framework-pkg-repo`, `de3-aws-pkg-repo`, `de3-azure-pkg-repo`, `de3-gui-pkg-repo`,
`de3-gcp-pkg-repo`, `de3-image-maker-pkg-repo`, `de3-maas-pkg-repo`,
`de3-mesh-central-pkg-repo`, `de3-mikrotik-pkg-repo`, `de3-proxmox-pkg-repo`,
`de3-unifi-pkg-repo`, `de3-pwy-home-lab-pkg-repo`, `de3-central-index-repo`.

---

### `de3-ext-packages/de3-runner/main/infra/_framework-pkg/_framework/_fw-repo-mgr/run` — modify

**1. Replace `_write_sops_yaml()` (lines 484–499):**

```bash
# Before (single template, no per-repo selection):
_write_sops_yaml() {   # _write_sops_yaml <repo_dir>
  local repo_dir="$1"
  [[ -z "$FW_MGR_CFG" ]] && return 0

  python3 - "$repo_dir" "$FW_MGR_CFG" <<'PYEOF'
import sys, yaml, pathlib
repo_dir, cfg_path = sys.argv[1], sys.argv[2]
d = yaml.safe_load(pathlib.Path(cfg_path).read_text()) or {}
template = d.get('framework_repo_manager', {}).get('framework_settings_sops_template')
if not template:
    sys.exit(0)
out_path = pathlib.Path(repo_dir) / '.sops.yaml'
out_path.write_text(yaml.dump(template, default_flow_style=False, sort_keys=False))
print(f'  wrote: .sops.yaml')
PYEOF
}
```

```bash
# After (list of named templates, per-repo selection):
_write_sops_yaml() {   # _write_sops_yaml <repo_dir> <repo_name>
  local repo_dir="$1" repo_name="$2"
  [[ -z "$FW_MGR_CFG" ]] && return 0

  python3 - "$repo_dir" "$repo_name" "$FW_MGR_CFG" <<'PYEOF'
import sys, yaml, pathlib
repo_dir, repo_name, cfg_path = sys.argv[1], sys.argv[2], sys.argv[3]
d = yaml.safe_load(pathlib.Path(cfg_path).read_text()) or {}
fm = d.get('framework_repo_manager', {})

templates = fm.get('framework_settings_sops_templates') or []
if not templates:
    sys.exit(0)

# Determine which template name this repo wants (default: 'default')
template_name = 'default'
for r in fm.get('framework_repos') or []:
    if r.get('name') == repo_name:
        template_name = r.get('sops-template', 'default')
        break

entry = next((t for t in templates if t.get('name') == template_name), None)
if entry is None:
    sys.stderr.write(
        f"ERROR: sops template '{template_name}' not found in "
        f"framework_settings_sops_templates (repo: {repo_name})\n"
    )
    sys.exit(1)

content = {k: v for k, v in entry.items() if k != 'name'}
out_path = pathlib.Path(repo_dir) / '.sops.yaml'
out_path.write_text(yaml.dump(content, default_flow_style=False, sort_keys=False))
print(f'  wrote: .sops.yaml ({template_name})')
PYEOF
}
```

**2. Update the call site at line 626–627:**

```bash
# Before:
  # Write .sops.yaml from framework_settings_sops_template
  _write_sops_yaml "$repo_dir"

# After:
  # Write .sops.yaml from framework_settings_sops_templates
  _write_sops_yaml "$repo_dir" "$repo_name"
```

---

### `de3-ext-packages/de3-runner/main/infra/_framework-pkg/_config/_framework_settings/framework_repo_manager.yaml` — modify

Update the commented-out example block. The comment text above it (line ~47–51) refers to
`framework_settings_sops_template` — update to `framework_settings_sops_templates`. Update the
commented-out YAML example to show the new list structure with a `name: default` entry:

```yaml
  # List of named SOPS templates written as .sops.yaml at the git root of generated repos.
  # Each entry has a "name:" field; repos reference a template via "sops-template: <name>".
  # The "default" entry is used when sops-template is absent. Content is not secret
  # (PGP fingerprints are public) — lives in plaintext config.
  #
#  framework_settings_sops_templates:
#    - name: default
#      stores:
#        yaml:
#          indent: 2
#      creation_rules:
#        - path_regex: '.*infra/[^/]+/_config/.*\.sops\.yaml$'
#          pgp: >-
#            <fingerprint1>,
#            <fingerprint2>
```

## Execution Order

1. **`de3-ext-packages/de3-runner/.../run`** — update `_write_sops_yaml()` signature + body, update call site comment + arg. Commit in the de3-runner repo.
2. **`infra/pwy-home-lab-pkg/_config/_framework_settings/framework_repo_manager.yaml`** — rename key, wrap in list, add `sops-template: default` to all 13 repos. Commit in pwy-home-lab-pkg.
3. **`de3-ext-packages/de3-runner/.../framework_repo_manager.yaml`** — update commented-out example. Commit in de3-runner (can be same commit as step 1).

Order matters: the code change (step 1) should be committed before or simultaneously with the config change (step 2), since a config using the new `framework_settings_sops_templates` key against old code would silently no-op (old code looks for the old key and finds nothing).

## Verification

1. Run `fw-repo-mgr --build de3-_framework-pkg-repo` (or any single repo).
2. Confirm `.sops.yaml` is written at the repo root with the correct `stores:` and `creation_rules:` content (matches the `default` template).
3. Confirm `sops-mgr --re-encrypt` runs without error on the target repo.
4. Run `fw-repo-mgr --status` — should show no errors for any configured repo.
5. Optionally: temporarily add a second entry to `framework_settings_sops_templates` with a different name, add `sops-template: <other-name>` to one repo, build it, and confirm the correct `.sops.yaml` is written.
