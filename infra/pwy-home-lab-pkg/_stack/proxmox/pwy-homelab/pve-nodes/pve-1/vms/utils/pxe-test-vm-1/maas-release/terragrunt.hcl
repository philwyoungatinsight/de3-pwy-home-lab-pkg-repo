include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}
include "proxmox_deps" {
  path = find_in_parent_folders("_proxmox_deps.hcl")
}

# Parent VM — provides vm_id and vm_name.
# When the VM is recreated (new vm_id), the trigger on null_resource.release
# changes, causing this unit to destroy+recreate, which fires the release script
# before the new VM is brought up.
dependency "vm" {
  config_path = ".."
  mock_outputs = {
    vm_id   = 0
    vm_name = "pxe-test-vm-1"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "apply", "destroy"]
}

terraform {
  source = "${include.root.locals.modules_dir}/maas_machine_release"
}

inputs = {
  hostname       = dependency.vm.outputs.vm_name
  maas_server_ip = try(include.root.locals.unit_params._maas_server_ip, "")
  vm_id          = tostring(dependency.vm.outputs.vm_id)
}
