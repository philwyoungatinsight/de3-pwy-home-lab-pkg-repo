# fw-repo-mgr: Config Redesign — framework_package_template + is_config_package

## Summary

Redesigned `framework_repo_manager.yaml` to eliminate repetition and make the `_framework-pkg`
injection and config-package selection explicit. The repeated 7-line `_framework-pkg` block that
appeared in every repo's `framework_packages` list is replaced by a single `framework_package_template`
section. Config-package selection moves from a top-level `config_package:` field on each repo to an
`is_config_package: true` flag on the relevant package entry. Dependency packages are now declared
explicitly per repo so each built repo contains everything it needs.

## Changes

- **`infra/pwy-home-lab-pkg/_config/_framework_settings/framework_repo_manager.yaml`**
  - Added `framework_package_template` block: `_framework-pkg` entry auto-prepended to every repo's
    `framework_packages` list by fw-repo-mgr; top-level files (Makefile, set_env.sh, etc.) come from
    this package's source repo
  - Replaced `config_package:` at repo level with `is_config_package: true` on per-package entries;
    fw-repo-mgr copies `_framework_settings` into that package's `_config/` and writes
    `_framework.config_package` accordingly; errors if zero or multiple packages declare it (single
    embedded package is an implicit fallback)
  - Removed all 11 repeated `_framework-pkg` blocks from individual repo entries
  - Added declared dependency packages as external entries for repos that require them:
    `de3-demo-buckets-example-pkg` (aws, azure, gcp), `de3-image-maker-pkg` (proxmox + unifi transitive),
    `de3-maas-pkg` (unifi), `de3-mesh-central-pkg` (proxmox + unifi transitive), `de3-proxmox-pkg` (unifi)
  - Updated `framework_repo_dir` to `git/de3-source-packages`
- **`TODO.md`** — updated notes

## Notes

The `is_config_package` fallback rule (single embedded package → implicit config package) means existing
single-package repos still work without the explicit flag, but all entries here carry it explicitly for clarity.
