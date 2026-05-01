# AI Log Summary

Reverse-chronological summary of significant changes made by Claude in this repo.

---

## 2026-05-01 — Revamp Git Repos: Fix Symlinks, Move Config

- Created `~/git/de3-ext-packages/de3-runner/main` symlink so all generated repos' `_ext_packages/de3-runner/main` chain resolves to the working `~/git/de3-runner/main`
- Removed dangling `.gitlab-ci.yml` symlink from all 13 generated framework repos and committed each
- Fixed `fw-repo-mgr` in de3-runner to auto-remove `.gitlab-ci.yml` after `prune_infra()` so future builds don't recreate it
- Copied full `framework_repo_manager.yaml` (623 lines, all 13 repos) from pwy-home-lab-pkg into `de3-central-index-repo` and pushed to GitHub + GitLab
- Steps 4 (retire de3-runner as `_framework-pkg` source) and 5 (retire pwy-home-lab-pkg) deferred to a separate plan

---

## 2026-04-29 — framework_settings_sops_templates: named list replaces single template

- Renamed `framework_settings_sops_template` (single dict) → `framework_settings_sops_templates` (list of named dicts)
- Each list entry has a `name:` key; existing template becomes `name: default`
- All 13 repos in `framework_repos` now have explicit `sops-template: default`
- `_write_sops_yaml()` in `fw-repo-mgr/run` updated to select template by name, strip `name:` key before writing `.sops.yaml`, error clearly if named template not found
- de3-runner default template comment updated to show new list format
- Behaviour unchanged; data model now supports repos with different SOPS key sets

---

## 2026-04-28 — Appearance menu: Mode dropdown + Tabbed Panels layout

- Replaced "Floating panels mode" checkbox with a `Mode:` select dropdown in Appearance → Layout
- Three options: `4-panels` (default), `Floating Panels`, `Tabbed Panels`
- New Tabbed Panels layout: infra-tree sidebar + draggable resizer + tab column (Object Viewer / File Viewer / Terminal tabs)
- `floating_panels_mode: bool` state replaced by `panel_mode: str`; migration reads old bool key on first load
- Main layout switch changed from nested `rx.cond` to `rx.match` over `panel_mode`
- de3-gui-pkg bumped 0.7.0 → 0.8.0

---

## 2026-04-26 — Fix fw-repo-mgr: CLI args, TypeError, _EPHEMERAL, Makefile support

- `fw-repo-mgr` renamed to `run`; `Makefile` added with `build`, `validate`, `status` targets
- CLI fixed: bare positional subcommands (`build`, `validate`, `status`) replaced with GNU-style flags (`--build`/`-b`, `--validate`/`-v`, `--status`/`-s`, `--force-push`/`-f`)
- TypeError fixed: tier-3 `framework_repo_manager.yaml` had `framework_repos: null` (bare key with no YAML value); changed to `framework_repos: []` and added `or []` guards throughout the script
- `$_EPHEMERAL` updated to `$_RAMDISK_DIR` in the validate-config flag block
- `set_env.sh`: `_FW_REPO_MGR` points to new `run`; `_fw-repo-mgr` removed from PATH list
- `_framework-pkg` bumped 1.20.0 → 1.21.0; README created for `_fw-repo-mgr/`

---

## 2026-04-26 — Rename _FRAMEWORK_CONFIG_PKG → _FRAMEWORK_MAIN_PACKAGE

- `set_env.sh` now exports `_FRAMEWORK_MAIN_PACKAGE` (name) and `_FRAMEWORK_MAIN_PACKAGE_DIR` (realpath-resolved path); old names kept as legacy aliases
- `_FRAMEWORK_MAIN_PACKAGE_DIR` is realpath-resolved so all tools get a canonical path through symlinks
- All 3-tier lookups in `fw-repo-mgr`, `pkg-mgr`, `packages.py`, `framework_config.py`, `config.py` updated to read new var with fallback to legacy
- `root.hcl` local var renamed `_framework_config_pkg_dir` → `_framework_main_package_dir`
- Docs updated: `config-overview.md`, `config-files.md`
- `_framework-pkg` bumped 1.19.0 → 1.20.0

---

## 2026-04-26 — sops-mgr + fw-repo-mgr integration; "Why Use Framework Tools" rule

- `sops-mgr` gains `-d|--infra-dir PATH` flag; automation can now scope SOPS file discovery to a target repo's `infra/` without using the parent repo's `INFRA_DIR`
- `fw-repo-mgr` calls `"$_SOPS_MGR" --re-encrypt --infra-dir "$repo_dir/infra"` immediately after writing `.sops.yaml`; ensures copied `*.sops.yaml` files are re-keyed to the new recipients before commit
- `sops-mgr README.md` updated: "not called by automation" claim removed; "When automation calls this" section added explaining fw-repo-mgr integration and traceability benefit
- `CLAUDE.md` gains "Why Use Framework Tools" rule: use framework tools (`sops-mgr`, `pkg-mgr`, etc.) not raw shell equivalents — every SOPS re-encryption is now grep-traceable
- `_framework-pkg` bumped 1.17.0 → 1.18.0

---

## 2026-04-26 — Clean up defunct repos; add local_only: true to all 13 framework repos

- `local_only: true` added to all 13 `framework_repos` entries in `framework_repo_manager.yaml`; prevents `fw-repo-mgr build` from pushing to remote until remotes exist
- `git-auth-check.py` updated to skip `local_only` repos when checking SSH/HTTPS hosts
- Both `known-fw-repos.yaml` visualizer cache files deleted; fresh scan will no longer show phantom repos (`proxmox-pkg-repo`, old `de3-*-pkg` names)
- Root causes fixed in de3-runner: stale `pwy-home-lab-pkg` template entry removed; scanner unified to read `new_repo_config.git-remotes`

---

## 2026-04-26 — feat(pwy-home-lab-pkg): activate framework_settings_sops_template + fw-repo-mgr write support

- `framework_settings_sops_template` in `framework_repo_manager.yaml` is now active (was wrong commented-out GCP placeholder); contains `stores.yaml.indent: 2` and two SOPS creation rules matching the root `.sops.yaml`
- `fw-repo-mgr` gains `_write_sops_yaml()`: reads the template and writes `.sops.yaml` at the generated repo root, overriding whatever was inherited from the de3-runner source rsync
- Both two PGP fingerprints (`446B41…` and `1FAFFD…`) wired in for all `infra/<pkg>/_config/*.sops.yaml` files plus a unifi-pkg-specific override
- Stale comment on `_write_settings_template` describing an unimplemented SOPS feature removed

---

## 2026-04-26 — feat(pwy-home-lab-pkg): add new_repo_config_defaults with branch protection schema

- New `new_repo_config_defaults.git-refs` section in `framework_repo_manager.yaml`; declares default branch protection for all repos without repeating it per entry
- Ships with `main` explicitly open: `allow_direct_push: true`, `allow_force_push: true`
- Merge semantics: per-repo `new_repo_config.git-refs` overrides per-branch, per-field — only specified fields win, rest inherit the default
- Override pattern documented in comment block above `framework_repos`

---

## 2026-04-26 — feat(pwy-home-lab-pkg): add GitLab remotes to all framework repos

- Added `gitlab` remote entry to all 13 repos in `framework_repo_manager.yaml`; each repo now has both `origin` (GitHub HTTPS) and `gitlab` (GitLab SSH) under `new_repo_config.git-remotes`
- GitLab URLs follow `git@gitlab.com:pwyoung/<repo-name>.git`; `fw-repo-mgr` already iterates all `git-remotes` entries so no code changes needed
- `framework_git_config.yaml` already had `gitlab.com: glab` in `host_type_map`; `git-auth-check.py` will validate GitLab auth once `glab auth login` is run

---

## 2026-04-26 — feat(pwy-home-lab-pkg): add gh/glab OAuth login via _setup + framework_git_config

- New `framework_git_config.yaml` in `_framework_settings/` controls periodic git auth validation: `mode`, `interval_minutes`, `validation_type: current-repos`, `on_failure`, `host_type_map`, `gh_scopes`
- New `_setup/check-git-auth` Python script: 3-tier settings lookup, extracts hostnames from `git remote -v` + all `framework_repo_manager.yaml` files, checks `gh`/`glab` auth per host, rate-limits via flag file
- New `_setup/run`: installs `gh` (apt/brew) and `glab` (GitHub Releases deb/brew), runs auth check, delegates seed flags to `./seed`
- New `_setup/seed`: interactive OAuth login (`--login/--seed`), status, test, clean; reads `host_type_map` dynamically so adding a host requires only a config change
- `_setup/.gitkeep` deleted; `glab` is installed for future GitLab use but skipped in auth check until installed

---

## 2026-04-26 — feat(fw-repos): add de3-pwy-home-lab-pkg-repo and de3-central-index-repo stubs

- Added commented-out entry for `de3-pwy-home-lab-pkg-repo` — the properly named (de3-prefix, -repo suffix) canonical reference for this deployment repo; marked non-exportable
- Added commented-out entry for `de3-central-index-repo` — a central discovery index that declares every known framework package repo as an external dependency; single entry point for ecosystem-wide package discovery
- Removed stale `de3-demo-buckets-example-pkg-repo` entry (repo no longer tracked)
- Central index external packages reference individual package repos (not de3-runner monorepo) to show the distributed graph once packages migrate
- Both entries stay commented out until their GitHub repos are created; `⚠️` warning included in each block

---

## 2026-04-26 — refactor(fw-repos): source_repo as object + source_repo_defaults rename

- `source_repos` renamed to `source_repo_defaults` in both tier-2 (pwy-home-lab-pkg) and tier-3 (de3-runner) `framework_repo_manager.yaml`
- All 12 per-repo `source_repo: de3-runner` string values expanded to `source_repo:\n  name: de3-runner` objects; `url`/`ref` fields optional, resolved from defaults by name
- `fw-repo-mgr` `_resolve_source()` rewritten to read `source_repo_defaults` and treat `source_repo` as an object; legacy `source_url`/`source_ref` sibling fields removed
- `_build_repo()` update-branch now reads `source_repo.name` via inline Python instead of `_repo_field` scalar read
- Fully explicit per-repo source override now possible without touching the defaults registry

---

## 2026-04-26 — refactor(fw-repos): rename repos to de3-<pkg>-repo convention + new_repo_config

- Removed `proxmox-pkg-repo` (never existed; merged into `de3-proxmox-pkg-repo`) and renamed all `de3-*-pkg` entries by adding `-repo` suffix (12 repos total, now including `de3-_framework-pkg-repo`)
- Replaced flat `upstream_url` / `upstream_branch` fields with `new_repo_config.git-remotes` list; all repos pre-populated with expected GitHub URLs; hard cutover — no backward compat fallback
- `fw-repo-mgr`: added `_resolve_remotes()` helper; Step 6 now iterates `new_repo_config.git-remotes`; `status` reads from same source
- Updated `repo_names_must_not_contain_special_chars` and `package_names_must_not_contain_special_chars` regexes from `^[a-z0-9][a-z0-9-]*$` to `^[a-z0-9_][a-z0-9_-]*$` (allow underscores for `_framework-pkg`)
- Fixed `config/_framework.yaml` `_docs` label: `gitlab.com/pwyoung/pwy-home-pkg` → `github.com/philwyoungatinsight/pwy-home-lab-pkg`

---

## 2026-04-26 — feat(fw-repos): relax repo_names_must_end_with from -pkg-repo to -repo

- Changed `repo_names_must_end_with` rule value from `-pkg-repo` to `-repo` in pwy-home-lab-pkg deployment config and de3-runner template config
- All existing repos remain valid: `proxmox-pkg-repo` ends with `-repo`; `de3-*-pkg` repos satisfy `begin_with: de3-`
- pwy-home-lab-pkg bumped 1.0.1 → 1.0.2

---

## 2026-04-26 — feat(fw-repos): naming rules config + fw-repo-mgr validate subcommand

- `framework_package_naming_rules` block added to de3-runner template and pwy-home-lab-pkg config (typo fixed: `begin_with:-pkg-repo` → `end_with:-pkg-repo`)
- `fw-repo-mgr`: added `_validate_naming_rules()` — rule-driven validator replacing hardcoded `-pkg` suffix check
- `begin_with` and `end_with` rules are OR'd; external packages exempt from uniqueness check; `_framework-pkg` template excluded from package name checks
- New `fw-repo-mgr -v|validate [<name>]` subcommand for standalone rule checking
- Validation runs automatically at start of every `fw-repo-mgr -b|build` run
- pwy-home-lab-pkg bumped 1.0.0 → 1.0.1

---

## 2026-04-26 — feat(fw-repos): clickable hyperlinks in DOT output

- Package nodes (ellipses) now carry `URL=` pointing to the repo browse URL (`.git` stripped, SSH converted)
- Repo cluster labels now carry `URL=` pointing to `framework_repo_manager.yaml` via `/blob/HEAD/` GitHub link
- `scanner.py`: fixed missing `main_package` backfill from declared stubs — repos with URLs now correctly populate `main_package` from declaring repo's `is_config_package` flag
- `renderer.py`: added `_to_browse_url()` and `_fw_repo_mgr_url()` helpers; both link types use `target="_blank"`
- `_framework-pkg` version bumped `1.13.0` → `1.14.0`

---

## 2026-04-26 — rename: _framework.config_package → _framework.main_package

- `config/_framework.yaml`: key renamed `config_package:` → `main_package:`
- `framework_repo_manager.yaml` comment updated to reference `_framework.main_package`
- `read-set-env.py` (de3-runner): reads `main_package` key from `config/_framework.yaml`
- `fw-repo-mgr` (de3-runner): `_write_config_framework_yaml()` now writes `main_package:` in generated repos
- `scanner.py` (de3-runner): all internal dict keys and YAML reads updated from `config_package` → `main_package`
- `renderer.py` (de3-runner): `repo_data.get("main_package")` for cluster URL generation; `_framework-pkg` bumped 1.12.0 → 1.13.0

---

## 2026-04-24 — fix(fw-repos): Arrow direction, inaccessible coloring, attribution

- `-->` replaces `<|--` for "creates" arrows; `<|--` put arrowhead on the wrong end so "creator creates created" read as "created creates creator"
- `_clone_or_pull` returns bool; clone failures now set `accessible: false` automatically so inaccessible coloring works without `check_accessibility: true` in config
- Framework_repos with `upstream_url` are now enqueued for BFS cloning; pwy-home-lab-pkg's own settings are scanned and override de3-runner's template claim on proxmox-pkg-repo
- Lineage changed to last-write-wins so cloned deployment repos take priority over initial template scan

---

## 2026-04-24 — fix(fw-repos): Correct proxmox-pkg-repo declaring-repo attribution

- Moved `proxmox-pkg-repo` from de3-runner's template into pwy-home-lab-pkg's own `framework_repo_manager.yaml`
- De3-runner template example re-commented; deployment-specific repos must live in the deployment repo's config
- Diagram now correctly shows `pwy-home-lab-pkg <|-- proxmox-pkg-repo : creates` (was de3-runner)
- First-write-wins in `lineage` dict meant the template entry always shadowed the deployment config; moving the entry is the correct fix

---

## 2026-04-24 — fix(fw-repos): Correct repo names, source URLs, and Refresh behaviour

- `scanner.py`: `_repo_name_from_git()` derives repo name from `git remote.origin.url` — fixes `main` appearing instead of `de3-runner` when the checkout dir is named `main`
- `scanner.py`: `_load_repo_manager()` now stores `upstream_url` from config into declared stubs — `pwy-home-lab-pkg` and `proxmox-pkg-repo` now have GitHub URLs in the diagram
- `scanner.py`: back-fills current repo URL from its declared stub after scan, preserving `source="local"` while adding the upstream URL
- GUI Refresh button now runs `--refresh --list` (was `--list` only) so it actually rescans and git-pulls the cache

---

## 2026-04-24 — feat(de3-gui): Replace fw-repos Cytoscape view with Mermaid class diagram

- Replaced broken/illegible Cytoscape compound-node graph with Mermaid `classDiagram` in iframe asset
- Repos appear as UML classes; embedded packages as `+ name: version`; external packages as `- name: version`; `created_by` as inheritance arrows
- Added `/api/fw-repos-graph` FastAPI endpoint; created `assets/fw_repos_mermaid_viewer.html` (Mermaid.js from CDN)
- Removed ~370 lines of Cytoscape-specific state/handlers/constants/menus from `homelab_gui.py`
- Deleted `state/fw-repos-layout.yaml`; bumped de3-gui-pkg to v0.5.0

---

## 2026-04-23 — fix(fw-repos-visualizer): Follow symlinks when scanning for _framework_settings

- `scanner.py` replaced `Path.rglob()` with `os.walk(followlinks=True)` so symlinked dirs (e.g. `infra/_framework-pkg`) are included in the current-repo scan
- Added `_find_settings_dirs()` helper with `seen_real` guard to prevent infinite loops on circular symlinks
- `framework_repos_visualizer.yaml`: all 4 output formats (yaml/text/json/dot) and capability visualization now enabled by default
- de3-runner bumped to v1.9.1; committed and pushed (b73a4b3, fab3e2b)

---

## 2026-04-23 — feat(_framework-pkg): Add fw-repos-visualizer tool (v1.9.0)

- New framework tool `fw-repos-visualizer` in de3-runner: BFS-discovers all reachable framework repos by cloning into `~/git/fw-repos-visualizer-cache/` and scanning for `_framework_settings` dirs
- Reads `framework_package_repositories.yaml` and `framework_repo_manager.yaml` from each discovered dir; records `created_by` lineage for generated repos
- Renders as `yaml`, `json`, `text` (ASCII tree), and `dot` (Graphviz) simultaneously per `output_formats` config list
- State files under `config/tmp/fw-repos-visualizer/` (gitignored); config in `_framework_settings/framework_repos_visualizer.yaml` (source-controlled)
- Auto-refresh with modes `never`/`fixed_time`/`file_age` (default); 10-second rate-limit gate; `--auto-refresh`/`--no-auto-refresh` CLI overrides
- Fixed: `config.py:repo_root()` uses `_GIT_ROOT` env var instead of `git rev-parse` (bash wrapper `cd`s into framework dir before Python runs)

---

## 2026-04-23 — feat(pkg-mgr): Remove import_path — symlink path always equals package name

- `pkg-mgr` (de3-runner 1.6.0): removed `import_path` param from all helper functions; now uses `$pkg_name` directly for symlink path
- `pkg-mgr --sync`: added validation that errors if `import_path` is set in any package entry — field is now forbidden
- `framework_packages.yaml` (both repos): removed 12+ redundant `import_path:` fields and updated example comments
- `framework_repo_manager.yaml` (both repos): removed `import_path` from `framework_package_template` and all `framework_repos` entries
- `pkg-mgr` README: updated schema examples and symlink path description to reflect removal
- `_framework-pkg` correctly remains `package_type: external` in pwy-home-lab-pkg (imported from de3-runner)

---

## 2026-04-23 — chore: Consolidate root files into _git_root

- All six consumer-repo root files (`run`, `set_env.sh`, `Makefile`, `README.md`, `CLAUDE.md`, `TODO.md`) now live in `_git_root/` and are symlinked from the repo root
- `run` restored as a symlink (was temporarily broken into a standalone file); bootstrap logic now lives in the shared `_git_root/run`

---

## 2026-04-23 — feat(wave-mgr): Extract wave execution into wave-mgr, simplify Makefile and run

- New `infra/_framework-pkg/_framework/_wave-mgr/wave-mgr`: owns all wave apply/test/clean/list logic; invoked via `$_WAVE_MGR`
- `set_env.sh` gains `export _WAVE_MGR` (between `_CLEAN_ALL` and `_FW_REPO_MGR`)
- `_git_root/run` replaced with thin no-bootstrap wrapper: keeps package-management functions, delegates waves to `wave-mgr`
- Top-level `run` symlink broken into a standalone file with `_bootstrap()` + auto-bootstrap check before `_source_env()`
- `Makefile` simplified: removed `FRAMEWORK_MAKEFILE` delegation and `_require_framework` guard; all targets call `./run --<flag>` directly

---

## 2026-04-23 — feat(pkg-mgr+fw-repo-mgr): Enforce -pkg suffix on all package names

- `pkg-mgr`: added `_assert_pkg_name()` bash guard called in `--import`, `--rename`, and `--copy`
- `pkg-mgr --sync`: added name check in Python heredoc — rejects any package in `framework_packages.yaml` whose name doesn't end in `-pkg`
- `fw-repo-mgr`: added name validation in `_write_framework_packages_yaml()` before writing — catches hand-edits to `framework_repo_manager.yaml`
- `framework_repo_manager.yaml`: updated example package name `my-homelab` → `my-homelab-pkg`
- Bumped `_framework-pkg` to 1.5.4

---

## 2026-04-23 — fix(config-mgr): Restore runtime SOPS decryption — remove plaintext secrets from _CONFIG_DIR

- `generator.py` no longer decrypts SOPS files; it copies them encrypted to `_CONFIG_DIR/<pkg>.secrets.sops.yaml`
- `root.hcl` restored to `sops_decrypt_file()` for secrets — decryption now in-process by Terragrunt, nothing written to disk
- Legacy plaintext `*.secrets.yaml` files auto-removed from `_CONFIG_DIR` on first `set_env.sh` source
- CLAUDE.md: added "NEVER decrypt SOPS files to disk" rule; fixed stale SOPS path references
- ai-screw-ups: documented root cause so this is never repeated

---

## 2026-04-23 — refactor(config-mgr): Replace all direct sops --set calls with config-mgr

- Replaced 10 direct `sops --set` calls across `aws-pkg`, `azure-pkg`, and `gcp-pkg` `_setup/seed` scripts with `"$_CONFIG_MGR" set-raw --sops`; `sops --set` now lives only in `config_mgr/sops.py`
- Fixed 5 stale `_config-mgr/run` path references in Ansible tg-scripts (proxmox configure-api-token, maas configure-server, configure-region, sync-api-key) to use `{{ lookup('env', '_CONFIG_MGR') }}`; these were broken since the c41cabb rename
- Dropped per-function `sops_file` local vars and file-existence guards in seed scripts — `config-mgr` handles missing-file errors internally
- Bumped `_framework-pkg` to 1.5.2

---

## 2026-04-23 — fix(remove-default-pkg): Replace all stale default-pkg references

- Updated 6 package `_setup/run` scripts (de3-gui, image-maker, maas, mesh-central, proxmox, unifi) to call `_framework-pkg/_setup/run`
- Fixed `maas-lifecycle-gate` + `maas-lifecycle-sanity` playbooks to use `_FRAMEWORK_PKG_DIR` env var + `_framework_settings/framework_backend.yaml` path
- Fixed archived `query-unifi-switch/run` inventory path
- Renamed `default-pkg` → `_framework-pkg` in de3-gui `defaults.yaml` package filter
- Cleaned `.gitignore` comment and removed 4 stale sed allow-list entries from `.claude/settings.local.json`
- Bumped `_framework-pkg` to 1.5.1

---

## 2026-04-22 — refactor(set_env.sh): Extract Python heredocs + rename framework tool scripts

- Replaced two inline bash heredocs in `set_env.sh` with `_utilities/python/read-set-env.py` helper
- `set_env.sh` now exports 6 new tool-path env vars: `_PKG_MGR`, `_UNIT_MGR`, `_CLEAN_ALL`, `_EPHEMERAL`, `_CONFIG_MGR`, `_FW_REPO_MGR`
- Renamed all framework tool scripts from `run` to descriptive names per naming convention (e.g. `pkg-mgr`, `unit-mgr`, `clean-all`)
- `_WRITE_EXIT_STATUS` path updated to `write-exit-status/write-exit-status`
- `homelab_gui.py`: 4 hardcoded `default-pkg` paths replaced with env vars
- Bumped `_framework-pkg` to 1.5.0 and `de3-gui-pkg` to 0.3.1

---

## 2026-04-22 — _framework-pkg: Improve framework_settings examples and placeholder comments

- `framework_backend.yaml` and `gcp_seed.yaml` now have commented-out placeholder shapes so new users know what to override
- `framework_clean_all.yaml` framework default: replaced hardcoded `pwy-home-lab-pkg` with empty list + example comment
- `framework_repo_manager.yaml` (de3-runner default): added commented-out `framework_package_template`, `framework_settings_template`, `framework_settings_sops_template` blocks
- `framework_repo_manager.yaml` (pwy-home-lab-pkg): added `framework_settings_sops_template` commented example
- Bumped `_framework-pkg` to 1.4.10

---

## 2026-04-22 — fw-repo-mgr: Rename framework_repo_dir to git/de3

- `framework_repo_dir` changed from `git/de3-source-packages` to `git/de3`; generated repos now land at `~/git/de3/<name>/`

---

## 2026-04-22 — fw-repo-mgr: Copy Full Framework Settings into Generated Repos

- Generated repos were missing all framework settings except the 3 written by `_write_minimal_framework_settings`; `./run` failed immediately with "framework_backend.yaml not found"
- Added `_copy_framework_settings()`: bulk-copies all non-excluded `*.yaml` files from source `_framework_settings/` dirs (framework defaults → config-pkg overrides)
- Added `_write_settings_template()`: applies `framework_settings_template` from config after the copy, allowing a shared GCS backend to be declared once for all generated repos
- `_find_component_config` in bash: `maxdepth 3 → 4` so files inside `_config/_framework_settings/` are found (they're at depth 4, previously unreachable)
- Added `framework_settings_template` to `framework_repo_manager.yaml` with the shared GCS backend; `framework_settings_sops_template` noted as the SOPS equivalent

---

## 2026-04-22 — _framework README: Document _config-mgr, _fw-repo-mgr, _git_root

- `_config-mgr`, `_fw-repo-mgr`, and `_git_root` were present in `_framework/` but missing from the README table
- Added entries describing each tool's purpose and commands

---

## 2026-04-22 — fw-repo-mgr: Inject framework_package_template into generated repos

- `_write_framework_packages_yaml()` was ignoring the top-level `framework_package_template` block — `_framework-pkg` was never written into generated repos' `framework_packages.yaml`
- Generated repos were missing `_framework-pkg`, leaving `set_env.sh` as a dangling symlink and `./run` non-functional
- Fix: read `framework_package_template` from config and prepend to the package list; skip if name already explicitly listed
- Bumped `_framework-pkg` to 1.4.8

---

## 2026-04-22 — fw-repo-mgr: Fix update step for local-only repos

- Update path unconditionally ran `git fetch origin` — repos created by rsync+git-init have no remote; now skips fetch when no remote is configured
- `_config_package()` only checked the legacy repo-level `config_package:` key; now also scans for the first package with `is_config_package: true` (the new convention)
- All 11 repos in `framework_repo_manager.yaml` now complete without errors

---

## 2026-04-22 — Hard-fail on config validation violations

- `validate-config` was called from `set_env.sh` with `|| true` — violations were advisory warnings that never blocked anything; now fixed
- Removed the call from `set_env.sh` entirely; `./run` and `fw-repo-mgr/run` call it directly after sourcing and abort on exit 1
- `_config-mgr/run` intentionally excluded — it's the tool used to fix violations
- Once-per-session ephemeral-mounts trigger moved alongside the validate-config call in each caller
- Also fixed two GUI bugs found during testing: `arch_diagram_config.yaml` top-level key mismatch, `rx.foreach` string concatenation error

---

## 2026-04-22 — fw-repo-mgr: Config Redesign — framework_package_template + is_config_package

- Added `framework_package_template` block — `_framework-pkg` auto-injected into every repo; top-level files sourced from its repo
- Replaced `config_package:` at repo level with `is_config_package: true` per-package flag; fw-repo-mgr copies `_framework_settings` and writes `config/_framework.yaml` accordingly
- Removed 11 repeated `_framework-pkg` blocks from individual repo entries
- Added transitive dependency packages as external entries for 5 repos (maas, proxmox, image-maker, mesh-central, demo-buckets)
- Updated `framework_repo_dir` to `git/de3-source-packages`

---

## 2026-04-22 — fw-repo-mgr: Use rsync+git-init for New Repos

- Replaced `git clone` in `fw-repo-mgr` Step 1 with rsync (excluding `.git`) + `git init`
- New per-package repos now start with zero git history — no de3-runner commits carried over
- Added `_ext_pkg_base()` to read `external_package_dir` from `framework_package_management.yaml`
- Added `_find_source_clone()` to resolve the local pkg-mgr cache path, avoiding a network clone
- Removed `source_remote` rename logic from the new-repo path (no remote added for local-only repos)

---

## 2026-04-22 — Generate local per-package repos via fw-repo-mgr

- Extended `fw-repo-mgr` with `config_package` field — writes `config/_framework.yaml`, `framework_packages.yaml` into the config pkg's `_framework_settings`, bootstraps minimal settings for pkg-mgr
- Fixed `FW_MGR_CFG` 3-tier lookup (was missing `_framework_settings/` subdir — tool silently read nothing)
- Fixed `_prune_infra` to also remove real dirs for `external`-typed packages so pkg-mgr can create symlinks
- Fixed `pkg-mgr --sync` bootstrap: installs a temporary `set_env.sh` shim while `_framework-pkg` is absent, restores symlink after sync
- Wired `framework_repo_manager.yaml` with 11 real entries; all repos built successfully at `~/git/de3-<pkg>`

---

## 2026-04-22 — Redesign Arch Diagram as nested deployment diagram with cloud icons

- Rewrote `_build_arch_diagram_elements()` — nested React Flow layout with zone → provider → env → resource hierarchy; depth-range filtering (`min_depth`/`max_depth`) replaces single `component_depth`
- Toolbar now has Dir (LR/TB), Min/Max depth sliders, Conn toggle, folder picker, and Save status display
- draw.io export now uses drawpyo with real cloud shape stencils (`mxgraph.cisco.*`, `mxgraph.aws4.*`, `mxgraph.gcp2.*`, etc.)
- Icon mapping moved entirely to `arch_diagram_config.yaml` (`icon_map` + `provider_icon_fallbacks`); no hardcoded shapes in Python
- Extensible export format registry (`_ARCH_EXPORT_FORMATS` / `_ARCH_GENERATORS`); new formats require only a generator function + registry entry
- Replaced static `_ARCH_DIAGRAM_CACHE` with reactive computed vars driven by `arch_direction`, `arch_min_depth`, `arch_max_depth`, `arch_show_connections` AppState vars
- Bumped de3-gui-pkg to 0.3.0

---

## 2026-04-22 — Add Arch Diagram visualization framework to de3-gui

- New `archdiagram` framework in VIZ_FRAMEWORKS: swimlane-based architectural diagram derived entirely from live infra data
- Components auto-selected from `_ALL_NODES_CACHE` at configurable `component_depth`; connections from `_DEPENDENCIES_CACHE`
- Layer/swimlane assignment by path-prefix rules in new `arch_diagram_config.yaml` (no manual component list)
- Toolbar with File → Export → draw.io: downloads mxGraphModel XML via `GET /api/arch-diagram-drawio`
- draw.io export via stdlib `xml.etree.ElementTree` — no new pip dependencies
- Bumped de3-gui-pkg to 0.2.0; created `version_history.md` for the package

---

## 2026-04-22 — Remove filter item tooltips from infra panel

- Removed `rx.tooltip()` wrappers from all five filter-item toggle functions: `provider_toggle_item`, `_package_toggle_item`, `_region_toggle_item`, `_role_toggle_item`, `_env_toggle_item`
- Each function now returns `rx.hstack(...)` directly — no Radix tooltip on hover
- Button-level `title=` on the dropdown trigger buttons left intact

---

## 2026-04-22 — Fix ./run -A de3-gui + /doit all-package plan search

- Fixed `waves_ordering.yaml` discovery in `run`: replaced hand-rolled search with `find_framework_config_dirs()` so `_framework_settings/` subdirectories are checked
- Moved `-A`/`--app` handler before `load_all_configs()` so app commands bypass wave config load entirely
- Added CLAUDE.md rule: plan names are unique across packages; always use `find infra -path "*/_docs/ai-plans/<name>.md"` to locate them
- Updated `/doit` Step 2 to use that `find` command instead of hardcoding the pwy-home-lab-pkg path

---

## 2026-04-21 — Rename framework_manager.yaml → framework_repo_manager.yaml

- Renamed `framework_manager.yaml` to `framework_repo_manager.yaml` in both `_framework-pkg/_config/_framework_settings/` and `pwy-home-lab-pkg/_config/_framework_settings/`
- Top-level YAML key renamed `framework_manager:` → `framework_repo_manager:` in both files
- Updated `fw-repo-mgr/run`: FW_MGR_CFG path, all 6 Python `d.get('framework_manager', {})` calls, and usage string
- Bumped `_framework-pkg` 1.4.6 → 1.4.7 in external de3-runner repo

---

## 2026-04-21 — Move Package Version History to version_history.md

- Stripped `# Version history` comment block from `infra/_framework-pkg/_config/_framework-pkg.yaml`
- Created `infra/_framework-pkg/_config/version_history.md` with full history in Markdown format
- Updated CLAUDE.md: version history now lives in `infra/<pkg>/_config/version_history.md` peer file, not YAML comments
- Updated memory to reflect the new convention

---

## 2026-04-21 — Add make all Convenience Target for First-Time Setup

- Added `make all` target to root Makefile as a first-time setup shortcut (installs deps + syncs packages)
- Target runs `make install-deps` then `make pkg-sync` in sequence

---

## 2026-04-21 — Fix Loose Ends After External Framework Package

- Fixed ai-plan and ai-log file paths that pointed to old default-pkg locations
- Updated references to _framework-pkg in documentation and scripts

---

## 2026-04-21 — Make _framework-pkg an External Package

- Converted `_framework-pkg` from an embedded directory to a symlink pointing to de3-runner external clone
- Added `_framework-pkg` to `framework_packages.yaml` as `package_type: external`
- `pkg-mgr sync` now manages the symlink; `infra/_framework-pkg` is no longer tracked directly in pwy-home-lab-pkg

---
