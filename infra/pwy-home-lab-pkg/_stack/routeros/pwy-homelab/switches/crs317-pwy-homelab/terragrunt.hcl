include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${include.root.locals.modules_dir}/routeros_switch"
}

# ---------------------------------------------------------------------------
# Per-unit config from pwy-home-lab-pkg.yaml config_params.
#
# Switch-specific values live under:
#   pwy-home-lab-pkg/_stack/routeros/pwy-homelab/switches/crs317-pwy-homelab
#
# Provider endpoint / credentials live under (ancestor-merged):
#   pwy-home-lab-pkg/_stack/routeros/pwy-homelab
#
# BOOTSTRAP: first apply uses endpoint apis://192.168.88.1:8729 (factory
# default, direct laptop RJ45 connection). After first apply update the
# endpoint in pwy-home-lab-pkg.yaml to "apis://10.0.11.5:8729" and re-apply.
# ---------------------------------------------------------------------------

locals {
  hostname           = try(include.root.locals.unit_params.hostname,            "crs317")
  management_vlan_id = try(include.root.locals.unit_params.management_vlan_id, 11)
  management_ip      = try(include.root.locals.unit_params.management_ip,       "")
  management_prefix  = try(include.root.locals.unit_params.management_prefix,   24)
  management_gateway = try(include.root.locals.unit_params.management_gateway,  "")
  storage_mtu        = try(include.root.locals.unit_params.storage_mtu,         9000)
  ports              = try(include.root.locals.unit_params.ports,               {})
  vlans              = try(include.root.locals.unit_params.vlans,               {})
}

inputs = {
  hostname           = local.hostname
  management_vlan_id = local.management_vlan_id
  management_ip      = local.management_ip
  management_prefix  = local.management_prefix
  management_gateway = local.management_gateway
  storage_mtu        = local.storage_mtu
  ports              = local.ports
  vlans              = local.vlans
}
