# Framework Settings

## What this directory is

`infra/pwy-home-lab-pkg/_config/_framework_settings/` contains deployment-specific
overrides for framework config files. Files here take precedence over the framework
defaults in `infra/_framework-pkg/_config/_framework_settings/`, but are overridden
by anything placed in `config/` at the git root.

Overrides are per-file — only files present in this directory take effect. Files
absent here fall back to the framework default.

## Lookup order (lowest → highest priority)

1. `infra/_framework-pkg/_config/_framework_settings/` — framework defaults
2. `infra/pwy-home-lab-pkg/_config/_framework_settings/` — this package (deployment config)
3. `config/` at the git root — per-developer ad-hoc overrides (gitignored)

## Files in this package

| File | Purpose |
|------|---------|
| `framework_backend.yaml` | GCS state bucket for Terragrunt |
| `framework_clean_all.yaml` | Controls `make clean-all` behaviour |
| `framework_git_config.yaml` | Git auth check (see [Git Auth](git-auth.md)) |
| `framework_package_management.yaml` | External package clone directory |
| `framework_package_repositories.yaml` | Package repository URLs |
| `framework_packages.yaml` | Which packages are active in this deployment |
| `framework_ramdisk.yaml` | RAM-backed scratch directory config |
| `framework_repo_manager.yaml` | Framework repo lineage and package declarations; use `local_only: true` on an entry to build locally before pushing — see [fw-repo-mgr docs](../../_framework-pkg/_docs/framework/framework-repo-manager.md) |
| `gcp_seed.yaml` | GCP seed config (project, region, SA) |
| `gcp_seed_secrets.sops.yaml` | GCP seed credentials (SOPS-encrypted) |
| `waves_ordering.yaml` | Wave definitions and execution order |

## Adding a per-developer override

Create `config/<filename>.yaml` at the git root with the same top-level key as the
framework file. Example — temporarily disable git auth checks without committing:

```yaml
# config/framework_git_config.yaml
framework_git_config:
  git-auth:
    mode: never
```

The `config/` directory is gitignored; changes there never affect other developers.

## Reading a framework setting from a script

Use `config-mgr fw-setting <name>` to resolve the winning file path via the 3-tier
lookup without replicating the logic:

```bash
RAMDISK_YAML="$("$_CONFIG_MGR" fw-setting framework_ramdisk)"
```

Accepts the filename with or without the `.yaml` suffix. Exits 1 if no file is found
at any tier.
