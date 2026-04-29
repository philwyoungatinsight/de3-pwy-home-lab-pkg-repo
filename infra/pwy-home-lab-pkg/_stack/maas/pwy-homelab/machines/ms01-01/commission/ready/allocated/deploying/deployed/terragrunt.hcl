include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}
dependency "lifecycle_parent" {
  config_path = ".."
  mock_outputs = {
    system_id = "placeholder-system-id"
    hostname  = "placeholder-hostname"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "apply"]
}

terraform {
  source = "${include.root.locals.modules_dir}/maas_lifecycle_deployed"
}

locals {
  up = include.root.locals.unit_params
}

inputs = {
  system_id        = dependency.lifecycle_parent.outputs.system_id
  maas_host        = try(local.up.maas_host, "")
  cloud_public_ip  = try(local.up.cloud_public_ip, "")
  deploy_timeout   = try(local.up.deploy_wait_timeout, "10800")
}
