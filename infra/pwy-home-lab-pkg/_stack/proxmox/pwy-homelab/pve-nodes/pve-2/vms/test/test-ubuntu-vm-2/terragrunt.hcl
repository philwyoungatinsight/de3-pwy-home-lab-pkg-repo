include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}
include "proxmox_deps" {
  path = find_in_parent_folders("_proxmox_deps.hcl")
}


# The ubuntu-24 cloud image must be present on the node before the VM can be created.
dependency "ubuntu_24_cloud_image" {
  config_path = "../../../isos/ubuntu-24"
  mock_outputs = {
    file_id = "local:import/noble-server-cloudimg-amd64.qcow2"
    node_name = "pve-2"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}

# Cloud-init user-data snippet (installs qemu-guest-agent)
dependency "guest_agent_cloud_init" {
  config_path = "../../../snippets/guest-agent"
  mock_outputs = {
    file_id = "local:snippets/cloud-init-guest-agent.cfg"
    node_name = "pve-2"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}

terraform {
  source = "${include.root.locals.modules_dir}/proxmox_virtual_environment_vm"
}

# ---------------------------------------------------------------------------
# Per-unit overrides via pwy-home-lab-pkg.yaml config_params.
# Add entries under the path for this unit (or the node level) to override:
#
#   vm_name:              test-ubuntu-vm-2   # defaults to the unit directory name
#   vm_id:                null               # null = auto-assign
#   disk_size:            32                 # GiB
#   memory_mb:            8192               # MiB (8 GiB default)
#   cpu_cores:            2
#   cpu_sockets:          1
#   cpu_type:             host
#   machine_type:         q35
#   bios:                 seabios
#   os_type:              l26
#   agent_enabled:        true
#   on_boot:              false
#   stop_on_destroy:      true
#   cloud_init_user:      ubuntu
#   cloud_init_ip_address: dhcp             # or "192.168.x.x/24" for static
#   cloud_init_gateway:   null             # set for static IP
#   cloud_init_dns_servers: ["1.1.1.1"]
#
# node_name / datastore_vm / network_bridge are inherited from the node-level
# config_params entry and do not need to be set per-VM.
# ---------------------------------------------------------------------------

locals {
  node_name      = include.root.locals.unit_params.node_name
  disk_datastore = include.root.locals.unit_params.datastore_vm
  network_bridge = include.root.locals.unit_params.network_bridge

  vm_name        = try(include.root.locals.unit_params.vm_name, include.root.locals.p_unit)
  vm_id          = try(include.root.locals.unit_params.vm_id, null)
  disk_size      = try(include.root.locals.unit_params.disk_size, 32)
  memory_mb      = try(include.root.locals.unit_params.memory_mb, 8192)
  cpu_cores      = try(include.root.locals.unit_params.cpu_cores, 2)
  cpu_sockets    = try(include.root.locals.unit_params.cpu_sockets, 1)
  cpu_type       = try(include.root.locals.unit_params.cpu_type, "host")
  machine_type   = try(include.root.locals.unit_params.machine_type, "q35")
  bios           = try(include.root.locals.unit_params.bios, "seabios")
  os_type        = try(include.root.locals.unit_params.os_type, "l26")
  agent_enabled  = try(include.root.locals.unit_params.agent_enabled, true)
  agent_timeout  = try(include.root.locals.unit_params.agent_timeout, "1m")
  on_boot        = try(include.root.locals.unit_params.on_boot, false)
  stop_on_destroy = try(include.root.locals.unit_params.stop_on_destroy, true)

  # Deterministic MAC derived from this unit's path. Override in YAML if needed.
  network_mac_address = try(include.root.locals.unit_params.network_mac_address, upper(include.root.locals._default_mac_address))

  # Cloud-init – all null unless explicitly set in config_params
  cloud_init_user         = try(include.root.locals.unit_params.cloud_init_user, null)
  cloud_init_password     = try(include.root.locals.unit_secret_params.cloud_init_password, null)
  cloud_init_ssh_keys     = try(include.root.locals.unit_params.cloud_init_ssh_keys, null)
  cloud_init_ip_address   = try(include.root.locals.unit_params.cloud_init_ip_address, null)
  cloud_init_gateway      = try(include.root.locals.unit_params.cloud_init_gateway, null)
  cloud_init_dns_servers  = try(include.root.locals.unit_params.cloud_init_dns_servers, null)
  cloud_init_dns_domain   = try(include.root.locals.unit_params.cloud_init_dns_domain, null)
}

inputs = {
  node_name      = local.node_name
  vm_name        = local.vm_name
  vm_id          = local.vm_id

  # Primary disk (imported from the Ubuntu 24.04 cloud image)
  disk_datastore = local.disk_datastore
  disk_size      = local.disk_size
  disk_interface = "virtio0"
  disk_import_from = dependency.ubuntu_24_cloud_image.outputs.file_id

  # Network
  network_bridge      = local.network_bridge
  network_mac_address = local.network_mac_address

  # Cloud-init drive (same datastore as VM disks)
  cloud_init_datastore    = local.disk_datastore
  cloud_init_vendor_data_file_id = dependency.guest_agent_cloud_init.outputs.file_id
  cloud_init_user         = local.cloud_init_user
  cloud_init_password     = local.cloud_init_password
  cloud_init_ssh_keys     = local.cloud_init_ssh_keys
  cloud_init_ip_address   = local.cloud_init_ip_address
  cloud_init_gateway      = local.cloud_init_gateway
  cloud_init_dns_servers  = local.cloud_init_dns_servers
  cloud_init_dns_domain   = local.cloud_init_dns_domain

  # Hardware
  memory_mb    = local.memory_mb
  cpu_cores    = local.cpu_cores
  cpu_sockets  = local.cpu_sockets
  cpu_type     = local.cpu_type
  machine_type = local.machine_type
  bios         = local.bios
  os_type      = local.os_type

  # Lifecycle
  agent_enabled   = local.agent_enabled
  agent_timeout   = local.agent_timeout
  on_boot         = local.on_boot
  stop_on_destroy = local.stop_on_destroy
  tags            = include.root.locals.common_tags_list
}
