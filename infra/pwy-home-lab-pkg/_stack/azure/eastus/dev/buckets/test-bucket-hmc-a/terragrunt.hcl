include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  # unit_type: test_bucket
  source = "${include.root.locals.modules_dir}/azurerm_storage_container"
}

# Per-unit parameter overrides from config_params:
#   storage_account_name: pwytgstacktestbkt  (globally unique, 3-24 lowercase alphanumeric)
#   container_name: test-data
#   resource_group_name: pwy-tg-stack-test-bucket-rg
#   location: eastus
#
#   hns_enabled: false                        (true = ADLS Gen2; cannot change after creation)
#   versioning_enabled: false
#   blob_soft_delete_days: 7                  (0 = disabled)
#   container_soft_delete_days: 7             (0 = disabled)
#   immutability_policy:                      (null = disabled; Locked state is irreversible)
#     allow_protected_append_writes: true
#     state: Unlocked
#     period_since_creation_in_days: 1
#   lifecycle_rules:
#     - name: tier-and-expire
#       tier_to_cool_after_days_since_modification: 30
#       tier_to_archive_after_days_since_modification: 90
#       delete_after_days_since_modification: 365

locals {
  resource_group_name = try(
    include.root.locals.unit_params.resource_group_name,
    "${include.root.locals.unit_params.project_prefix}-${include.root.locals.p_unit}-rg"
  )
  storage_account_name = try(
    include.root.locals.unit_params.storage_account_name,
    substr(replace("${include.root.locals.unit_params.project_prefix}${include.root.locals.p_unit}", "-", ""), 0, 24)
  )
  container_name             = try(include.root.locals.unit_params.container_name, include.root.locals.p_unit)
  location                   = try(include.root.locals.unit_params.location, include.root.locals.p_region)
  hns_enabled                = try(include.root.locals.unit_params.hns_enabled, false)
  versioning_enabled         = try(include.root.locals.unit_params.versioning_enabled, false)
  blob_soft_delete_days      = try(include.root.locals.unit_params.blob_soft_delete_days, 7)
  container_soft_delete_days = try(include.root.locals.unit_params.container_soft_delete_days, 7)
  lifecycle_rules            = try(include.root.locals.unit_params.lifecycle_rules, [])
  immutability_policy        = try(include.root.locals.unit_params.immutability_policy, null)
}

inputs = {
  resource_group_name        = local.resource_group_name
  storage_account_name       = local.storage_account_name
  container_name             = local.container_name
  location                   = local.location
  tags                       = include.root.locals.common_tags
  hns_enabled                = local.hns_enabled
  versioning_enabled         = local.versioning_enabled
  blob_soft_delete_days      = local.blob_soft_delete_days
  container_soft_delete_days = local.container_soft_delete_days
  lifecycle_rules            = local.lifecycle_rules
  immutability_policy        = local.immutability_policy
}
