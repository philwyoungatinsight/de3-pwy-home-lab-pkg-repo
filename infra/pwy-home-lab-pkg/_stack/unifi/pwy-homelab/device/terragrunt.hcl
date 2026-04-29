include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

# Port profile IDs from the port-profile unit — needed to map profile keys to IDs.
dependency "port_profile" {
  config_path = "../port-profile"
  mock_outputs = {
    port_profile_ids = {}
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

terraform {
  source = "${include.root.locals.modules_dir}/unifi_device"

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
# Add entries under "pwy-home-lab-pkg/_stack/unifi/pwy-homelab/device" to set:
#
#   devices:                        # Map of device key -> device config object
#     udm:
#       mac: aa:bb:cc:dd:ee:ff
#       name: UDM
#       type: gateway               # "gateway" (ignore_changes=all) or "switch" (default)
#     sw-living-room:
#       mac: aa:bb:cc:dd:ee:01
#       name: Switch-LivingRoom
#       type: switch
#       port_overrides:
#         "1":
#           name: NAS
#           port_profile: servers   # key in port_profiles map, or "" for default
# ---------------------------------------------------------------------------

locals {
  devices = try(include.root.locals.unit_params.devices, {})

  # Credentials for the port_override_patch null_resource.
  # The null_resource needs direct API access because the unifi_device provider's
  # Read() does not reliably detect port_override drift after switch reprovisions.
  unifi_api_url  = try(include.root.locals.unit_params._provider_unifi_api_url, "")
  unifi_username = try(include.root.locals.unit_secret_params["_provider_unifi_username"], "")
  unifi_password = try(include.root.locals.unit_secret_params["_provider_unifi_password"], "")
}

inputs = {
  devices          = local.devices
  port_profile_ids = dependency.port_profile.outputs.port_profile_ids
  unifi_api_url    = local.unifi_api_url
  unifi_username   = local.unifi_username
  unifi_password   = local.unifi_password
}
