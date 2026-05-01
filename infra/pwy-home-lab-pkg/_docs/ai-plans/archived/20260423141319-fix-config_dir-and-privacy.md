# Plan: Fix _CONFIG_DIR Privacy — Remove SOPS Decryption to Disk

## Objective

`config-mgr generate` (called by `set_env.sh`) currently decrypts all SOPS secret files and writes
them as plaintext to `$_CONFIG_DIR/*.secrets.yaml`. This is a privacy violation — secrets must never
be decrypted to disk.

The fix:
1. `generator.py` copies encrypted SOPS files unchanged into `_CONFIG_DIR/<pkg>.secrets.sops.yaml`
   (no decryption).
2. `root.hcl` switches from `file()` on a plaintext `.secrets.yaml` to `sops_decrypt_file()` on a
   `.secrets.sops.yaml` — decryption happens at runtime, in memory, by Terragrunt.
3. Legacy plaintext `*.secrets.yaml` files in `_CONFIG_DIR` are removed on first run.
4. CLAUDE.md gains a rule prohibiting SOPS-to-disk decryption.
5. The ai-screw-ups log gains an entry so this is never repeated.

## Context

### What exists today
- `generator.py` calls `decrypt_to_dict(sops_path)` → parses secrets → writes
  `_CONFIG_DIR/<pkg>.secrets.yaml` (plaintext, chmod 600 but still on disk).
- `root.hcl` reads those plaintext files with plain `yamldecode(file(...))`. No `sops_decrypt_file`.
- Two plaintext files are currently in `_CONFIG_DIR`:
  - `pwy-home-lab-pkg.secrets.yaml` — real production secrets (MaaS API key, power passwords, etc.)
  - `mikrotik-pkg.secrets.yaml` — example data from the external package's SOPS file

### Original design (before this was broken)
- `root.hcl` used `sops_decrypt_file()` directly on the source SOPS files
  (`infra/<pkg>/_config/<pkg>_secrets.sops.yaml`).
- Decryption happened in-process by Terragrunt — nothing written to disk.

### All real units live in `pwy-home-lab-pkg`
- `p_package` in root.hcl is always `pwy-home-lab-pkg` for every deployed unit.
- External packages (maas-pkg, proxmox-pkg, etc.) contain only modules/providers — no terragrunt units.
- All real secrets live in `pwy-home-lab-pkg/_config/pwy-home-lab-pkg_secrets.sops.yaml`.
- Only `_CONFIG_DIR/pwy-home-lab-pkg.secrets.sops.yaml` is ever read at runtime.

### Framework package is a symlink
- `infra/_framework-pkg/` → `infra/_ext_packages/de3-runner/main/infra/_framework-pkg/`
- Edits to `generator.py` actually modify the de3-runner repo via the symlink.

## Open Questions

None — ready to proceed.

## Files to Create / Modify

### `infra/_framework-pkg/_framework/_config-mgr/config_mgr/generator.py` — modify

**Remove** the following:

1. Top of file: `from .sops import decrypt_to_dict`
2. Functions `_get_secrets_config_params` and `_build_secrets_output_yaml` (delete both entirely).
3. The "Secrets: decrypt + merge + write" block inside `generate()` (lines ~261–300, currently):
   ```python
   own_secret_params: dict = {}
   cs_secret_params: dict = {}
   if own_sops.exists():
       ...decrypt_to_dict(own_sops)...
   if has_config_source:
       ...decrypt_to_dict(cs_sops)...
   if own_secret_params or cs_secret_params:
       ...write out_secrets...chmod 0o600...
   ```

**Add** the following (in place of the removed block):

```python
# Secrets: copy encrypted SOPS file — never decrypt to disk.
# own_sops takes precedence; fall back to config_source's SOPS if own is absent.
sops_dest = config_dir / f"{pkg_name}.secrets.sops.yaml"
_sops_src: Path | None = None
if own_sops.exists():
    _sops_src = own_sops
elif has_config_source:
    cs_sops = pkg_sops_path(repo_root, config_source_name)
    if cs_sops.exists():
        _sops_src = cs_sops
if _sops_src is not None:
    _copy_file(sops_src, sops_dest)
elif sops_dest.exists():
    sops_dest.unlink()
```

**Add** helper function `_copy_file` (near the other helpers at the top):
```python
import shutil

def _copy_file(src: Path, dst: Path) -> None:
    """Atomically copy src to dst."""
    tmp = dst.with_suffix(".tmp")
    shutil.copy2(src, tmp)
    os.replace(tmp, dst)
```

**Add** staleness check for the SOPS output file (alongside the existing yaml check):
```python
# Also stale if expected SOPS output is missing
expected_sops_dest = config_dir / f"{pkg_name}.secrets.sops.yaml"
if not stale and (own_sops.exists() or (has_config_source and pkg_sops_path(repo_root, config_source_name).exists())) and not expected_sops_dest.exists():
    stale = True
```

**Add** legacy plaintext cleanup at the TOP of `generate()`, before the package loop:
```python
# Remove legacy plaintext secrets files (replaced by .secrets.sops.yaml copies)
for legacy in config_dir.glob("*.secrets.yaml"):
    legacy.unlink()
    if effective_mode in ("normal", "verbose"):
        print(f"config-mgr: removed legacy plaintext secrets file {legacy.name}", flush=True)
```

**Update** the module docstring from:
```python
"""Generate pre-merged, pre-decrypted config into $_CONFIG_DIR."""
```
to:
```python
"""Generate pre-merged config and encrypted SOPS copies into $_CONFIG_DIR."""
```

Keep staleness tracking for `own_sops` and `cs_sops` in `source_files` — we still want to
re-copy the SOPS file when it changes.

### `root.hcl` — modify

Three changes, all in the secrets loading block (lines ~78–87):

**Change 1** — package secrets path and load:
```hcl
# OLD:
_pkg_sec_path  = "${local._config_dir}/${local.p_package}.secrets.yaml"
_package_sec   = fileexists(local._pkg_sec_path) ? yamldecode(file(local._pkg_sec_path)) : {}

# NEW:
_pkg_sec_path  = "${local._config_dir}/${local.p_package}.secrets.sops.yaml"
_package_sec   = fileexists(local._pkg_sec_path) ? yamldecode(sops_decrypt_file(local._pkg_sec_path)) : {}
```

**Change 2** — framework secrets path and load:
```hcl
# OLD:
_fw_sec_path   = "${local._config_dir}/_framework-pkg.secrets.yaml"
_framework_sec = fileexists(local._fw_sec_path) ? yamldecode(file(local._fw_sec_path)) : {}

# NEW:
_fw_sec_path   = "${local._config_dir}/_framework-pkg.secrets.sops.yaml"
_framework_sec = fileexists(local._fw_sec_path) ? yamldecode(sops_decrypt_file(local._fw_sec_path)) : {}
```

**Change 3** — update the comment above the secrets block:
```hcl
# OLD:
# Package secrets: load if present, otherwise empty map. Plain YAML — no sops_decrypt_file.

# NEW:
# Package secrets: load if present; sops_decrypt_file decrypts at runtime — never on disk.
```

Also update the block header comment (lines ~48–55) that says "pre-decrypted SOPS secrets":
```hcl
# OLD (line ~51):
# and decrypts SOPS secrets before any terragrunt invocation.
# ...
# Secrets:          per-package decrypted file (plain YAML, mode 600).

# NEW:
# SOPS secrets are decrypted at runtime by sops_decrypt_file() — never written to disk.
# ...
# Secrets:          per-package encrypted SOPS file copy in _CONFIG_DIR (decrypted at runtime).
```

### `set_env.sh` — modify

Update the `_CONFIG_DIR` export comment:
```bash
# OLD:
export _CONFIG_DIR="$_DYNAMIC_DIR/config"                # pre-merged config YAML (read by root.hcl)

# NEW:
export _CONFIG_DIR="$_DYNAMIC_DIR/config"                # pre-merged public YAML + encrypted SOPS copies (read by root.hcl)
```

### `CLAUDE.md` — modify

**Add to the existing `⚠️ SOPS — CRITICAL RULES ⚠️` section** (immediately after the opening line):

```markdown
**NEVER decrypt SOPS files to disk.** Secrets must stay encrypted at rest.
- Terragrunt/HCL: use `sops_decrypt_file(path)` — decrypts in-process, nothing written to disk
- Python/shell: `sops --decrypt <file>` piped to stdout, parsed in memory — never redirect to a file
- `_CONFIG_DIR` holds **encrypted** `.secrets.sops.yaml` copies — NEVER `.secrets.yaml` plaintext copies
- `config-mgr generate` copies SOPS files unchanged; it does NOT decrypt them
```

**Fix the stale SOPS file path references** in the existing SOPS rules block:
```bash
# OLD (wrong — these paths don't use the <pkg>_secrets.sops.yaml naming):
`SOPS_FILE="$_INFRA_DIR/_framework-pkg/_config/secrets.sops.yaml"`  (_framework-pkg secrets)
`SOPS_FILE="$_INFRA_DIR/<pkg>/_config/secrets.sops.yaml"`          (per-package secrets; key: `<pkg>_secrets`)

# NEW (correct names):
`SOPS_FILE="$_INFRA_DIR/_framework-pkg/_config/_framework-pkg_secrets.sops.yaml"`  (if it exists)
`SOPS_FILE="$_INFRA_DIR/<pkg>/_config/<pkg>_secrets.sops.yaml"`                    (per-package secrets; key: `<pkg>_secrets`)
```

### `infra/_framework-pkg/_docs/ai-screw-ups/README.md` — modify

**Append a new entry** at the end:

```markdown
---

## 2026-04-23 — Decrypted SOPS Secrets to Disk in _CONFIG_DIR

**Session**: fix-config_dir-and-privacy

### What was asked

Add a centralized `_CONFIG_DIR` that holds merged config for fast Terragrunt access.
The intention was to copy config AND encrypted SOPS files to one location.

### What went wrong

`config-mgr`'s `generator.py` was written to **decrypt** every package's SOPS secrets file
and write the plaintext result to `_CONFIG_DIR/<pkg>.secrets.yaml` (mode 600).

`root.hcl` was updated to read those plaintext files with `yamldecode(file(...))` instead
of the original `yamldecode(sops_decrypt_file(...))`.

Result: every time `set_env.sh` is sourced, all production secrets — MaaS API keys, BMC
passwords, smart plug credentials — are written as plaintext YAML to
`config/tmp/dynamic/config/pwy-home-lab-pkg.secrets.yaml`.

### Rules violated

- **Secrets must never be decrypted to disk.** SOPS exists precisely to prevent this.
  Decrypting to disk means the secrets are accessible to anything with file-system access,
  appear in editor swap files, and may be captured by backup tools.

### New rules added to CLAUDE.md

- **NEVER decrypt SOPS files to disk.** Use `sops_decrypt_file()` in HCL (decrypts in-process)
  or `sops --decrypt` piped to stdout in scripts (parsed in memory). Never redirect to a file.
- `_CONFIG_DIR` holds **encrypted** `.secrets.sops.yaml` copies — never plaintext `.secrets.yaml`.
```

## Execution Order

1. **generator.py** — remove decrypt logic; add `_copy_file` helper; add SOPS copy logic; add legacy cleanup.
2. **root.hcl** — swap paths and calls to `sops_decrypt_file()`.
3. **set_env.sh** — update comment.
4. **CLAUDE.md** — add never-decrypt rule; fix stale file path references.
5. **ai-screw-ups/README.md** — append new entry.
6. **Memory** — save a feedback memory: "never decrypt SOPS to disk".
7. **Commit** — include ai-log entry as required by convention.

After execution, `set_env.sh` sourcing will:
- Remove the existing `pwy-home-lab-pkg.secrets.yaml` and `mikrotik-pkg.secrets.yaml` from `_CONFIG_DIR`
- Write encrypted `pwy-home-lab-pkg.secrets.sops.yaml` (and others) to `_CONFIG_DIR`
- Leave no plaintext secrets on disk

## Verification

```bash
# 1. Source set_env.sh and confirm no .secrets.yaml files remain
source set_env.sh
ls config/tmp/dynamic/config/*.secrets.yaml 2>/dev/null && echo "FAIL: plaintext files remain" || echo "OK: no plaintext secrets files"

# 2. Confirm encrypted SOPS copies exist
ls config/tmp/dynamic/config/*.secrets.sops.yaml

# 3. Confirm root.hcl can still decrypt secrets at runtime
cd infra/pwy-home-lab-pkg/_stack/maas/pwy-homelab
terragrunt plan 2>&1 | grep -i "error\|Error" || echo "plan succeeded"

# 4. Confirm the plaintext file content is gone
cat config/tmp/dynamic/config/pwy-home-lab-pkg.secrets.yaml 2>/dev/null && echo "FAIL" || echo "OK: file absent"
```
