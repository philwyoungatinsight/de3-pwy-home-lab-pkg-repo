# fix(config-mgr): restore runtime SOPS decryption — remove plaintext secrets from _CONFIG_DIR

## What changed

- **`generator.py`**: Removed SOPS decryption entirely. Added `_copy_file()` helper. Generator now
  copies each package's encrypted `*_secrets.sops.yaml` file unchanged to
  `_CONFIG_DIR/<pkg>.secrets.sops.yaml`. Added legacy cleanup that removes any existing
  `*.secrets.yaml` plaintext files from `_CONFIG_DIR` on first run.

- **`root.hcl`**: Replaced `yamldecode(file(...secrets.yaml))` with
  `yamldecode(sops_decrypt_file(...secrets.sops.yaml))` for both package and framework secrets.
  Decryption now happens in-process by Terragrunt — nothing written to disk.

- **`set_env.sh`**: Updated `_CONFIG_DIR` comment to reflect it holds public YAML + encrypted SOPS
  copies (not decrypted secrets).

- **`CLAUDE.md`**: Added "NEVER decrypt SOPS files to disk" rule to the SOPS CRITICAL RULES section.
  Fixed stale SOPS file path references (`secrets.sops.yaml` → `<pkg>_secrets.sops.yaml`).

- **`ai-screw-ups/README.md`**: Added entry documenting the root cause and fix.

## Why

The previous `config-mgr generate` (called by `set_env.sh`) was decrypting all SOPS secrets and
writing them as plaintext to `_CONFIG_DIR/*.secrets.yaml`. This exposed production credentials
(MaaS API key, BMC power passwords, smart plug credentials) as plaintext on disk every time a
shell was opened. The user's original intent was for `_CONFIG_DIR` to hold encrypted SOPS copies
only, with decryption happening at runtime via `sops_decrypt_file()`.

## Verification

- `source set_env.sh` removed the two legacy plaintext files and regenerated all packages
- `ls _CONFIG_DIR/*.secrets.yaml` → no results (no plaintext files)
- `ls _CONFIG_DIR/*.secrets.sops.yaml` → 12 encrypted copies present
- `terragrunt plan` on `ms01-01` succeeded with "No changes" — runtime decryption works
