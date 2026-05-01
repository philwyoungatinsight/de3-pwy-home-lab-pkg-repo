# Plan: Refactor Package Repos to `de3-<pkg>-repo` Naming Convention

## Objective

Normalise all framework-managed package repos so every entry in
`framework_repo_manager.framework_repos` follows the `de3-<package-name>-repo`
naming convention.  Clean up earlier inconsistent entries (`proxmox-pkg-repo`,
`de3-*-pkg` without `-repo` suffix, duplicate proxmox entries).  Add a new
`de3-[_]framework-pkg-repo` entry for the `_framework-pkg` package.  Replace
the flat `upstream_url` / `upstream_branch` fields with a structured
`new_repo_config.git-remotes` list that supports multiple remotes per repo.
Update `fw-repo-mgr` to consume the new structure.

---

## Context

### File locations

| Purpose | Path |
|---|---|
| Deployment config (tier-2, modified here) | `infra/pwy-home-lab-pkg/_config/_framework_settings/framework_repo_manager.yaml` |
| Framework default (tier-3, in de3-runner) | `infra/_framework-pkg/_config/_framework_settings/framework_repo_manager.yaml` |
| fw-repo-mgr script (in de3-runner) | `_ext_packages/de3-runner/main/infra/_framework-pkg/_framework/_fw-repo-mgr/fw-repo-mgr` |
| Main package label with typo | `config/_framework.yaml` |

> **de3-runner is an external package.**  Its files sit in `_ext_packages/de3-runner/main/`
> (a git clone).  Changes to `fw-repo-mgr` must be committed and pushed to de3-runner.

### Current repo entries and what's wrong with them

| Current name | Problem | Target name |
|---|---|---|
| `proxmox-pkg-repo` | Missing `de3-` prefix; conflicts with `de3-proxmox-pkg` | **remove** (consolidate) |
| `de3-aws-pkg` | Missing `-repo` suffix | `de3-aws-pkg-repo` |
| `de3-azure-pkg` | Missing `-repo` suffix | `de3-azure-pkg-repo` |
| `de3-gui-pkg` | Missing `-repo` suffix | `de3-gui-pkg-repo` |
| `de3-demo-buckets-example-pkg` | Missing `-repo` suffix | `de3-demo-buckets-example-pkg-repo` |
| `de3-gcp-pkg` | Missing `-repo` suffix | `de3-gcp-pkg-repo` |
| `de3-image-maker-pkg` | Missing `-repo` suffix | `de3-image-maker-pkg-repo` |
| `de3-maas-pkg` | Missing `-repo` suffix | `de3-maas-pkg-repo` |
| `de3-mesh-central-pkg` | Missing `-repo` suffix | `de3-mesh-central-pkg-repo` |
| `de3-mikrotik-pkg` | Missing `-repo` suffix | `de3-mikrotik-pkg-repo` |
| `de3-proxmox-pkg` | Missing `-repo` suffix; absorbs `proxmox-pkg-repo` | `de3-proxmox-pkg-repo` |
| `de3-unifi-pkg` | Missing `-repo` suffix | `de3-unifi-pkg-repo` |
| *(missing)* | No entry for `_framework-pkg` | `de3-[_]framework-pkg-repo` |

### `proxmox-pkg-repo` vs `de3-proxmox-pkg` — the duplicate

Both entries embed `proxmox-pkg`.
- `proxmox-pkg-repo`: only `proxmox-pkg` embedded; has `upstream_url` set.
- `de3-proxmox-pkg`: `proxmox-pkg` embedded + `unifi-pkg` external.

After renaming both would be `de3-proxmox-pkg-repo`.  Resolution: remove
`proxmox-pkg-repo`; rename `de3-proxmox-pkg` → `de3-proxmox-pkg-repo`; migrate
the `upstream_url` from `proxmox-pkg-repo` into `new_repo_config.git-remotes`.

### Only one file has `upstream_url` today

Only `proxmox-pkg-repo` has `upstream_url: https://github.com/philwyoungatinsight/proxmox-pkg-repo.git`.
All other entries lack it.  The plan proposes adding `new_repo_config.git-remotes`
for ALL repos using the expected URL pattern
`https://github.com/philwyoungatinsight/de3-<X>-repo.git` — see Open Question 3.

### `repo_names_must_not_contain_special_chars` clash with `_framework-pkg`

The naming validation regex is `^[a-z0-9][a-z0-9-]*$`, which rejects underscores.
`de3-_framework-pkg-repo` fails because `_` follows the first hyphen.  See Open Question 1.

### `config/_framework.yaml` typo

`labels._docs` contains `https://gitlab.com/pwyoung/pwy-home-pkg` (missing `-lab`).
Correct value: `https://github.com/philwyoungatinsight/pwy-home-lab-pkg`.

---

## Open Questions

**Answer all of these before executing.**

### 1 — `_framework-pkg` repo name and naming-rule update

The desired name `de3-_framework-pkg-repo` contains `_` which fails
`repo_names_must_not_contain_special_chars` (`^[a-z0-9][a-z0-9-]*$`).

Options:
- **(A) `de3-framework-pkg-repo`** — drop the leading underscore from the package portion of the repo name; no rule change needed.
- **(B) `de3-_framework-pkg-repo`** — keep exact name; update the special-chars regex in both the tier-2 YAML and `_validate_naming_rules` Python code to `^[a-z0-9_][a-z0-9_-]*$` (allow `_` anywhere).

> What name do you want, and should the rule be updated?

### 2 — `de3-proxmox-pkg-repo` external deps

`de3-proxmox-pkg` includes `unifi-pkg` as an external dependency.
`proxmox-pkg-repo` does not.

After consolidation, should `de3-proxmox-pkg-repo` include `unifi-pkg` as external?
(Almost certainly yes — confirm.)

### 3 — Pre-populate `git-source` URLs for repos without `upstream_url`

Only `proxmox-pkg-repo` has a live `upstream_url` today.  Two options for the other repos:

- **(A) Populate now** — add `new_repo_config.git-remotes[0].git-source` for every repo
  using the expected URL (`https://github.com/philwyoungatinsight/<repo-name>.git`).
  The remote won't be pushed until the GitHub repo is created, but the config is ready.
- **(B) Populate lazily** — only add `new_repo_config` where an `upstream_url` currently exists;
  leave others without it until the GitHub repo exists.

> Recommend (A) to keep the config complete.  Confirm?

### 4 — Backward compatibility for `upstream_url` in `fw-repo-mgr`

Should `fw-repo-mgr` keep reading `upstream_url` / `upstream_branch` as a fallback
(so old YAML entries still work), or do a **hard cutover** — require `new_repo_config`
and error if only the old fields are present?

> Recommend keeping a silent fallback so the script doesn't break mid-migration.  Confirm?

---

## Files to Create / Modify

### 1. `infra/pwy-home-lab-pkg/_config/_framework_settings/framework_repo_manager.yaml` — modify

Replace the `framework_repos` block entirely.  Key changes:
- Remove `proxmox-pkg-repo`.
- Rename all entries per the table above.
- Replace `upstream_url` / `upstream_branch` with `new_repo_config.git-remotes`.
- Add `de3-[_]framework-pkg-repo` entry (name per Q1 answer).

New entry structure (example for proxmox):

```yaml
- name: de3-proxmox-pkg-repo
  source_repo: de3-runner
  new_repo_config:
    git-remotes:
      - name: origin
        git-source: https://github.com/philwyoungatinsight/de3-proxmox-pkg-repo.git
        git-ref: main
  labels:
    - name: _purpose
      value: "Proxmox VE hypervisor provisioning and VM management with UniFi network integration"
    - name: _docs
      value: "https://github.com/philwyoungatinsight/de3-proxmox-pkg-repo"
  framework_packages:
    - name: proxmox-pkg
      package_type: embedded
      exportable: true
      is_config_package: true
    - name: unifi-pkg
      package_type: external
      exportable: true
      repo: de3-runner
      source: https://github.com/philwyoungatinsight/de3-runner.git
      git_ref: main
```

New entry for `_framework-pkg` (name per Q1 answer; example uses option A):

```yaml
- name: de3-framework-pkg-repo
  source_repo: de3-runner
  new_repo_config:
    git-remotes:
      - name: origin
        git-source: https://github.com/philwyoungatinsight/de3-framework-pkg-repo.git
        git-ref: main
  labels:
    - name: _purpose
      value: "Core framework package providing wave orchestration, pkg-mgr, and all framework tooling"
    - name: _docs
      value: "https://github.com/philwyoungatinsight/de3-framework-pkg-repo"
  framework_packages:
    - name: _framework-pkg
      package_type: embedded
      exportable: true
      is_config_package: true
```

If Q1 answer is option (B), update `framework_package_naming_rules` in this file to add:
```yaml
    - name: repo_names_must_not_contain_special_chars
      value: false   # replaced by updated regex in fw-repo-mgr
```
and update the regex in `fw-repo-mgr` (see §2).

---

### 2. `_ext_packages/de3-runner/main/infra/_framework-pkg/_framework/_fw-repo-mgr/fw-repo-mgr` — modify

**a) Add `_resolve_remotes()` helper** (after `_repo_field`, around line 232):

```bash
# Returns JSON array of git-remote objects from new_repo_config.git-remotes,
# falling back to [{name:origin, git-source:<upstream_url>, git-ref:<upstream_branch>}]
# if new_repo_config is absent (backward compat).
_resolve_remotes() {   # _resolve_remotes <repo_name>  →  JSON array
  local repo_name="$1"
  python3 - "$repo_name" "$FW_MGR_CFG" <<'PYEOF'
import sys, yaml, pathlib, json
repo_name, cfg_path = sys.argv[1], sys.argv[2]
d = yaml.safe_load(pathlib.Path(cfg_path).read_text()) or {}
for r in d.get('framework_repo_manager', {}).get('framework_repos', []):
    if r.get('name') != repo_name:
        continue
    new_cfg = r.get('new_repo_config') or {}
    remotes = new_cfg.get('git-remotes', [])
    if remotes:
        print(json.dumps(remotes))
        sys.exit(0)
    # Backward compat: old upstream_url / upstream_branch fields
    url = r.get('upstream_url', '')
    if url:
        branch = r.get('upstream_branch') or 'main'
        print(json.dumps([{'name': 'origin', 'git-source': url, 'git-ref': branch}]))
        sys.exit(0)
    print('[]')
    sys.exit(0)
print('[]')
PYEOF
}
```

**b) Replace Step 6 in `_build_repo()`** (lines 549–563):

```bash
  # Step 6: configure and push to all remotes in new_repo_config.git-remotes
  local remotes_json; remotes_json=$(_resolve_remotes "$repo_name")
  echo "$remotes_json" | python3 -c "
import json, sys
for r in json.load(sys.stdin):
    print(r.get('name',''), r.get('git-source',''), r.get('git-ref','main'))
" | while IFS=' ' read -r remote_name git_source git_ref; do
    [[ -z "$git_source" ]] && continue
    git -C "$repo_dir" remote get-url "$remote_name" &>/dev/null || \
      git -C "$repo_dir" remote add "$remote_name" "$git_source"
    local cur; cur=$(git -C "$repo_dir" remote get-url "$remote_name" 2>/dev/null || true)
    [[ "$cur" != "$git_source" ]] && git -C "$repo_dir" remote set-url "$remote_name" "$git_source"
    if [[ "$force_push" == "true" ]]; then
      git -C "$repo_dir" push --force -u "$remote_name" "$git_ref"
    else
      git -C "$repo_dir" push -u "$remote_name" "$git_ref"
    fi
    echo "Pushed: $repo_name → $git_source ($git_ref) via $remote_name"
  done
```

**c) Update `_status()` to show first `git-source` instead of `upstream_url`** (lines 578–585):

Change the Python snippet inside `_status()` from:
```python
up = r.get('upstream_url', '(none)')
```
to:
```python
remotes = (r.get('new_repo_config') or {}).get('git-remotes', [])
if remotes:
    up = remotes[0].get('git-source', '(none)')
else:
    up = r.get('upstream_url', '(none)')   # backward compat
```

**d) If Q1 answer is option (B)** — update `_validate_naming_rules` special-chars regex
(line 161) from:
```python
if not re.match(r'^[a-z0-9][a-z0-9-]*$', n):
```
to:
```python
if not re.match(r'^[a-z0-9_][a-z0-9_-]*$', n):
```

---

### 3. `config/_framework.yaml` — modify

Fix the `_docs` label value (line 8):
```yaml
    - name: _docs
      value: https://github.com/philwyoungatinsight/pwy-home-lab-pkg
```

---

## Execution Order

1. Fix `config/_framework.yaml` typo (trivial, no dependencies).
2. Rewrite `framework_repo_manager.yaml` with renamed entries + `new_repo_config` structure.
3. Update `fw-repo-mgr` in de3-runner external package cache:
   a. Add `_resolve_remotes()`.
   b. Replace Step 6.
   c. Update `_status()` Python snippet.
   d. (Conditional on Q1-B) Update special-chars regex.
4. Run `fw-repo-mgr -v` to confirm naming validation passes.
5. Commit `config/_framework.yaml` + `framework_repo_manager.yaml` to `pwy-home-lab-pkg`.
6. Commit `fw-repo-mgr` to the de3-runner clone, push to `philwyoungatinsight/de3-runner`.

---

## Verification

```bash
# 1. Validate naming rules pass
fw-repo-mgr -v

# 2. Check status table shows new names and git-source URLs
fw-repo-mgr status

# 3. Spot-check one repo build (dry run — no push)
fw-repo-mgr -b de3-unifi-pkg-repo

# 4. Confirm no references to old names remain
grep -r 'proxmox-pkg-repo\|de3-proxmox-pkg\b\|de3-aws-pkg\b\|upstream_url' \
  infra/pwy-home-lab-pkg/_config/_framework_settings/framework_repo_manager.yaml
```
