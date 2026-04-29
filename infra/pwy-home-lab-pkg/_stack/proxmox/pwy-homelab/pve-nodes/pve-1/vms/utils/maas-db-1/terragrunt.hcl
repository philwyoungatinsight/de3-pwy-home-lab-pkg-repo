include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}
include "proxmox_deps" {
  path = find_in_parent_folders("_proxmox_deps.hcl")
}

dependency "ubuntu_24_cloud_image" {
  config_path = "../../../isos/ubuntu-24"
  mock_outputs = {
    file_id   = "local:import/noble-server-cloudimg-amd64.qcow2"
    node_name = "pve"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "apply", "destroy"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}

dependency "guest_agent_cloud_init" {
  config_path = "../../../snippets/guest-agent"
  mock_outputs = {
    file_id   = "local:snippets/cloud-init-guest-agent.cfg"
    node_name = "pve"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "apply", "destroy"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}

terraform {
  source = "${include.root.locals.modules_dir}/proxmox_virtual_environment_vm"
}

# ---------------------------------------------------------------------------
# MaaS DB VM — Ubuntu 24.04, tagged role_maas_db.
# Hosts PostgreSQL database for the MaaS region controller.
# Static IP 10.0.10.12/24 configured via cloud-init.
# ---------------------------------------------------------------------------

locals {
  node_name      = include.root.locals.unit_params.node_name
  disk_datastore = include.root.locals.unit_params.datastore_vm
  network_bridge = include.root.locals.unit_params.network_bridge

  vm_name        = try(include.root.locals.unit_params.vm_name, include.root.locals.p_unit)
  vm_id          = try(include.root.locals.unit_params.vm_id, null)
  disk_size      = try(include.root.locals.unit_params.disk_size, 20)
  memory_mb      = try(include.root.locals.unit_params.memory_mb, 4096)
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

  network_mac_address = try(include.root.locals.unit_params.network_mac_address, upper(include.root.locals._default_mac_address))
  additional_tags = distinct(flatten([
    for params in include.root.locals._ancestor_param_list :
    try(params.additional_tags, [])
  ]))

  cloud_init_user        = try(include.root.locals.unit_params.cloud_init_user, null)
  cloud_init_password    = try(include.root.locals.unit_secret_params.cloud_init_password, null)
  cloud_init_ssh_keys    = try(include.root.locals.unit_params.cloud_init_ssh_keys, null)
  cloud_init_ip_address  = try(include.root.locals.unit_params.cloud_init_ip_address, "dhcp")
  cloud_init_gateway     = try(include.root.locals.unit_params.cloud_init_gateway, null)
  cloud_init_dns_servers = try(include.root.locals.unit_params.cloud_init_dns_servers, null)
  cloud_init_dns_domain  = try(include.root.locals.unit_params.cloud_init_dns_domain, null)
}

inputs = {
  node_name = local.node_name
  vm_name   = local.vm_name
  vm_id     = local.vm_id

  disk_datastore   = local.disk_datastore
  disk_size        = local.disk_size
  disk_interface   = "virtio0"
  disk_import_from = dependency.ubuntu_24_cloud_image.outputs.file_id

  network_bridge      = local.network_bridge
  network_mac_address = local.network_mac_address

  cloud_init_datastore           = local.disk_datastore
  cloud_init_vendor_data_file_id = dependency.guest_agent_cloud_init.outputs.file_id
  cloud_init_user                = local.cloud_init_user
  cloud_init_password            = local.cloud_init_password
  cloud_init_ssh_keys            = local.cloud_init_ssh_keys
  cloud_init_ip_address          = local.cloud_init_ip_address
  cloud_init_gateway             = local.cloud_init_gateway
  cloud_init_dns_servers         = local.cloud_init_dns_servers
  cloud_init_dns_domain          = local.cloud_init_dns_domain

  memory_mb    = local.memory_mb
  cpu_cores    = local.cpu_cores
  cpu_sockets  = local.cpu_sockets
  cpu_type     = local.cpu_type
  machine_type = local.machine_type
  bios         = local.bios
  os_type      = local.os_type

  agent_enabled   = local.agent_enabled
  agent_timeout   = local.agent_timeout
  on_boot         = local.on_boot
  stop_on_destroy = local.stop_on_destroy
  tags            = concat(include.root.locals.common_tags_list, local.additional_tags)
}
