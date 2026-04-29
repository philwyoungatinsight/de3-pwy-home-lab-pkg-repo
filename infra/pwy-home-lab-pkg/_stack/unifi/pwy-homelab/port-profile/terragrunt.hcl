#  Because the port-profile module uses ignore_changes = all,
#  you need to taint and re-apply the port-profile unit to push the new profiles to UniFi:
#
#  cd infra/pwy-home-lab-pkg/_stack/unifi/pwy-homelab/port-profile
#  terragrunt state list  # find the resource keys
#  terragrunt taint 'unifi_port_profile.this["provisioning_only"]'
#  terragrunt taint 'unifi_port_profile.this["ms01_trunk"]'
#  terragrunt apply

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

# Network IDs from the network unit — needed to map VLAN keys to resource IDs.
dependency "network" {
  config_path = "../network"
  mock_outputs = {
    network_ids = {}
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

terraform {
  source = "${include.root.locals.modules_dir}/unifi_port_profile"

  # Limit parallelism to avoid 429 rate-limiting on the UDM login endpoint.
  # The paultyng/unifi provider re-authenticates per resource.
  extra_arguments "rate_limit" {
    commands  = ["apply", "plan", "destroy"]
    arguments = ["-parallelism=1"]
  }

  # Skip per-resource API refresh on apply to avoid triggering the UDM login
  # rate limiter (429). Plan and destroy still refresh.
  extra_arguments "no_refresh_apply" {
    commands  = ["apply"]
    arguments = ["-refresh=false"]
  }
}

# ---------------------------------------------------------------------------
# Per-unit overrides via pwy-home-lab-pkg.yaml config_params.
# Add entries under "pwy-home-lab-pkg/_stack/unifi/pwy-homelab/port-profile" to set:
#
#   port_profiles:                  # Map of profile key -> profile config object
#     trunk_all:
#       name: Trunk-All
#       forward: all
#     servers:
#       name: Servers
#       forward: customize
#       native_vlan: vlan_10        # key in vlans map (native/untagged VLAN)
#       tagged_vlans:               # list of keys from vlans map to tag
#         - vlan_20
#         - vlan_30
# ---------------------------------------------------------------------------

locals {
  port_profiles = try(include.root.locals.unit_params.port_profiles, {})

  # Credentials for the VLAN patch script (null_resource.vlan_patch local-exec).
  # The script needs direct API access because the provider does not support
  # the tagged_vlan_mgmt=custom field required by UniFi 10.x.
  unifi_api_url  = try(include.root.locals.unit_params._provider_unifi_api_url, "")
  unifi_username = try(include.root.locals.unit_secret_params["_provider_unifi_username"], "")
  unifi_password = try(include.root.locals.unit_secret_params["_provider_unifi_password"], "")
}

inputs = {
  port_profiles  = local.port_profiles
  network_ids    = dependency.network.outputs.network_ids
  unifi_api_url  = local.unifi_api_url
  unifi_username = local.unifi_username
  unifi_password = local.unifi_password
}
