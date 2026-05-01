# Dynamic SSH Config

## What this does

`_tg_scripts/local/update-ssh-config/run` generates a dynamic SSH config file from the
current Ansible inventory and ensures it is included in `~/.ssh/config`. It runs
automatically as part of the `local.updates` Terragrunt wave via `null_resource__run-script`.

After it runs, every host in the inventory is reachable with `ssh <hostname>` — no IP
addresses, users, or jump-box flags needed.

## How it works

1. Regenerates the Ansible inventory (`$_GENERATE_INVENTORY --exclude-unreachable`)
2. Parses `hosts.yml` and writes a `Host` stanza for each host to the dynamic config file
3. Prepends `Include <dynamic-config-path>` to `~/.ssh/config` if not already present
4. Translates `ansible_ssh_common_args` (e.g. `-J ubuntu@10.0.10.11`) into SSH config
   directives (`ProxyJump`, `StrictHostKeyChecking`, `UserKnownHostsFile`)

## Config path

The output file path is read from `pwy-home-lab-pkg.yaml`:

```yaml
pwy-home-lab-pkg:
  ssh_config:
    dynamic_config_path: ~/.ssh/conf.d/dynamic_ssh_config
```

## Running manually

```bash
# Regenerate inventory + rewrite SSH config
infra/pwy-home-lab-pkg/_tg_scripts/local/update-ssh-config/run --build

# Show current dynamic config
infra/pwy-home-lab-pkg/_tg_scripts/local/update-ssh-config/run --status

# Remove the generated file
infra/pwy-home-lab-pkg/_tg_scripts/local/update-ssh-config/run --clean
```

Or via make (same directory):

```bash
cd infra/pwy-home-lab-pkg/_tg_scripts/local/update-ssh-config
make        # build + test
make build
make clean
```
