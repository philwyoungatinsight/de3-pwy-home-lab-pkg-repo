# Plan: Ensure Package Names End in `-pkg`

## Objective

Enforce that all framework package names end with the `-pkg` suffix. This rule is
already followed by every package in production (`aws-pkg`, `maas-pkg`, `_framework-pkg`,
etc.), but is not yet machine-checked, so a typo in a CLI arg or a YAML edit could
silently introduce a non-conforming name. Validation should fire at every point where a
new name is accepted — both CLI operations and direct config edits — so the rule cannot
be bypassed.

## Context

**Two tools manage package names:**

- `infra/_framework-pkg/_framework/_pkg-mgr/pkg-mgr` — CLI for adding/renaming/copying
  packages; `--sync` reads `framework_packages.yaml`
- `infra/_framework-pkg/_framework/_fw-repo-mgr/fw-repo-mgr` — reads
  `framework_repo_manager.yaml`, assembles and writes `framework_packages.yaml` into
  target repos, then calls `pkg-mgr --sync`

**All current production package names end in `-pkg`**, including `_framework-pkg`
(the `_` prefix does not conflict — the suffix rule is `*-pkg`).

**Entry points where a new package name is first accepted:**

| Operation | Tool | Where name arrives |
|-----------|------|--------------------|
| `import <repo> <pkg>` | pkg-mgr | CLI arg, `_cmd_import()` line 518 |
| `rename <src> <dst>` | pkg-mgr | CLI arg, `_cmd_rename()` line 994 |
| `copy <src> <dst>` | pkg-mgr | CLI arg, `_cmd_copy()` line 1164 |
| `--sync` | pkg-mgr | Reads `framework_packages.yaml` Python heredoc, lines 360–398 |
| `build` | fw-repo-mgr | Reads `framework_repo_manager.yaml`, `_write_framework_packages_yaml()` lines 197–216 |

`remove` and `add-repo` operate on already-registered names — no validation needed.

**Config example in `framework_repo_manager.yaml` has `name: my-homelab`** (a package
without the `-pkg` suffix). This example needs to be updated to avoid confusion.

## Open Questions

None — ready to proceed.

## Files to Create / Modify

### `infra/_framework-pkg/_framework/_pkg-mgr/pkg-mgr` — modify

**1. Add bash helper after `EXT_PACKAGES_DIR` / `INFRA_DIR` setup block (around line 8):**

```bash
_assert_pkg_name() {
  local name="$1"
  [[ "$name" == *-pkg ]] && return 0
  echo "ERROR: package name '$name' must end in '-pkg' (e.g. '${name}-pkg')" >&2
  exit 1
}
```

Place it right after the `INFRA_DIR=` line (line 7), before `_fw_cfg()`.

**2. Call it in `_cmd_import()` — after the `--git-ref` required check (~line 534):**

```bash
  if [[ -z "$git_ref" ]]; then
    echo "ERROR: --git-ref <ref> is required (e.g. --git-ref main)" >&2
    exit 1
  fi
  _assert_pkg_name "$pkg_name"   # ← add this line
```

**3. Call it in `_cmd_rename()` — after the usage check (~line 1005):**

```bash
  if [[ -z "$src" || -z "$dst" ]]; then
    echo "Usage: pkg-mgr rename <src-pkg> <dst-pkg> [--dry-run] [--skip-state]" >&2; exit 1
  fi
  _assert_pkg_name "$dst"   # ← add this line
```

**4. Call it in `_cmd_copy()` — after the `--skip-state/--with-state` required check (~line 1184):**

```bash
  if [[ "$dry_run" == false && -z "$state_flag" ]]; then
    echo "ERROR: copy requires --skip-state or --with-state" >&2
    ...
    exit 1
  fi
  _assert_pkg_name "$dst"   # ← add this line
```

**5. Add name validation inside `_cmd_sync()`'s Python heredoc — extend the existing
`invalid` list check at ~line 375 by adding a name check in the same loop:**

The existing loop starts at `for p in pkgs:` and builds `invalid`. Add a name check
**before** the `package_type` check so it runs for every entry:

```python
for p in pkgs:
    if not p["name"].endswith("-pkg"):
        invalid.append(f"  '{p['name']}': package name must end in '-pkg'")
    pt = p.get("package_type", "")
    if pt not in ("embedded", "external"):
        ...
```

This reuses the existing `invalid`/`sys.exit(1)` error-reporting pattern already in
place for `package_type` validation.

---

### `infra/_framework-pkg/_framework/_fw-repo-mgr/fw-repo-mgr` — modify

**Add name validation inside `_write_framework_packages_yaml()`'s Python heredoc
(~lines 199–216), after the `framework_package_template` injection block and before
the `out = ...` write line:**

```python
# Validate all package names before writing
invalid_names = [p['name'] for p in pkgs if not p['name'].endswith('-pkg')]
if invalid_names:
    for n in invalid_names:
        print(f"ERROR: package name '{n}' must end in '-pkg'", file=sys.stderr)
    sys.exit(1)

out = {'framework_packages': pkgs}
```

This catches hand-edits to `framework_repo_manager.yaml` before the bad name propagates
to `framework_packages.yaml` or downstream `pkg-mgr --sync`.

---

### `infra/_framework-pkg/_config/_framework_settings/framework_repo_manager.yaml` — modify

Update the example `name: my-homelab` package (inside the `my-homelab` repo entry's
`framework_packages` list) to `name: my-homelab-pkg` so the example itself satisfies
the rule. This is a YAML comment block — no runtime impact.

Change:
```yaml
        - name: my-homelab
          package_type: embedded
          exportable: false
          is_config_package: true
```
to:
```yaml
        - name: my-homelab-pkg
          package_type: embedded
          exportable: false
          is_config_package: true
```

Also update the repo's `upstream_url` example line above to reference `my-homelab-pkg`
if the package name appears there — it doesn't, so no further change needed.

## Execution Order

1. `pkg-mgr` — add `_assert_pkg_name()` helper + 3 bash call sites (import, rename, copy)
2. `pkg-mgr` — add name check into `_cmd_sync()` Python heredoc
3. `fw-repo-mgr` — add name validation into `_write_framework_packages_yaml()` Python heredoc
4. `framework_repo_manager.yaml` — update example package name

Steps 1–3 are independent of each other and can be done in any order. Step 4 is a cosmetic
YAML change with no dependencies.

## Verification

```bash
# 1. CLI guards
pkg-mgr --import de3-runner badname --git-ref main
# Expected: ERROR: package name 'badname' must end in '-pkg'

pkg-mgr --rename aws-pkg notpkg
# Expected: ERROR: package name 'notpkg' must end in '-pkg'

pkg-mgr --copy aws-pkg also-bad
# Expected: ERROR: package name 'also-bad' must end in '-pkg'

# 2. Sync guard — temporarily add a bad name to framework_packages.yaml,
#    run sync, verify error, then revert
echo "  - name: bad-name
    package_type: embedded
    exportable: false" >> infra/_framework-pkg/_config/_framework_settings/framework_packages.yaml
pkg-mgr --sync
# Expected: ERROR: 'bad-name': package name must end in '-pkg'
git checkout infra/_framework-pkg/_config/_framework_settings/framework_packages.yaml

# 3. fw-repo-mgr guard — temporarily add a bad name to framework_repo_manager.yaml
#    under an existing repo entry, run fw-repo-mgr build, verify error, then revert
```
