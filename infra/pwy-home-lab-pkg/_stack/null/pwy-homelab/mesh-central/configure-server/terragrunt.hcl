include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

# Trigger: re-run Ansible whenever the mesh-central VM is replaced (vm_id changes).
dependency "mesh_central" {
  config_path = "${include.root.locals.stack_root}/infra/pwy-home-lab-pkg/_stack/proxmox/pwy-homelab/pve-nodes/pve-1/vms/utils/mesh-central"
  mock_outputs = { vm_id = 0 }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

terraform {
  source = "${include.root.locals.modules_dir}/null_resource__run-script"
}

inputs = {
  trigger    = tostring(dependency.mesh_central.outputs.vm_id)
  script_dir = "${include.root.locals._tg_scripts}/mesh-central/install"
}
