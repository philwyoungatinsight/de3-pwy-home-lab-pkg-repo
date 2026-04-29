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
  source = "${include.root.locals.modules_dir}/maas_lifecycle_commission"
}

locals {
  up          = include.root.locals.unit_params
  _power_type = try(local.up.power_type, "manual")
}

inputs = {
  system_id  = dependency.lifecycle_parent.outputs.system_id
  maas_host  = try(local.up.maas_host, "")
  power_type = local._power_type == "smart_plug" ? "webhook" : local._power_type
}
