include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

# Hard dep: MeshCentral must be installed and running before enrolling agents.
dependency "configure_mesh_central" {
  config_path = "../configure-server"
  mock_outputs = { run_id = "0" }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

terraform {
  source = "${include.root.locals.modules_dir}/null_resource__run-script"
}

locals {
  _stack_root = dirname(find_in_parent_folders("root.hcl"))

  # Re-run when config or Ansible playbook/task files change,
  # or when MeshCentral is re-installed (configure_id changes).
  config_files = [
    "${include.root.locals.stack_root}/infra/mesh-central-pkg/_config/mesh-central-pkg.yaml",
  ]
  script_files = [
    for f in fileset("${include.root.locals._tg_scripts}/mesh-central/update/tasks", "*.yaml") :
    "${include.root.locals._tg_scripts}/mesh-central/update/tasks/${f}"
  ]
  config_hash = sha256(join("", [for f in concat(local.config_files, local.script_files) : filesha256(f)]))
}

# Soft dep: all managed hosts must be configured before enrollment.
# Depending on configure-physical-machines (rather than listing individual
# machines) keeps this generic — adding/removing machines requires no change
# here.  configure-physical-machines is the aggregating unit for the full
# machine fleet; it already enforces that MaaS is configured before it runs.
dependencies {
  paths = [
    "${local._stack_root}/infra/pwy-home-lab-pkg/_stack/null/pwy-homelab/configure-physical-machines",
  ]
}

inputs = {
  trigger    = "${local.config_hash}-${dependency.configure_mesh_central.outputs.run_id}"
  script_dir = "${include.root.locals._tg_scripts}/mesh-central/update"
}
