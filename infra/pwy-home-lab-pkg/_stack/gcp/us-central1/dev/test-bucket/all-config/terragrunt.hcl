include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${include.root.locals.modules_dir}/google_storage_bucket_object"
}

dependency "test_data_bucket" {
  config_path = ".."
  mock_outputs = {
    bucket_name = "mock-bucket"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "apply", "destroy"]
}

locals {
  object_name = try(include.root.locals.unit_params.object_name, include.root.locals.p_unit)
  content     = jsonencode(include.root.locals._cfg)
}

inputs = {
  bucket_name  = try(
    include.root.locals.unit_params.bucket_name,
    dependency.test_data_bucket.outputs.bucket_name
  )
  object_name  = local.object_name
  content      = local.content
  content_type = try(include.root.locals.unit_params.content_type, "application/json")
}
