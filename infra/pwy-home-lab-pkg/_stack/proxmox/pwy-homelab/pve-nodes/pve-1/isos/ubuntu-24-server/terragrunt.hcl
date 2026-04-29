include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}
include "proxmox_deps" {
  path = find_in_parent_folders("_proxmox_deps.hcl")
}


terraform {
  source = "${include.root.locals.modules_dir}/proxmox_virtual_environment_download_file"
}

# ---------------------------------------------------------------------------
# Downloads Ubuntu 24.04 LTS live-server ISO directly onto the Proxmox node.
# Used by the Packer image-builder (iso_file reference in packer build).
# Avoids large ISO upload from image-maker VM via the Proxmox upload API.
#
# To pin a specific point release or add checksum verification, set in
# pwy-home-lab-pkg.yaml under config_params for this unit's path:
#   url:                "https://releases.ubuntu.com/24.04.2/ubuntu-24.04.2-live-server-amd64.iso"
#   checksum_algorithm: sha256
#   checksum:           "<sha256 from the Ubuntu release page>"
# ---------------------------------------------------------------------------

locals {
  node_name    = include.root.locals.unit_params.node_name
  datastore_id = include.root.locals.unit_params.datastore_iso
  url          = try(
    include.root.locals.unit_params.url,
    "https://releases.ubuntu.com/24.04.2/ubuntu-24.04.2-live-server-amd64.iso"
  )
  # Derive file_name from the URL so the provider skips the query-url-metadata
  # API call (which requires Sys.Audit privilege on the Proxmox token).
  _url_parts = split("/", local.url)
  file_name  = try(
    include.root.locals.unit_params.file_name,
    local._url_parts[length(local._url_parts) - 1]
  )
  checksum           = try(include.root.locals.unit_params.checksum, null)
  checksum_algorithm = try(include.root.locals.unit_params.checksum_algorithm, null)
}

inputs = {
  node_name          = local.node_name
  datastore_id       = local.datastore_id
  url                = local.url
  file_name          = local.file_name
  content_type         = "iso"
  checksum             = local.checksum
  checksum_algorithm   = local.checksum_algorithm
  overwrite_unmanaged  = true
  upload_timeout       = 3600  # 60 min — Ubuntu ISO is ~2.7 GB; 1800 timed out in practice
}
