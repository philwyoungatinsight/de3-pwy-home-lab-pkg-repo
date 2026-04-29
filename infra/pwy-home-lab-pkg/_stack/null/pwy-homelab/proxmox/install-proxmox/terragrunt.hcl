include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

# Soft dep: physical machines must be MaaS-deployed before Proxmox can be installed on them.
# configure-physical-machines is the aggregating unit for the full machine fleet.
dependencies {
  paths = [
    "${get_repo_root()}/infra/pwy-home-lab-pkg/_stack/null/pwy-homelab/configure-physical-machines",
  ]
}

terraform {
  source = "${include.root.locals.modules_dir}/null_resource__run-script"
}

locals {
  # Re-run when config or Ansible playbook/task files change.
  config_files = [
    "${include.root.locals.stack_root}/infra/proxmox-pkg/_config/proxmox-pkg.yaml",
  ]
  script_files = [
    for f in fileset("${include.root.locals._tg_scripts}/proxmox/install/tasks", "*.yaml") :
    "${include.root.locals._tg_scripts}/proxmox/install/tasks/${f}"
  ]
  config_hash = sha256(join("", [for f in concat(local.config_files, local.script_files) : filesha256(f)]))
}

inputs = {
  trigger    = local.config_hash
  script_dir = "${include.root.locals._tg_scripts}/proxmox/install"
}
