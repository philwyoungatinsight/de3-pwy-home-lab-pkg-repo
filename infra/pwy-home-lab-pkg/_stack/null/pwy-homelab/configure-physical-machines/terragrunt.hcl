include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

# Hard dep: MaaS region must be configured before we can enlist physical machines.
dependency "maas_configure_server" {
  config_path = "../maas/configure-region"
  mock_outputs = { configure_id = "0" }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

terraform {
  source = "${include.root.locals.modules_dir}/null_resource__run-script"
}

locals {
  # Re-run when config or Ansible playbook/task files change,
  # or when the MaaS server is replaced (configure_id changes → MaaS re-configured).
  config_files = [
    "${include.root.locals.stack_root}/infra/maas-pkg/_config/maas-pkg.yaml",
    "${include.root.locals._tg_scripts}/maas/configure-machines/ansible.cfg",
  ]
  script_files = [
    for f in fileset("${include.root.locals._tg_scripts}/maas/configure-machines/tasks", "*.yaml") :
    "${include.root.locals._tg_scripts}/maas/configure-machines/tasks/${f}"
  ]
  config_hash = sha256(join("", [for f in concat(local.config_files, local.script_files) : filesha256(f)]))
}

inputs = {
  trigger    = "${local.config_hash}-${dependency.maas_configure_server.outputs.configure_id}"
  script_dir = "${include.root.locals._tg_scripts}/maas/configure-machines"
}
