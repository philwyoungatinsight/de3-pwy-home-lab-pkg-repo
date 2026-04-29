include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  # unit_type: test_bucket
  source = "${include.root.locals.modules_dir}/google_storage_bucket"
}

# ---------------------------------------------------------------------------
# Per-unit parameter overrides
# Add entries under pwy-home-lab-pkg.providers.gcp.config_params.us-central1.dev.test-data
# in pwy-home-lab-pkg.yaml.  Overridable keys:
#   bucket_name: pwy-tg-stack-test-data      # defaults to <project_prefix>-<unit>
#   location:    US-CENTRAL1                 # defaults to upper(p_region)
#   storage_class: STANDARD                  # STANDARD | NEARLINE | COLDLINE | ARCHIVE
#   force_destroy: true
#   soft_delete_retention_seconds: 0         # 0 = disabled (default)
#   versioning_enabled: false
#   retention_period_seconds: 0
# ---------------------------------------------------------------------------
locals {
  bucket_name = try(
    include.root.locals.unit_params.bucket_name,
    "${include.root.locals.unit_params.project_prefix}-${include.root.locals.p_unit}"
  )
  location                    = try(include.root.locals.unit_params.location, upper(include.root.locals.p_region))
  storage_class               = try(include.root.locals.unit_params.storage_class, "STANDARD")
  force_destroy               = try(include.root.locals.unit_params.force_destroy, true)
  uniform_bucket_level_access = try(include.root.locals.unit_params.uniform_bucket_level_access, true)
  public_access_prevention    = try(include.root.locals.unit_params.public_access_prevention, "inherited")
  soft_delete_retention_seconds = try(include.root.locals.unit_params.soft_delete_retention_seconds, 0)
  versioning_enabled          = try(include.root.locals.unit_params.versioning_enabled, false)
  retention_period_seconds    = try(include.root.locals.unit_params.retention_period_seconds, 0)
  retention_is_locked         = try(include.root.locals.unit_params.retention_is_locked, false)
  lifecycle_rules             = try(include.root.locals.unit_params.lifecycle_rules, [])
}

inputs = {
  bucket_name                   = local.bucket_name
  location                      = local.location
  labels                        = include.root.locals.common_tags
  storage_class                 = local.storage_class
  force_destroy                 = local.force_destroy
  uniform_bucket_level_access   = local.uniform_bucket_level_access
  public_access_prevention      = local.public_access_prevention
  soft_delete_retention_seconds = local.soft_delete_retention_seconds
  versioning_enabled            = local.versioning_enabled
  retention_period_seconds      = local.retention_period_seconds
  retention_is_locked           = local.retention_is_locked
  lifecycle_rules               = local.lifecycle_rules
}
