include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}
include "proxmox_deps" {
  path = find_in_parent_folders("_proxmox_deps.hcl")
}


# Depend on the parent VM unit to obtain its IP address.
dependency "vm" {
  config_path = "../"
  mock_outputs = {
    ipv4_addresses = [["127.0.0.1"], ["192.0.2.1"]]
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

terraform {
  source = "${include.root.locals.modules_dir}/null_resource__ssh-script"
}

locals {
  # ssh_user defaults to cloud_init_user (set at node level, currently "ubuntu").
  user   = try(include.root.locals.unit_params.ssh_user, include.root.locals.unit_params.cloud_init_user, "ubuntu")
  script = include.root.locals.unit_params.setup_script
}

inputs = {
  # Pass the raw IP list; ssh-script module picks first non-loopback, non-link-local IP.
  # (Terragrunt v0.99+ does not allow dependency.* inside for expressions.)
  ipv4_addresses = dependency.vm.outputs.ipv4_addresses

  user      = local.user
  script    = local.script
  ssh_agent = try(include.root.locals.unit_params.ssh_agent, true)
}
