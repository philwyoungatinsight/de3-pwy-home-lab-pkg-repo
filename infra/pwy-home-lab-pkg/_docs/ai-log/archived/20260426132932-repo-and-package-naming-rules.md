# 2026-04-26 — repo-and-package-naming-rules

## What was done

Added `framework_package_naming_rules` support to fw-repo-mgr and propagated the
config block to the de3-runner template.

### Changes in de3-runner (`/home/pyoung/git/de3-ext-packages/de3-runner/main/`)

**`infra/_framework-pkg/_config/_framework_settings/framework_repo_manager.yaml`**
- Added live `framework_package_naming_rules` block before `framework_repos`.
- Rules: repo_names_must_be_unique, repo_names_must_begin_with (de3-), repo_names_must_end_with (-pkg-repo), repo_names_must_not_contain_special_chars, package_names_must_be_unique, package_names_must_be_valid_identifiers, package_names_must_not_contain_special_chars.

**`infra/_framework-pkg/_framework/_fw-repo-mgr/fw-repo-mgr`**
- Added `_validate_naming_rules()` function (rule-driven Python validator).
- `begin_with` and `end_with` rules are OR'd — a repo name is valid if it matches ANY prefix or suffix across both rule types.
- `framework_package_template` excluded from package name checks (framework internal).
- `package_names_must_be_unique` checks only embedded packages; external packages are intentionally shared across repos.
- Replaced hardcoded `endswith('-pkg')` check in `_write_framework_packages_yaml`.
- Validation runs automatically at start of `_build_repo()`.
- Added `fw-repo-mgr -v|validate [<name>]` subcommand for standalone checking.

### Changes in pwy-home-lab-pkg (this repo)

**`infra/pwy-home-lab-pkg/_config/_framework_settings/framework_repo_manager.yaml`**
- Fixed typo: `repo_names_must_begin_with: -pkg-repo` → `repo_names_must_end_with: -pkg-repo`.

**`infra/pwy-home-lab-pkg/_config/pwy-home-lab-pkg.yaml`**
- Bumped version: 1.0.0 → 1.0.1.

## Current validation state

Running `fw-repo-mgr validate` against pwy-home-lab-pkg config reports:
```
ERROR: package_names_must_be_unique: duplicate embedded package names: ['proxmox-pkg']
```
This is correct and expected — `proxmox-pkg` is embedded in both `proxmox-pkg-repo` and
`de3-proxmox-pkg`. The user is about to recreate/rename the package repos, which will
resolve this conflict.
