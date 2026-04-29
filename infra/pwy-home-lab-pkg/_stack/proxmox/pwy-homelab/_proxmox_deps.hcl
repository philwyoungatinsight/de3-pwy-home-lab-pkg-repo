# _proxmox_deps.hcl — include in every unit under pwy-home-lab-pkg/_stack/proxmox/pwy-homelab/
#
# Ensures Proxmox hosts are configured before any VM resource is
# created or destroyed.

locals {
  _stack_root = dirname(find_in_parent_folders("root.hcl"))
}

dependencies {
  paths = [
    "${local._stack_root}/infra/pwy-home-lab-pkg/_stack/null/pwy-homelab/proxmox/configure-proxmox",
  ]
}
