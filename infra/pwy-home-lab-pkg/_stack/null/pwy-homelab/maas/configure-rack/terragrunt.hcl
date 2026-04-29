include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

# Trigger: re-run Ansible whenever the MaaS rack VM is replaced (vm_id changes).
dependency "maas_rack" {
  config_path = "${include.root.locals.stack_root}/infra/pwy-home-lab-pkg/_stack/proxmox/pwy-homelab/pve-nodes/pve-1/vms/utils/maas-rack-1"
  mock_outputs = { vm_id = 0 }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

# configure-region must complete before configure-rack so the region is
# initialised and the enrolment secret exists before the rack joins.
dependency "configure_region" {
  config_path = "../configure-region"
  mock_outputs = { configure_id = "0" }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "apply", "destroy"]
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
    for f in fileset("${include.root.locals._tg_scripts}/maas/configure-rack/tasks", "*.yaml") :
    "${include.root.locals._tg_scripts}/maas/configure-rack/tasks/${f}"
  ]
  config_hash = sha256(join("", [
    for f in concat(local.config_files, local.script_files) : filesha256(f)
  ]))
}

inputs = {
  vm_id                = dependency.maas_rack.outputs.vm_id
  configure_script_dir = "${include.root.locals._tg_scripts}/maas/configure-rack"
  config_hash          = local.config_hash
}
