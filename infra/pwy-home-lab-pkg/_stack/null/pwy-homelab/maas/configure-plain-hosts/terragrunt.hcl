include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

# Hard dep: MaaS region must be configured so config_params (maas_host, etc.) are
# available via config_base. This also ensures the MaaS server is up before we
# try to use it as an SSH jump host.
dependency "configure_region" {
  config_path = "../configure-region"
  mock_outputs = { configure_id = "0" }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "apply", "destroy"]
}

# Hard dep: ms01-02 must be fully deployed (Rocky 9) before configuring OVS on it.
dependency "ms01_02_deployed" {
  config_path = "${include.root.locals.stack_root}/infra/pwy-home-lab-pkg/_stack/maas/pwy-homelab/machines/ms01-02/commission/ready/allocated/deploying/deployed"
  mock_outputs = { deployed_at = "0" }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "apply", "destroy"]
}

# Hard dep: ms01-03 must be fully deployed (Ubuntu 24.04) before configuring OVS on it.
dependency "ms01_03_deployed" {
  config_path = "${include.root.locals.stack_root}/infra/pwy-home-lab-pkg/_stack/maas/pwy-homelab/machines/ms01-03/commission/ready/allocated/deploying/deployed"
  mock_outputs = { deployed_at = "0" }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "apply", "destroy"]
}

terraform {
  source = "${include.root.locals.modules_dir}/null_resource__run-script"
}

locals {
  # Re-run whenever:
  #   - the playbook or config changes (config_hash)
  #   - a host is re-deployed by MaaS (deployed_at changes → OVS is wiped by the
  #     new OS install, so we must re-configure it)
  config_files = [
    "${include.root.locals.stack_root}/infra/maas-pkg/_config/maas-pkg.yaml",
    "${include.root.locals.stack_root}/infra/pwy-home-lab-pkg/_config/pwy-home-lab-pkg.yaml",
    "${include.root.locals._tg_scripts}/maas/configure-plain-hosts/ansible.cfg",
  ]
  script_files = [
    "${include.root.locals._tg_scripts}/maas/configure-plain-hosts/playbook.configure-plain-hosts.yaml",
  ]
  config_hash = sha256(join("", [for f in concat(local.config_files, local.script_files) : filesha256(f)]))
}

inputs = {
  trigger    = "${local.config_hash}-${dependency.ms01_02_deployed.outputs.deployed_at}-${dependency.ms01_03_deployed.outputs.deployed_at}"
  script_dir = "${include.root.locals._tg_scripts}/maas/configure-plain-hosts"
}
