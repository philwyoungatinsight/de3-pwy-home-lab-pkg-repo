include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  # unit_type: gke_cluster
  source = "${include.root.locals.modules_dir}/google_container_cluster"
}

# ---------------------------------------------------------------------------
# Per-unit overrides — set these under:
#   pwy-home-lab-pkg.providers.gcp.config_params
#     .pwy-home-lab-pkg/_stack/gcp/us-central1/dev/clusters/gke-cluster-dev
# in pwy-home-lab-pkg.yaml.
#
# Overridable keys:
#   cluster_name             – defaults to <project_prefix>-<unit>
#   location                 – defaults to p_region (regional cluster)
#   network                  – VPC network name (default: "default")
#   subnetwork               – VPC subnetwork name (default: "default")
#   node_pool_name           – default: "primary"
#   node_count               – nodes per zone (default: 1)
#   machine_type             – GCE machine type (default: "e2-medium")
#   disk_size_gb             – node boot disk GB (default: 50)
#   disk_type                – pd-standard | pd-ssd | pd-balanced (default: "pd-standard")
#   auto_repair              – default: true
#   auto_upgrade             – default: true
#   deletion_protection      – default: false
#   cluster_ipv4_cidr_block  – pod CIDR (default: "" = GKE auto-assigns)
#   services_ipv4_cidr_block – service CIDR (default: "" = GKE auto-assigns)
#   workload_pool            – e.g. "<project>.svc.id.goog" (default: "" = disabled)
# ---------------------------------------------------------------------------
locals {
  up = include.root.locals.unit_params

  cluster_name             = try(local.up.cluster_name, "${include.root.locals.unit_params.project_prefix}-${include.root.locals.p_unit}")
  location                 = try(local.up.location, include.root.locals.p_region)
  network                  = try(local.up.network, "default")
  subnetwork               = try(local.up.subnetwork, "default")
  node_pool_name           = try(local.up.node_pool_name, "primary")
  node_count               = try(local.up.node_count, 1)
  machine_type             = try(local.up.machine_type, "e2-medium")
  disk_size_gb             = try(local.up.disk_size_gb, 50)
  disk_type                = try(local.up.disk_type, "pd-standard")
  auto_repair              = try(local.up.auto_repair, true)
  auto_upgrade             = try(local.up.auto_upgrade, true)
  deletion_protection      = try(local.up.deletion_protection, false)
  cluster_ipv4_cidr_block  = try(local.up.cluster_ipv4_cidr_block, "")
  services_ipv4_cidr_block = try(local.up.services_ipv4_cidr_block, "")
  workload_pool            = try(local.up.workload_pool, "")
}

inputs = {
  cluster_name             = local.cluster_name
  location                 = local.location
  network                  = local.network
  subnetwork               = local.subnetwork
  node_pool_name           = local.node_pool_name
  node_count               = local.node_count
  machine_type             = local.machine_type
  disk_size_gb             = local.disk_size_gb
  disk_type                = local.disk_type
  auto_repair              = local.auto_repair
  auto_upgrade             = local.auto_upgrade
  deletion_protection      = local.deletion_protection
  cluster_ipv4_cidr_block  = local.cluster_ipv4_cidr_block
  services_ipv4_cidr_block = local.services_ipv4_cidr_block
  workload_pool            = local.workload_pool
  labels                   = include.root.locals.common_tags
}
