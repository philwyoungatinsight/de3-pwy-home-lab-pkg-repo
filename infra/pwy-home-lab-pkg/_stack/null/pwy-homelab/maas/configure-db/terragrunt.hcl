include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

# Trigger: re-run Ansible whenever the MaaS DB VM is replaced (vm_id changes).
dependency "maas_db" {
  config_path = "${include.root.locals.stack_root}/infra/pwy-home-lab-pkg/_stack/proxmox/pwy-homelab/pve-nodes/pve-1/vms/utils/maas-db-1"
  mock_outputs = { vm_id = 0 }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

terraform {
  source = "${include.root.locals.modules_dir}/null_resource__configure-server"
}

locals {
  config_files = [
    for f in fileset("${include.root.locals.stack_root}/infra", "*/_config/*.yaml") :
    "${include.root.locals.stack_root}/infra/${f}"
    if !endswith(f, ".sops.yaml")
  ]
  script_files = [
    for f in fileset("${include.root.locals._tg_scripts}/maas/configure-db/tasks", "*.yaml") :
    "${include.root.locals._tg_scripts}/maas/configure-db/tasks/${f}"
  ]
  config_hash = sha256(join("", [
    for f in concat(local.config_files, local.script_files) : filesha256(f)
  ]))
}

inputs = {
  vm_id                = dependency.maas_db.outputs.vm_id
  configure_script_dir = "${include.root.locals._tg_scripts}/maas/configure-db"
  config_hash          = local.config_hash
}
