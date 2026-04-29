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
# PXE test VM — boots from the provisioning network (VLAN 12).
# MaaS deploys the OS onto this VM via PXE + DHCP.
#
# No cloud image import, no cloud-init: MaaS manages OS provisioning.
# The NIC is tagged to VLAN 12 (provisioning) so MaaS can DHCP/PXE it.
# Boot order: network first (net0), then disk (virtio0) after OS install.
#
# Configure overrides in pwy-home-lab-pkg.yaml under:
#   "pwy-home-lab-pkg/_stack/proxmox/pwy-homelab/pve-nodes/pve-1/vms/utils/pxe-test-vm-1"
#
# Supported overrides:
#   vm_name:         pxe-test-vm-1   # defaults to directory name
#   vm_id:           null            # null = auto-assign
#   disk_size:       40              # GiB — destination for MaaS OS deploy
#   memory_mb:       4096            # MiB
#   cpu_cores:       2
#   network_vlan_id:     12              # must match the provisioning VLAN
#   boot_order:          ["net0", "virtio0"]
#   network_mac_address: "BC:24:11:D2:7F:E4"  # override auto-derived deterministic MAC (normally not needed)
# ---------------------------------------------------------------------------

locals {
  node_name      = include.root.locals.unit_params.node_name
  disk_datastore = include.root.locals.unit_params.datastore_vm
  network_bridge = include.root.locals.unit_params.network_bridge

  vm_name        = try(include.root.locals.unit_params.vm_name, include.root.locals.p_unit)
  vm_id          = try(include.root.locals.unit_params.vm_id, null)
  disk_size      = try(include.root.locals.unit_params.disk_size, 40)
  memory_mb      = try(include.root.locals.unit_params.memory_mb, 4096)
  cpu_cores      = try(include.root.locals.unit_params.cpu_cores, 2)
  cpu_sockets    = try(include.root.locals.unit_params.cpu_sockets, 1)
  on_boot        = try(include.root.locals.unit_params.on_boot, false)
  stop_on_destroy = try(include.root.locals.unit_params.stop_on_destroy, true)

  # PXE-specific: NIC on provisioning VLAN (50). MaaS serves DHCP/TFTP here.
  # Default is null (untagged) so this unit can be applied before the VLAN-aware
  # bridge is configured; set network_vlan_id: 12 in the YAML to enable PXE.
  network_vlan_id = try(include.root.locals.unit_params.network_vlan_id, null)

  # Deterministic MAC so the MaaS pxe_mac_address stays valid across destroy+recreate.
  # Falls back to a stable MAC derived from this unit's path via root.hcl._default_mac_address.
  # Override with network_mac_address in YAML only if needed.
  network_mac_address = try(include.root.locals.unit_params.network_mac_address, upper(include.root.locals._default_mac_address))

  # Boot from network first; switch to disk after MaaS deploys the OS.
  boot_order = try(include.root.locals.unit_params.boot_order, ["net0", "virtio0"])

  # additional_tags accumulates from all ancestor levels (not last-wins).
  additional_tags = distinct(flatten([
    for params in include.root.locals._ancestor_param_list :
    try(params.additional_tags, [])
  ]))
}

inputs = {
  node_name = local.node_name
  vm_name   = local.vm_name
  vm_id     = local.vm_id

  # Empty disk — MaaS writes the OS here during deployment.
  # No disk_import_from: Proxmox creates a blank disk.
  disk_datastore = local.disk_datastore
  disk_size      = local.disk_size
  disk_interface = "virtio0"

  # NIC on provisioning VLAN (50) — MaaS DHCP/PXE operates on this VLAN.
  network_bridge      = local.network_bridge
  network_vlan_id     = local.network_vlan_id
  network_mac_address = local.network_mac_address

  # PXE boot order: net0 first, virtio0 after OS is installed.
  boot_order = local.boot_order

  # No cloud-init — MaaS handles OS provisioning from scratch.
  cloud_init_datastore = null

  # Hardware
  memory_mb   = local.memory_mb
  cpu_cores   = local.cpu_cores
  cpu_sockets = local.cpu_sockets
  os_type     = "l26"
  bios        = "seabios"   # SeaBIOS supports legacy PXE (iPXE)

  # Enable guest agent — installed post-deploy by the setup-via-ssh child unit.
  agent_enabled  = true
  agent_timeout  = try(include.root.locals.unit_params.agent_timeout, "1m")

  # Lifecycle
  on_boot         = local.on_boot
  stop_on_destroy = local.stop_on_destroy
  tags            = concat(include.root.locals.common_tags_list, local.additional_tags)
}
