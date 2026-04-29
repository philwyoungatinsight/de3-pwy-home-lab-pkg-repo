include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}
include "maas_deps" {
  path = find_in_parent_folders("_maas_deps.hcl")
}


# The Proxmox VM this MaaS unit manages. Its network_mac_address output gives
# the stable, deterministic MAC (derived from the VM unit's path via root.hcl),
# which is used as pxe_mac_address here — no explicit MAC needed in YAML.
dependency "proxmox_pxe_vm" {
  config_path = "${include.root.locals.stack_root}/infra/pwy-home-lab-pkg/_stack/proxmox/pwy-homelab/pve-nodes/pve-1/vms/utils/pxe-test-vm-1"
  # Mock MAC is intentionally invalid — apply is not in mock_outputs_allowed_terraform_commands
  # so the real MAC from state is always used during apply. The mock only activates during
  # plan/init/validate/destroy with no state, at which point the auto_import hook does not run.
  mock_outputs = {
    network_mac_address = "02:00:00:00:00:00"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}

# Commission pxe-test-vm-1 in MaaS and deploy Ubuntu noble to it.
#
# Pre-conditions:
#   1. The configure-maas-server Ansible playbook has run successfully.
#      (MaaS is installed, networking configured, boot images synced,
#       and the MaaS API key has been written to SOPS secrets.)
#   2. pxe-test-vm-1 has PXE-booted and auto-enlisted in MaaS (status: New).
#   3. Proxmox power credentials are set in SOPS secrets under
#      providers.maas.config_params["pwy-home-lab-pkg/_stack/maas/pwy-homelab/machines/pxe-test-vm-1"].
#
# Configuration comes from pwy-home-lab-pkg.yaml under:
#   providers.maas.config_params["pwy-home-lab-pkg/_stack/maas/pwy-homelab/machines/pxe-test-vm-1"]
#
# Secrets from pwy-home-lab-pkg_secrets.sops.yaml under:
#   providers.maas.config_params["pwy-home-lab-pkg/_stack/maas/pwy-homelab/machines/pxe-test-vm-1"]

terraform {
  source = "${include.root.locals.modules_dir}/maas_machine"

  # Auto-import the auto-enlisted machine before apply.
  # On destroy+recreate, pxe-test-vm-1 PXE boots and enlists in MaaS as "New".
  # This hook polls for it by MAC and imports it into TF state so that apply
  # can set power driver + commission + deploy without "MAC already in use" error.
  before_hook "auto_import_maas_machine" {
    commands = ["apply"]
    execute  = [
      "${include.root.locals._tg_scripts}/maas/auto-import/run",
      dependency.proxmox_pxe_vm.outputs.network_mac_address,
      local.up.maas_host,
    ]
  }
  before_hook "force_release_maas_machine" {
    commands = ["destroy"]
    execute  = [
      "${include.root.locals._tg_scripts}/maas/force-release/run",
      include.root.locals.p_unit,
      try(local.up.maas_host, ""),
    ]
  }
}

locals {
  up = include.root.locals.unit_params
  sp = include.root.locals.unit_secret_params
}

inputs = {
  stop_after_new     = true
  machine_name       = include.root.locals.p_unit
  # MAC comes from the Proxmox VM dependency (deterministic, path-derived).
  # No pxe_mac_address needed in YAML.
  pxe_mac_address    = dependency.proxmox_pxe_vm.outputs.network_mac_address
  power_type         = try(local.up.power_type, "manual")
  power_address      = try(local.up.power_address, "")
  power_vm_name      = try(local.up.power_vm_name, "")
  power_user         = try(local.sp.power_user, "")
  power_pass         = try(local.sp.power_pass, "")
  power_token_name   = try(local.sp.power_token_name, "")
  power_token_secret = try(local.sp.power_token_secret, "")
  maas_host          = try(local.up.maas_host, "")
  deploy_distro      = try(local.up.deploy_distro, "noble")
  release_erase      = try(local.up.release_erase, false)
}
