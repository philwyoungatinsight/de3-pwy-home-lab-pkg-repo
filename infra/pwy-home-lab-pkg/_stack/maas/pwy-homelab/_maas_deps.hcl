# _maas_deps.hcl — include in every unit under pwy-home-lab-pkg/_stack/maas/pwy-homelab/
#
# Ensures the MaaS API key is current before any MaaS machine resource is
# created, so the MaaS provider always authenticates successfully.
#
# Usage in each maas unit's terragrunt.hcl:
#   include "maas_deps" {
#     path = find_in_parent_folders("_maas_deps.hcl")
#   }

locals {
  _stack_root = dirname(find_in_parent_folders("root.hcl"))
}

dependencies {
  paths = [
    "${local._stack_root}/infra/pwy-home-lab-pkg/_stack/null/pwy-homelab/maas/sync-maas-api-key",
  ]
}
