include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

# Hard dep: Proxmox VE must be installed before we can configure the newly
# installed nodes (storage pools, API tokens, VLAN-aware bridge).
dependency "install_proxmox" {
  config_path = "../install-proxmox"
  mock_outputs = { run_id = "0" }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

terraform {
  source = "${include.root.locals.modules_dir}/null_resource__run-script"
}

inputs = {
  # Trigger on install_proxmox.run_id so this re-runs whenever Proxmox is
  # (re-)installed, even if the config files themselves have not changed.
  trigger    = "${dependency.install_proxmox.outputs.run_id}"
  script_dir = "${include.root.locals._tg_scripts}/proxmox/configure"
}
