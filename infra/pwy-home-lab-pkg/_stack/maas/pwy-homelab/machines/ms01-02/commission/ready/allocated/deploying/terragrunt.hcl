include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}
dependency "lifecycle_parent" {
  config_path = ".."
  mock_outputs = {
    system_id = "placeholder-system-id"
    hostname  = "placeholder-hostname"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "apply"]
}

terraform {
  source = "${include.root.locals.modules_dir}/maas_lifecycle_deploy"
}

locals {
  up = include.root.locals.unit_params
  sp = include.root.locals.unit_secret_params
  _power_type = try(local.up.power_type, "manual")
  _proxy      = "http://${try(local.up.maas_host, "")}:7050"
  _plug_host  = try(local.up.smart_plug_host, "")
  _plug_type  = try(local.up.smart_plug_type, "kasa")
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
    power_address = try(local.up.amt_address, "")
    power_user    = try(local.sp.power_user, "admin")
    power_pass    = try(local.sp.power_pass, "")
    port          = tostring(try(local.up.amt_port, 16993))
  })
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
}

inputs = {
  system_id         = dependency.lifecycle_parent.outputs.system_id
  maas_host         = try(local.up.maas_host, "")
  deploy_osystem    = try(local.up.deploy_osystem, "")
  deploy_distro     = try(local.up.deploy_distro, "noble")
  deploy_user_data  = local._user_data
  power_type        = local._power_type == "smart_plug" ? "webhook" : local._power_type
  power_params_b64  = base64encode(jsonencode(local._power_params))
  smart_plug_host   = local._plug_host
  smart_plug_type   = local._plug_type
  smart_plug_proxy  = local._proxy
}
