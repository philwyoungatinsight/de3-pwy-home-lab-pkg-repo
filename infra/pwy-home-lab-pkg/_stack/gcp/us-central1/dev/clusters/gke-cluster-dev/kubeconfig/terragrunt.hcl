include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  config_files = [
    "${include.root.locals.stack_root}/infra/pwy-home-lab-pkg/_config/pwy-home-lab-pkg.yaml",
  ]
  config_hash = sha256(join("", [for f in local.config_files : filesha256(f)]))
}

# Hard dep: the GKE cluster must exist before fetching credentials.
dependency "cluster" {
  config_path = "../"
  mock_outputs = {
    cluster_name   = "mock-cluster"
    node_pool_name = "primary"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

terraform {
  # unit_type: gke_kubeconfig
  source = "${include.root.locals.modules_dir}/null_resource__run-script"
}

inputs = {
  # Re-runs whenever the cluster identity or config changes.
  trigger    = "${local.config_hash}-${dependency.cluster.outputs.cluster_name}"
  script_dir = "${include.root.locals._tg_scripts}/gke/kubeconfig"
}
