include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

# Hard dep: Proxmox must be installed before we can poll its API.
dependency "install_proxmox" {
  config_path = "../install-proxmox"
  mock_outputs = { run_id = "0" }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

terraform {
  source = "${include.root.locals.modules_dir}/null_resource__run-script"
}

locals {
  # Re-run when Proxmox endpoint configuration changes.
  config_files = [
    "${include.root.locals.stack_root}/infra/proxmox-pkg/_config/proxmox-pkg.yaml",
  ]
  config_hash = sha256(join("", [for f in local.config_files : filesha256(f)]))
}

inputs = {
  # Include install_proxmox.run_id so this re-polls the API whenever Proxmox is (re-)installed.
  trigger    = "${local.config_hash}-${dependency.install_proxmox.outputs.run_id}"
  script_dir = "${include.root.locals._tg_scripts}/proxmox/wait-for-api"
}
