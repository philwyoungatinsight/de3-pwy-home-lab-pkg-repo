# Plan: Replace All Direct `sops --set` Calls with `config-mgr`

## Objective

Ensure that `sops --set` is called in exactly one place — `config_mgr/sops.py` — and that
all other code reaches it via `config-mgr set-raw --sops` (bash) or
`{{ lookup('env', '_CONFIG_MGR') }}` (Ansible). This eliminates duplicated credential-writing
logic in three cloud seed scripts and fixes five stale `_config-mgr/run` references left
over from the c41cabb rename of framework tool scripts.

## Context

**Canonical location of `sops --set`:**
`de3-ext-packages/de3-runner/main/infra/_framework-pkg/_framework/_config-mgr/config_mgr/sops.py:37`
— `set_key()` — the only place `sops --set` should appear.

**`set_env.sh` exports:** `_CONFIG_MGR="$_FRAMEWORK_DIR/_config-mgr/config-mgr"`
All scripts that source `set_env.sh` already have `$_CONFIG_MGR` available.

**Direct `sops --set` calls that must be replaced** (all in `de3-ext-packages/de3-runner/main/`):
- `infra/aws-pkg/_setup/seed` — 4 calls in `_write_credentials_to_sops()` and `_clear_credentials_from_sops()`
- `infra/azure-pkg/_setup/seed` — 4 calls in `_write_credentials_to_sops()` and `_clear_sops_credentials()`
- `infra/gcp-pkg/_setup/seed` — 2 calls in `_write_sa_key_to_sops()` and `_clear_sa_key_from_sops()`

**Stale `_config-mgr/run` references that must be fixed** (renamed to `config-mgr` in c41cabb):
- `infra/proxmox-pkg/_tg_scripts/proxmox/configure/tasks/configure-api-token.yaml` (lines 66, 75)
- `infra/maas-pkg/_tg_scripts/maas/configure-server/tasks/install-maas.yaml` (line 330)
- `infra/maas-pkg/_tg_scripts/maas/sync-api-key/playbook.yaml` (line 54)
- `infra/maas-pkg/_tg_scripts/maas/configure-region/tasks/install-maas.yaml` (line 279)

**Empty-string handling:** `yaml.safe_load("")` returns `None`; `str(None)` = `"None"`.
To pass an empty string via `config-mgr`, use the YAML double-quoted scalar `'""'` on the
command line — `yaml.safe_load('""')` correctly yields Python `""`.

**GCP JSON credential:** the bash seed script pre-encodes the SA key as a JSON string
(`json.dumps(compact_json)`), producing `"{\"type\":\"service_account\",...}"`. Passing
this as `"$key_json_encoded"` to `config-mgr` works: YAML parses the outer `"..."` as a
string scalar, `_quote_value()` re-escapes for the sops expression, and SOPS stores the
compact JSON as a string value — identical to the direct `sops --set` behaviour.

## Open Questions

None — ready to proceed.

## Files to Create / Modify

All paths are relative to `de3-ext-packages/de3-runner/main/`.

---

### `infra/aws-pkg/_setup/seed` — modify

**`_write_credentials_to_sops()` (lines 78–83):**

Replace:
```bash
SOPS_AGE_KEY_FILE="$HOME/.sops/age/keys.txt" sops --set \
    "[\"aws-pkg_secrets\"][\"providers\"][\"aws\"][\"access_key_id\"] \"$key_id\"" \
    "$sops_file"
SOPS_AGE_KEY_FILE="$HOME/.sops/age/keys.txt" sops --set \
    "[\"aws-pkg_secrets\"][\"providers\"][\"aws\"][\"secret_access_key\"] \"$secret\"" \
    "$sops_file"
```

With:
```bash
"$_CONFIG_MGR" set-raw aws-pkg aws-pkg_secrets.providers.aws.access_key_id "$key_id" --sops
"$_CONFIG_MGR" set-raw aws-pkg aws-pkg_secrets.providers.aws.secret_access_key "$secret" --sops
```

**`_clear_credentials_from_sops()` (lines 92–97):**

Replace:
```bash
SOPS_AGE_KEY_FILE="$HOME/.sops/age/keys.txt" sops --set \
    "[\"aws-pkg_secrets\"][\"providers\"][\"aws\"][\"access_key_id\"] \"\"" \
    "$sops_file" 2>/dev/null || true
SOPS_AGE_KEY_FILE="$HOME/.sops/age/keys.txt" sops --set \
    "[\"aws-pkg_secrets\"][\"providers\"][\"aws\"][\"secret_access_key\"] \"\"" \
    "$sops_file" 2>/dev/null || true
```

With:
```bash
"$_CONFIG_MGR" set-raw aws-pkg aws-pkg_secrets.providers.aws.access_key_id '""' --sops 2>/dev/null || true
"$_CONFIG_MGR" set-raw aws-pkg aws-pkg_secrets.providers.aws.secret_access_key '""' --sops 2>/dev/null || true
```

Also remove the `[ ! -f "$sops_file" ]` guard and `sops_file` local var in both functions
— `config-mgr` performs its own file-exists check and errors clearly.

---

### `infra/azure-pkg/_setup/seed` — modify

**`_write_credentials_to_sops()` (lines 40–45):**

Replace:
```bash
SOPS_AGE_KEY_FILE="$HOME/.sops/age/keys.txt" sops --set \
    "[\"azure-pkg_secrets\"][\"providers\"][\"azure\"][\"client_id\"] \"$client_id\"" \
    "$sops_file"
SOPS_AGE_KEY_FILE="$HOME/.sops/age/keys.txt" sops --set \
    "[\"azure-pkg_secrets\"][\"providers\"][\"azure\"][\"client_secret\"] \"$client_secret\"" \
    "$sops_file"
```

With:
```bash
"$_CONFIG_MGR" set-raw azure-pkg azure-pkg_secrets.providers.azure.client_id "$client_id" --sops
"$_CONFIG_MGR" set-raw azure-pkg azure-pkg_secrets.providers.azure.client_secret "$client_secret" --sops
```

**`_clear_sops_credentials()` (lines 55–59):**

Replace:
```bash
SOPS_AGE_KEY_FILE="$HOME/.sops/age/keys.txt" sops --set \
    "[\"azure-pkg_secrets\"][\"providers\"][\"azure\"][\"client_id\"] \"\"" \
    "$sops_file" 2>/dev/null || true
SOPS_AGE_KEY_FILE="$HOME/.sops/age/keys.txt" sops --set \
    "[\"azure-pkg_secrets\"][\"providers\"][\"azure\"][\"client_secret\"] \"\"" \
    "$sops_file" 2>/dev/null || true
```

With:
```bash
"$_CONFIG_MGR" set-raw azure-pkg azure-pkg_secrets.providers.azure.client_id '""' --sops 2>/dev/null || true
"$_CONFIG_MGR" set-raw azure-pkg azure-pkg_secrets.providers.azure.client_secret '""' --sops 2>/dev/null || true
```

Also remove the `sops_file` local var and `[ ! -f "$sops_file" ]` / `[ -z "$sops_file" ]` guards.

---

### `infra/gcp-pkg/_setup/seed` — modify

**`_write_sa_key_to_sops()` (lines 113–118):**

Replace:
```bash
# Compact-encode the JSON key, then JSON-encode that string for sops --set
key_json_encoded=$(jq -c . "$KEY_FILE" | python3 -c 'import sys, json; print(json.dumps(sys.stdin.read().strip()))')
SOPS_AGE_KEY_FILE="$HOME/.sops/age/keys.txt" sops --set \
    "[\"gcp-pkg_secrets\"][\"providers\"][\"gcp\"][\"credentials\"] $key_json_encoded" \
    "$sops_file"
```

With:
```bash
key_json_encoded=$(jq -c . "$KEY_FILE" | python3 -c 'import sys, json; print(json.dumps(sys.stdin.read().strip()))')
"$_CONFIG_MGR" set-raw gcp-pkg gcp-pkg_secrets.providers.gcp.credentials "$key_json_encoded" --sops
```

The `key_json_encoded` variable (outer-double-quoted JSON string) passes through
`yaml.safe_load` as a Python string, is re-escaped by `_quote_value()`, and produces an
identical sops expression.

**`_clear_sa_key_from_sops()` (lines 126–128):**

Replace:
```bash
SOPS_AGE_KEY_FILE="$HOME/.sops/age/keys.txt" sops --set \
    "[\"gcp-pkg_secrets\"][\"providers\"][\"gcp\"][\"credentials\"] \"\"" \
    "$sops_file" 2>/dev/null || true
```

With:
```bash
"$_CONFIG_MGR" set-raw gcp-pkg gcp-pkg_secrets.providers.gcp.credentials '""' --sops 2>/dev/null || true
```

Also remove the `sops_file` local var and `[ ! -f "$sops_file" ]` / `[ -z "$sops_file" ]` guards.

---

### `infra/proxmox-pkg/_tg_scripts/proxmox/configure/tasks/configure-api-token.yaml` — modify

Lines 66 and 75: replace `{{ lookup('env', '_FRAMEWORK_DIR') }}/_config-mgr/run` with
`{{ lookup('env', '_CONFIG_MGR') }}`.

```yaml
# Before:
    {{ lookup('env', '_FRAMEWORK_DIR') }}/_config-mgr/run
    set {{ pve_config_path }} token.id {{ _new_token_id }} --sops
# After:
    {{ lookup('env', '_CONFIG_MGR') }}
    set {{ pve_config_path }} token.id {{ _new_token_id }} --sops
```

Apply the same substitution for the `token.secret` task on line 75.

---

### `infra/maas-pkg/_tg_scripts/maas/configure-server/tasks/install-maas.yaml` — modify

Line 330: same substitution.

```yaml
# Before:
    {{ lookup('env', '_FRAMEWORK_DIR') }}/_config-mgr/run
# After:
    {{ lookup('env', '_CONFIG_MGR') }}
```

---

### `infra/maas-pkg/_tg_scripts/maas/sync-api-key/playbook.yaml` — modify

Line 54: same substitution.

---

### `infra/maas-pkg/_tg_scripts/maas/configure-region/tasks/install-maas.yaml` — modify

Line 279: same substitution.

---

## Execution Order

1. Fix the five Ansible task files (stale `run` → `_CONFIG_MGR` env var). These are broken
   references that affect live automation; fix first.
2. Replace `sops --set` in `aws-pkg/_setup/seed`.
3. Replace `sops --set` in `azure-pkg/_setup/seed`.
4. Replace `sops --set` in `gcp-pkg/_setup/seed`.
5. Commit all changes together in `de3-ext-packages/de3-runner/main` with message:
   `refactor(config-mgr): replace direct sops --set calls with config-mgr set-raw`
6. Write ai-log entry and bump `_framework-pkg` version in `de3-ext-packages`.

## Verification

```bash
# Confirm no direct sops --set outside sops.py:
grep -r "sops --set" de3-ext-packages/de3-runner/main/infra \
  --exclude-dir=".git" | grep -v "sops\.py:" | grep -v "\.md:"
# Expected: zero results

# Confirm no stale _config-mgr/run references:
grep -r "_config-mgr/run" de3-ext-packages/de3-runner/main/infra \
  --exclude-dir=".git" | grep -v "\.md:"
# Expected: zero results
```
