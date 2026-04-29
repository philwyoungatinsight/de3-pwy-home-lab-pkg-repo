include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}
include "proxmox_deps" {
  path = find_in_parent_folders("_proxmox_deps.hcl")
}


terraform {
  source = "${include.root.locals.modules_dir}/proxmox_virtual_environment_vm"
}

# ---------------------------------------------------------------------------
# VM booted from the Kairos Ubuntu 24.04 ISO built by infra/image-maker-pkg/_tg_scripts/image-maker/build-images.
# Kairos auto-installs on first boot using the baked-in cloud-config (SSH keys,
# auto-install flag). No cloud-init drive needed — Kairos handles its own config.
#
# The ISO must exist in Proxmox before this VM is created. It is built and
# uploaded by infra/image-maker-pkg/_tg_scripts/image-maker/build-images (Stage 5 of `run --build`).
#
# Per-unit overrides via pwy-home-lab-pkg.yaml config_params:
#   iso_file_id:    "local:iso/kairos-ubuntu-24.04.iso"  # required
#   vm_name:        test-kairos-ubuntu-24-vm
#   vm_id:          null       # null = auto-assign
#   disk_size:      32         # GiB — blank disk Kairos installs to
#   memory_mb:      8192
#   cpu_cores:      2
#
# node_name / datastore_vm / network_bridge inherited from pve-1.
# ---------------------------------------------------------------------------

locals {
  node_name      = include.root.locals.unit_params.node_name
  disk_datastore = include.root.locals.unit_params.datastore_vm
  network_bridge = include.root.locals.unit_params.network_bridge

  vm_name     = try(include.root.locals.unit_params.vm_name, include.root.locals.p_unit)
  vm_id       = try(include.root.locals.unit_params.vm_id, null)
  iso_file_id = include.root.locals.unit_params.iso_file_id
  disk_size   = try(include.root.locals.unit_params.disk_size, 32)
  memory_mb   = try(include.root.locals.unit_params.memory_mb, 8192)
  cpu_cores   = try(include.root.locals.unit_params.cpu_cores, 2)
  cpu_sockets = try(include.root.locals.unit_params.cpu_sockets, 1)
  cpu_type    = try(include.root.locals.unit_params.cpu_type, "host")
  machine_type = try(include.root.locals.unit_params.machine_type, "q35")
  bios         = try(include.root.locals.unit_params.bios, "seabios")
  os_type      = try(include.root.locals.unit_params.os_type, "l26")
  # agent_enabled defaults false: Kairos does not guarantee qemu-guest-agent.
  agent_enabled   = try(include.root.locals.unit_params.agent_enabled, false)
  agent_timeout   = try(include.root.locals.unit_params.agent_timeout, "1m")
  on_boot         = try(include.root.locals.unit_params.on_boot, false)
  stop_on_destroy = try(include.root.locals.unit_params.stop_on_destroy, true)
  additional_tags = distinct(flatten([
    for params in include.root.locals._ancestor_param_list :
    try(params.additional_tags, [])
  ]))

  network_mac_address = try(include.root.locals.unit_params.network_mac_address, upper(include.root.locals._default_mac_address))
}

inputs = {
  node_name = local.node_name
  vm_name   = local.vm_name
  vm_id     = local.vm_id

  # Boot order: virtio0 first so that after installation the disk takes priority.
  # On first boot, virtio0 is empty (not bootable), so SeaBIOS falls through to
  # ide2 (CDROM/ISO) and Kairos installs to virtio0. On subsequent boots, the
  # installed GRUB on virtio0 takes over and the CDROM is never tried again.
  iso_file_id = local.iso_file_id
  boot_order  = ["virtio0", "ide2"]

  # Blank disk — Kairos installs itself here on first boot.
  disk_datastore = local.disk_datastore
  disk_size      = local.disk_size

  # Network
  network_bridge      = local.network_bridge
  network_mac_address = local.network_mac_address

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
