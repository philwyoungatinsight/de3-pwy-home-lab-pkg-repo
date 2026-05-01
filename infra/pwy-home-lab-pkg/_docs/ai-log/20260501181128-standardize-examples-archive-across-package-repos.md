# Standardize examples-archive Across Individual Package Repos

## Summary

Implemented the `examples-archive` convention across all 9 provider package repos
(aws, azure, gcp, image-maker, maas, mesh-central, mikrotik, proxmox, unifi). Each repo
now has an `examples-archive/` directory with real, runnable example units and
`_skip_on_build: true` at the ancestor path so examples are excluded from `./run --apply`
by default. The examples can be copied into a new deployment repo and run after filling
in credentials and IPs.

## Changes

- **`de3-mikrotik-pkg-repo`** — `git mv routeros/example-lab → routeros/examples-archive/example-lab`. Split single config_params key into three: `examples-archive` (with `_skip_on_build: true`), `examples-archive/example-lab` (region/endpoint), and the switch entry.

- **`de3-unifi-pkg-repo`** — Added three example units (network VLANs, port profiles, device port assignments) with full YAML example config including standard homelab IP scheme. Removed empty `examples/.gitkeep`.

- **`de3-aws-pkg-repo`** — Added S3 bucket and all-config object upload examples. Config_params includes AWS profile/account placeholders.

- **`de3-azure-pkg-repo`** — Added Azure Blob Storage container example. Config_params includes resource group and storage account placeholders.

- **`de3-gcp-pkg-repo`** — Added `examples-archive/.gitkeep`. Existing units under `us-central1/` already serve as examples with `_skip_on_build: true` at the `gcp-pkg/_stack/gcp:` ancestor.

- **`de3-proxmox-pkg-repo`** — Added ISO download, Ubuntu VM, and install-proxmox examples for both proxmox and null providers. Added `_proxmox_deps.hcl` stub explaining how to wire in real dependencies.

- **`de3-maas-pkg-repo`** — Added full 6-stage MaaS lifecycle tree (machine → commission → ready → allocated → deploying → deployed) for an AMT-managed physical machine. Added configure-region null example. Added `_maas_deps.hcl` stub.

- **`de3-mesh-central-pkg-repo`** — Fixed orphaned `config_params` entry pointing to non-existent `proxmox/example-lab/` path. Created directory at `examples-archive/example-lab/` and updated config path. Added `_proxmox_deps.hcl` stub.

- **`de3-image-maker-pkg-repo`** — Added image-maker VM example with ISO dependencies mocked (so the unit initializes without pre-existing ISO units) and after_hook that triggers Packer/Kairos builds on apply.

- **`de3-framework-pkg-repo: skip-parameters.md`** — Updated example code blocks to use `examples-archive/` naming convention with the full ancestor config structure (including `_env`, `_region`, `project_prefix` dummy values).

- **`de3-framework-pkg-repo: ai-plans/`** — Archived plan `copy-examples-to-individial-package-repos.md`.

## Notes

- The `_proxmox_deps.hcl` and `_maas_deps.hcl` stubs in examples-archive have no active dependencies (commented out). In a real deployment, copy these files and uncomment/set the correct paths to your configure-proxmox / sync-maas-api-key units.
- The `_skip_on_build` evaluatability requirement applies: even though these units are excluded from build, Terragrunt still evaluates their locals during graph discovery. All ancestors have dummy values (`_env: example`, `_region: example-lab`, `project_prefix: example`) to prevent crashes.
- The image-maker example uses `mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "apply", "destroy"]` for all ISO dependencies so the unit works standalone without pre-existing ISO units in state.
- GCP chose Option B (add `.gitkeep` alongside existing units) since the existing units at `us-central1/` are already functional examples with `_skip_on_build: true`.
