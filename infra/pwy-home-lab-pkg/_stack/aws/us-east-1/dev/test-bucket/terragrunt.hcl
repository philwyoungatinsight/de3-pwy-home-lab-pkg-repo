include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  # unit_type: test_bucket
  source = "${include.root.locals.modules_dir}/aws_s3_bucket"
}

# ---------------------------------------------------------------------------
# Per-unit parameter overrides
# Add entries under pwy-home-lab-pkg.providers.aws.config_params
# keyed by the unit's ancestor path, e.g.:
#   "pwy-home-lab-pkg/_stack/aws/us-east-1/dev/test-bucket":
#     bucket_name: my-custom-bucket-name     # defaults to <project_prefix>-<unit>
#     force_destroy: true
#     versioning_enabled: true               # AWS default: true
#     object_lock_enabled: false             # must be set at bucket creation; default: false
#     expiration_days: 90                    # null = no expiration (default)
#     storage_class_transitions:             # default: [] (no transitions)
#       - days: 30
#         storage_class: STANDARD_IA
#       - days: 90
#         storage_class: GLACIER
#     replication:                           # null = disabled (default)
#       role_arn: arn:aws:iam::123456789012:role/replication-role
#       destination_bucket: arn:aws:s3:::my-dest-bucket
#       storage_class: STANDARD
# ---------------------------------------------------------------------------
locals {
  bucket_name = try(
    include.root.locals.unit_params.bucket_name,
    "${include.root.locals.unit_params.project_prefix}-${include.root.locals.p_unit}"
  )
  force_destroy             = try(include.root.locals.unit_params.force_destroy, true)
  object_lock_enabled       = try(include.root.locals.unit_params.object_lock_enabled, false)
  versioning_enabled        = try(include.root.locals.unit_params.versioning_enabled, true)
  expiration_days           = try(include.root.locals.unit_params.expiration_days, null)
  storage_class_transitions = try(include.root.locals.unit_params.storage_class_transitions, [])
  replication               = try(include.root.locals.unit_params.replication, null)
}

inputs = {
  bucket_name               = local.bucket_name
  force_destroy             = local.force_destroy
  object_lock_enabled       = local.object_lock_enabled
  versioning_enabled        = local.versioning_enabled
  expiration_days           = local.expiration_days
  storage_class_transitions = local.storage_class_transitions
  replication               = local.replication
  tags                      = include.root.locals.common_tags
}
