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
# Downloads the Ubuntu 24.04 LTS cloud image directly onto the Proxmox node.
# The file_id output is consumed by the VM units to import as the primary disk.
#
# To pin a specific build or add checksum verification, set in
# pwy-home-lab-pkg.yaml under config_params for this unit's path:
#   url:                "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
#   file_name:          "noble-server-cloudimg-amd64.qcow2"
#   checksum_algorithm: sha256
#   checksum:           "<sha256 from the Ubuntu cloud image manifest>"
# ---------------------------------------------------------------------------

locals {
  node_name    = include.root.locals.unit_params.node_name
  datastore_id = include.root.locals.unit_params.datastore_iso
  url          = try(
    include.root.locals.unit_params.url,
    "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
  )
  # Derive file_name from the URL so the provider skips the query-url-metadata
  # API call (which requires Sys.Audit privilege on the Proxmox token).
  _url_parts = split("/", local.url)
  _raw_name  = local._url_parts[length(local._url_parts) - 1]
  file_name  = try(
    include.root.locals.unit_params.file_name,
    replace(local._raw_name, ".img", ".qcow2")
  )
  checksum           = try(include.root.locals.unit_params.checksum, null)
  checksum_algorithm = try(include.root.locals.unit_params.checksum_algorithm, null)
}

inputs = {
  node_name          = local.node_name
  datastore_id       = local.datastore_id
  url                = local.url
  file_name          = local.file_name
  content_type         = "import"
  checksum             = local.checksum
  checksum_algorithm   = local.checksum_algorithm
  overwrite_unmanaged  = true
  upload_timeout       = 1800  # 30 min — cloud image ~500 MB; default 600s may time out
}
