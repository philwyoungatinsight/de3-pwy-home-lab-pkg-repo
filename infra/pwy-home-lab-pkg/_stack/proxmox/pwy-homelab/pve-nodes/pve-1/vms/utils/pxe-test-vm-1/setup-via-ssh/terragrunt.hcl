include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}
include "proxmox_deps" {
  path = find_in_parent_folders("_proxmox_deps.hcl")
}


# Get the deployed IP from the MaaS machine unit.
# Unlike the other VMs (which read IPs from the Proxmox QEMU agent),
# pxe-test-vm-1 is provisioned by MaaS, so its IP comes from the MaaS instance.
dependency "maas_machine" {
  config_path = "${include.root.locals.stack_root}/infra/pwy-home-lab-pkg/_stack/maas/pwy-homelab/machines/pxe-test-vm-1"
  mock_outputs = {
    # Empty list → host="" → ssh-script skips (MaaS machine not yet deployed).
    ip_addresses = []
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "apply", "destroy"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}

terraform {
  source = "${include.root.locals.modules_dir}/null_resource__ssh-script"
}

locals {
  user = try(include.root.locals.unit_params.cloud_init_user, "ubuntu")

  # MaaS-deployed VMs live on the provisioning VLAN (10.0.12.0/24) which is not
  # directly routable from the Terraform host. Route SSH through the MaaS server.
  maas_server_ip = try(include.root.locals.unit_params._maas_server_ip, "")
}

inputs = {
  # Use the first MaaS-assigned IP, or "" (skips ssh-script) if not yet deployed.
  # try() returns "" when ip_addresses is empty (index out of bounds on empty list).
  # dependency.* cannot be referenced in locals in Terragrunt v0.99 run --all.
  host      = try(tolist(dependency.maas_machine.outputs.ip_addresses)[0], "")
  user      = local.user
  ssh_agent = try(include.root.locals.unit_params.ssh_agent, true)

  # Jump through the MaaS server to reach the provisioning VLAN.
  bastion_host = local.maas_server_ip
  bastion_user = "ubuntu"

  script    = <<-SCRIPT
    #!/bin/bash
    set -euo pipefail
    sudo apt-get update -qq
    sudo apt-get install -y qemu-guest-agent
    sudo systemctl enable --now qemu-guest-agent
  SCRIPT
}
