include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

# Hard dep: Proxmox must be reachable before we configure it.
dependency "wait_for_proxmox" {
  config_path = "../wait-for-proxmox"
  mock_outputs = { run_id = "0" }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}


terraform {
  source = "${include.root.locals.modules_dir}/null_resource__run-script"
}

locals {
  # Re-run when config or Ansible playbook/task files change.
  config_files = [
    "${include.root.locals.stack_root}/infra/proxmox-pkg/_config/proxmox-pkg.yaml",
  ]
  script_files = concat(
    [
      "${include.root.locals._tg_scripts}/proxmox/configure/playbook.configure-pve.yaml",
    ],
    [
      for f in fileset("${include.root.locals._tg_scripts}/proxmox/configure/tasks", "*.yaml") :
      "${include.root.locals._tg_scripts}/proxmox/configure/tasks/${f}"
    ]
  )
  config_hash = sha256(join("", [for f in concat(local.config_files, local.script_files) : filesha256(f)]))
}

inputs = {
  trigger    = local.config_hash
  script_dir = "${include.root.locals._tg_scripts}/proxmox/configure"
}
