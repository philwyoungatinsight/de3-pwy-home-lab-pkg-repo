include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${include.root.locals.modules_dir}/aws_s3_object"
}

dependency "test_data_bucket" {
  config_path = ".."
  mock_outputs = {
    bucket_name = "mock-bucket"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "apply", "destroy"]
}

# ---------------------------------------------------------------------------
# Per-unit parameter overrides
# Add entries under pwy-home-lab-pkg.providers.aws.config_params
# keyed by the unit's ancestor path, e.g.:
#   "pwy-home-lab-pkg/_stack/aws/us-east-1/dev/test-bucket/all-config":
#     object_name: my-key                         # defaults to unit name (all-config)
#     bucket_name: override-bucket                # defaults to parent bucket output
#     content_type: application/json              # default
#     storage_class: STANDARD                     # default
#     object_lock_mode: GOVERNANCE                # null = disabled (default)
#     object_lock_retain_until_date: "2027-01-01T00:00:00Z"  # null = disabled (default)
# ---------------------------------------------------------------------------
locals {
  object_name = try(include.root.locals.unit_params.object_name, include.root.locals.p_unit)
  content     = jsonencode(include.root.locals._cfg)

  storage_class                 = try(include.root.locals.unit_params.storage_class, "STANDARD")
  object_lock_mode              = try(include.root.locals.unit_params.object_lock_mode, null)
  object_lock_retain_until_date = try(include.root.locals.unit_params.object_lock_retain_until_date, null)
}

inputs = {
  bucket_name  = try(
    include.root.locals.unit_params.bucket_name,
    dependency.test_data_bucket.outputs.bucket_name
  )
  object_name  = local.object_name
  content      = local.content
  content_type = try(include.root.locals.unit_params.content_type, "application/json")

  storage_class                 = local.storage_class
  tags                          = include.root.locals.common_tags
  metadata                      = include.root.locals.common_tags
  object_lock_mode              = local.object_lock_mode
  object_lock_retain_until_date = local.object_lock_retain_until_date
}
