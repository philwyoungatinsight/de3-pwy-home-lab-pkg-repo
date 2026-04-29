include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}
include "proxmox_deps" {
  path = find_in_parent_folders("_proxmox_deps.hcl")
}


# Ubuntu 24.04 live-server ISO — must be downloaded before Packer build runs.
dependency "ubuntu_24_server_iso" {
  config_path = "${include.root.locals.stack_root}/infra/pwy-home-lab-pkg/_stack/proxmox/pwy-homelab/pve-nodes/pve-1/isos/ubuntu-24-server"
  mock_outputs = {
    file_id   = "local:iso/ubuntu-24.04.2-live-server-amd64.iso"
    node_name = "pve"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "apply", "destroy"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}

# Rocky Linux 9.5 minimal ISO — must be downloaded before Packer build runs.
dependency "rocky_9_installer_iso" {
  config_path = "${include.root.locals.stack_root}/infra/pwy-home-lab-pkg/_stack/proxmox/pwy-homelab/pve-nodes/pve-1/isos/rocky-9-installer"
  mock_outputs = {
    file_id   = "local:iso/Rocky-9.7-x86_64-minimal.iso"
    node_name = "pve"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "apply", "destroy"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}

# The ubuntu-24 cloud image must be present on the node before the VM can be created.
dependency "ubuntu_24_cloud_image" {
  config_path = "${include.root.locals.stack_root}/infra/pwy-home-lab-pkg/_stack/proxmox/pwy-homelab/pve-nodes/pve-1/isos/ubuntu-24"
  mock_outputs = {
    file_id   = "local:import/noble-server-cloudimg-amd64.qcow2"
    node_name = "pve"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "apply", "destroy"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}

# Cloud-init vendor-data snippet (installs qemu-guest-agent via cloud-init)
dependency "guest_agent_cloud_init" {
  config_path = "${include.root.locals.stack_root}/infra/pwy-home-lab-pkg/_stack/proxmox/pwy-homelab/pve-nodes/pve-1/snippets/guest-agent"
  mock_outputs = {
    file_id   = "local:snippets/cloud-init-guest-agent.cfg"
    node_name = "pve"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "apply", "destroy"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}

terraform {
  source = "${include.root.locals.modules_dir}/proxmox_virtual_environment_vm"

  # After the image-maker VM is created/updated, automatically run the
  # build-images Ansible playbook to build Packer templates and Kairos ISOs.
  # The hook is non-fatal: if the VM is not yet reachable (e.g. first boot
  # still in progress), the operator can re-run the hook manually once the VM is up:
  #   ${include.root.locals._tg_scripts}/image-maker/build-images/run --build
  after_hook "build_images" {
    commands = ["apply"]
    execute  = [
      "${include.root.locals._tg_scripts}/image-maker/build-images/run",
      "--build"
    ]
    run_on_error = false
  }
}

# ---------------------------------------------------------------------------
# image-maker VM — Ubuntu 24.04, dedicated image build host.
#
# Runs Packer (proxmox-iso builder) and Kairos auroraboot to create Proxmox
# VM templates for Ubuntu 24.04 and Rocky Linux 9.
#
# Image building is triggered by the after_hook above (on each apply), or manually:
#   infra/image-maker-pkg/_tg_scripts/image-maker/build-images/run --build
#
# Configure overrides in pwy-home-lab-pkg.yaml under:
#   "pwy-home-lab-pkg/_stack/proxmox/pwy-homelab/pve-nodes/pve-1/vms/utils/image-maker"
#
# Kairos settings:
#   kairos_version:          v3.4.1  (auroraboot/kairos release tag)
#   kairos_ubuntu_release:   24.04
#   kairos_rocky_release:    9
# ---------------------------------------------------------------------------

locals {
  node_name      = include.root.locals.unit_params.node_name
  disk_datastore = include.root.locals.unit_params.datastore_vm
  network_bridge = include.root.locals.unit_params.network_bridge

  vm_name        = try(include.root.locals.unit_params.vm_name, include.root.locals.p_unit)
  vm_id          = try(include.root.locals.unit_params.vm_id, null)
  disk_size      = try(include.root.locals.unit_params.disk_size, 60)
  memory_mb      = try(include.root.locals.unit_params.memory_mb, 8192)
  cpu_cores      = try(include.root.locals.unit_params.cpu_cores, 4)
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

  # additional_tags accumulates from all ancestor levels (not last-wins).
  additional_tags = distinct(flatten([
    for params in include.root.locals._ancestor_param_list :
    try(params.additional_tags, [])
  ]))

  # Cloud-init — inherited from pve-1 defaults; override per-VM in YAML if needed.
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

  # Primary disk (imported from the Ubuntu 24.04 cloud image)
  disk_datastore   = local.disk_datastore
  disk_size        = local.disk_size
  disk_interface   = "virtio0"
  disk_import_from = dependency.ubuntu_24_cloud_image.outputs.file_id

  # Network
  network_bridge      = local.network_bridge
  network_mac_address = local.network_mac_address

  # Cloud-init drive
  cloud_init_datastore           = local.disk_datastore
  cloud_init_vendor_data_file_id = dependency.guest_agent_cloud_init.outputs.file_id
  cloud_init_user                = local.cloud_init_user
  cloud_init_password            = local.cloud_init_password
  cloud_init_ssh_keys            = local.cloud_init_ssh_keys
  cloud_init_ip_address          = local.cloud_init_ip_address
  cloud_init_gateway             = local.cloud_init_gateway
  cloud_init_dns_servers         = local.cloud_init_dns_servers
  cloud_init_dns_domain          = local.cloud_init_dns_domain

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
  tags            = concat(include.root.locals.common_tags_list, local.additional_tags)
}
