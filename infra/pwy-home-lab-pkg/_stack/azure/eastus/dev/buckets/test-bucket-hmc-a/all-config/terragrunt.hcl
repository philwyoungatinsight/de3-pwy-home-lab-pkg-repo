include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${include.root.locals.modules_dir}/azurerm_storage_blob"
}

# Dependency on parent container unit
dependency "test_data_bucket" {
  config_path = ".."
  mock_outputs = {
    bucket_name          = "mock-container"
    storage_account_name = "mockstorageacct"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "apply", "destroy"]
}

# Configuration parameters from YAML:
#   object_name: my-blob           (defaults to unit name)
#   content_type: application/json

locals {
  object_name = try(include.root.locals.unit_params.object_name, include.root.locals.p_unit)
  content     = jsonencode(include.root.locals._cfg)
}

inputs = {
  storage_account_name = dependency.test_data_bucket.outputs.storage_account_name
  container_name = try(
    include.root.locals.unit_params.bucket_name,
    dependency.test_data_bucket.outputs.bucket_name
  )
  object_name  = local.object_name
  content      = local.content
  content_type = try(include.root.locals.unit_params.content_type, "application/json")
  metadata     = include.root.locals.common_tags
}
