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
# Downloads Ubuntu 22.04 LTS live-server ISO directly onto the Proxmox node.
# The file_id output can be referenced by VM units via a dependency block.
#
# To pin a specific point release or add checksum verification, set in
# pwy-home-lab-pkg.yaml under config_params for this unit's path:
#   url:                "https://releases.ubuntu.com/22.04/ubuntu-22.04.5-live-server-amd64.iso"
#   checksum_algorithm: sha256
#   checksum:           "<sha256 from the Ubuntu release page>"
# ---------------------------------------------------------------------------

locals {
  node_name    = include.root.locals.unit_params.node_name
  datastore_id = include.root.locals.unit_params.datastore_iso
  url          = try(
    include.root.locals.unit_params.url,
    "https://releases.ubuntu.com/22.04/ubuntu-22.04.5-live-server-amd64.iso"
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
  upload_timeout       = 1800  # 30 min — Ubuntu 22 ISO is ~1.5 GB; default 600s times out
}
