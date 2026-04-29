include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

# Hard dep: MaaS region must be fully installed and configured before syncing the API
# key.  configure-region runs the full Ansible playbook (snap, boot images, etc.)
# — without this dep sync-maas-api-key starts in parallel and SSH-fails
# because MaaS isn't installed yet.
dependency "configure_region" {
  config_path = "../configure-region"
  mock_outputs = { configure_id = "0" }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "apply", "destroy"]
}

# Hard dep: physical machines must be configured (AMT power drivers registered)
# before we sync the API key — ensures MaaS is fully set up and stable.
dependency "configure_physical_machines" {
  config_path = "../../configure-physical-machines"
  mock_outputs = { run_id = "0" }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "apply", "destroy"]
}

terraform {
  source = "${include.root.locals.modules_dir}/null_resource__run-script"
}

locals {
  # Re-run when configure-region or configure-physical-machines re-runs.
  config_files = [
    "${include.root.locals.stack_root}/infra/maas-pkg/_config/maas-pkg.yaml",
  ]
  config_hash = sha256(join("", [for f in local.config_files : filesha256(f)]))
}

inputs = {
  trigger    = "${local.config_hash}-${dependency.configure_region.outputs.configure_id}-${dependency.configure_physical_machines.outputs.run_id}"
  script_dir = "${include.root.locals._tg_scripts}/maas/sync-api-key"
}
