include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${include.root.locals.modules_dir}/null_resource__run-script"
}

locals {
  # Re-run when any config file that affects inventory hosts changes.
  config_files = [
    "${include.root.locals.stack_root}/infra/proxmox-pkg/_config/proxmox-pkg.yaml",
    "${include.root.locals.stack_root}/infra/maas-pkg/_config/maas-pkg.yaml",
    "${include.root.locals._tg_scripts}/local/update-ssh-config/run",
  ]
  config_hash = sha256(join("", [for f in local.config_files : filesha256(f)]))
}

inputs = {
  trigger    = local.config_hash
  script_dir = "${include.root.locals._tg_scripts}/local/update-ssh-config"
}
