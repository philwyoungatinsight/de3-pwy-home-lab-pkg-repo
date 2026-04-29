include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}
include "maas_deps" {
  path = find_in_parent_folders("_maas_deps.hcl")
}

# Commission ms01-01 in MaaS and deploy Debian trixie to it (for Proxmox VE 9).
#
# Power management — set power_type in pwy-home-lab-pkg.yaml (current: amt):
#   smart_plug — TP-Link Kasa/Tapo via smart-plug-proxy (BIOS: power-on-after-AC-loss required)
#   amt        — Intel AMT (port 16993, TLS) — requires MEBx setup
#   ipmi       — IPMI v2 BMC: Dell iDRAC (older), HP iLO (older), Cisco CIMC
#   redfish    — Redfish REST API: iDRAC 9+, iLO 5+, Cisco CIMC (Redfish enabled)
#
# Pre-conditions (one-time physical setup — everything else is automated):
#   1. BIOS: disable Secure Boot, enable PXE in boot order.
#      (smart_plug: also enable "Power on after AC loss".)
#   2. (amt) MEBx: activate AMT, set admin password, enable network access.
#   3. pxe_mac_address and power-type-specific params set in
#      providers.maas.config_params["pwy-home-lab-pkg/_stack/maas/pwy-homelab/machines/ms01-01"]
#      in pwy-home-lab-pkg.yaml.
#   4. power_user / power_pass in pwy-home-lab-pkg_secrets.sops.yaml
#      under the same path (required for amt, ipmi, redfish).
#
# Configuration: pwy-home-lab-pkg.yaml
#   providers.maas.config_params["pwy-home-lab-pkg/_stack/maas/pwy-homelab/machines/ms01-01"]
#
# Secrets: pwy-home-lab-pkg_secrets.sops.yaml
#   providers.maas.config_params["pwy-home-lab-pkg/_stack/maas/pwy-homelab/machines/ms01-01"]
terraform {
  source = "${include.root.locals.modules_dir}/maas_machine"
  # Auto-import the auto-enlisted machine before apply.
  # Power-cycles the machine (smart_plug: off→on via proxy; amt: hard reset via wsman)
  # so it PXE boots and auto-enlists in MaaS without manual intervention.
  before_hook "auto_import_maas_machine" {
    commands = ["apply"]
    execute  = [
      "${include.root.locals._tg_scripts}/maas/auto-import/run",
      local.up.pxe_mac_address,
      local.up.maas_host,
      local._power_type,
      local._plug_host,
      local._plug_type,
      local._mgmt_ip,
      try(local.sp.power_pass, ""),
      tostring(try(local.up.mgmt_wake_via_plug, false)),
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
  up          = include.root.locals.unit_params
  sp          = include.root.locals.unit_secret_params
  _power_type = try(local.up.power_type, "amt")
  _proxy      = "http://${try(local.up.maas_host, "")}:7050"
  _plug_host  = try(local.up.smart_plug_host, "")
  _plug_type  = try(local.up.smart_plug_type, "kasa")
  # Management interface IP: varies by power type. Passed as arg 6 to auto-import/run.
  _mgmt_ip    = (local._power_type == "ipmi" ? try(local.up.ipmi_address, "") :
                 local._power_type == "redfish" ? try(local.up.redfish_address, "") :
                 try(local.up.amt_address, ""))
  # Build cloud-init user_data from cloud_init_ssh_keys / cloud_init_user /
  # cloud_init_password (all optional). Generates a #cloud-config block with:
  #   - ssh_authorized_keys (if cloud_init_ssh_keys is set)
  #   - chpasswd + ssh_pwauth: true (if cloud_init_password set in secrets) —
  #     enables SSH password login AND console/terminal password login
  _ssh_keys = try(local.up.cloud_init_ssh_keys, [])
  _ci_user  = try(local.up.cloud_init_user, "debian")
  _ci_pass  = try(local.sp.cloud_init_password, "")
  _has_keys = length(local._ssh_keys) > 0
  _has_pass = local._ci_pass != ""
  _user_data = (local._has_keys || local._has_pass) ? join("", concat(
    ["#cloud-config\n"],
    local._has_keys ? concat(
      ["ssh_authorized_keys:\n"],
      [for k in local._ssh_keys : "  - ${k}\n"]
    ) : [],
    local._has_pass ? [
      "chpasswd:\n",
      "  users:\n",
      "    - name: ${local._ci_user}\n",
      "      password: ${local._ci_pass}\n",
      "      type: text\n",
      "  expire: false\n",
      "ssh_pwauth: true\n"
    ] : []
  )) : ""
  # tomap() on each branch ensures consistent map(string) type for the conditional.
  # Supported: smart_plug (→ MaaS webhook), ipmi (iDRAC/iLO/CIMC), redfish (iDRAC 9+/iLO 5+),
  #            manual (no BMC — empty params), amt (default).
  _power_params = local._power_type == "smart_plug" ? tomap({
    power_on_uri    = "${local._proxy}/power/on?host=${local._plug_host}&type=${local._plug_type}"
    power_off_uri   = "${local._proxy}/power/off?host=${local._plug_host}&type=${local._plug_type}"
    power_query_uri = "${local._proxy}/power/status?host=${local._plug_host}&type=${local._plug_type}"
    power_on_regex  = "\"state\".*\"on\""
    power_off_regex = "\"state\".*\"off\""
  }) : local._power_type == "ipmi" ? tomap({
    power_address = try(local.up.ipmi_address, "")
    power_user    = try(local.sp.power_user, "admin")
    power_pass    = try(local.sp.power_pass, "")
    power_driver  = try(local.up.power_driver, "LAN_2_0")
  }) : local._power_type == "redfish" ? tomap({
    power_address = try(local.up.redfish_address, "")
    power_user    = try(local.sp.power_user, "admin")
    power_pass    = try(local.sp.power_pass, "")
    node_id       = try(local.up.node_id, "/redfish/v1/Systems/1")
  }) : local._power_type == "manual" ? tomap({}) : tomap({
    # amt (default)
    power_address = try(local.up.amt_address, "")
    power_user    = try(local.sp.power_user, "admin")
    power_pass    = try(local.sp.power_pass, "")
    port          = tostring(try(local.up.amt_port, 16993))
  })
}
inputs = {
  stop_after_new  = true
  machine_name    = include.root.locals.p_unit
  pxe_mac_address = try(local.up.pxe_mac_address, "")
  # smart_plug → webhook (MaaS built-in); ipmi/redfish/amt pass through unchanged
  power_type                = local._power_type == "smart_plug" ? "webhook" : local._power_type
  power_parameters_override = local._power_params
  maas_host                 = try(local.up.maas_host, "")
  deploy_distro             = try(local.up.deploy_distro, "noble")
  deploy_osystem            = try(local.up.deploy_osystem, "")
  deploy_user_data          = local._user_data
  release_erase             = try(local.up.release_erase, false)
  # provisioning_ip pins ms01-01 to a fixed IP on the provisioning VLAN (VLAN 12)
  # in MaaS (mode=STATIC on the primary interface). Passed to commission-and-wait.sh
  # as MAAS_STATIC_IP. ansible_host should match. Set in config_params["...ms01-01"].
  provisioning_ip = try(local.up.provisioning_ip, "")
}
