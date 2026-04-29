include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}
include "proxmox_deps" {
  path = find_in_parent_folders("_proxmox_deps.hcl")
}


terraform {
  source = "${include.root.locals.modules_dir}/proxmox_virtual_environment_file"
}

# ---------------------------------------------------------------------------
# Upload a cloud-init user-data snippet that installs and enables the
# QEMU guest agent on first boot.
# Default source is a file under _CONFIG_DIR. Override with config_params:
#   source_file_path: "/path/to/guest-agent.cfg"
# ---------------------------------------------------------------------------

locals {
  node_name    = include.root.locals.unit_params.node_name
  datastore_id = try(include.root.locals.unit_params.datastore_snippets, include.root.locals.unit_params.datastore_iso)
  source_file_content = include.root.locals.unit_params.guest_agent_cloud_init
  file_name           = "cloud-init-guest-agent.cfg"
}

inputs = {
  node_name    = local.node_name
  datastore_id = local.datastore_id
  source_file_content = local.source_file_content
  file_name           = local.file_name
  content_type     = "snippets"
}
