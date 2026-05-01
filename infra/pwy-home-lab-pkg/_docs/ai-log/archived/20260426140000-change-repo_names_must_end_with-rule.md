# 2026-04-26 — change-repo_names_must_end_with-rule

## What was done

Changed the `repo_names_must_end_with` naming rule value from `-pkg-repo` to `-repo` in
both config files that define it.

### Changes in pwy-home-lab-pkg

**`infra/pwy-home-lab-pkg/_config/_framework_settings/framework_repo_manager.yaml`**
- `repo_names_must_end_with` value: `-pkg-repo` → `-repo`

**`infra/pwy-home-lab-pkg/_config/pwy-home-lab-pkg.yaml`**
- Bumped version: 1.0.1 → 1.0.2

### Changes in de3-runner (`/home/pyoung/git/de3-ext-packages/de3-runner/main/`)

**`infra/_framework-pkg/_config/_framework_settings/framework_repo_manager.yaml`**
- `repo_names_must_end_with` value: `-pkg-repo` → `-repo`

## Impact

All existing repos remain valid:
- `proxmox-pkg-repo` ends with `-repo` ✓
- `de3-*-pkg` repos satisfy the `repo_names_must_begin_with: de3-` rule ✓

The change allows future repos to end with just `-repo` without requiring the `-pkg-` infix
(e.g. `proxmox-repo` would now be a valid repo name).
