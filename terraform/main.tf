# terraform/main.tf
resource "null_resource" "vagrant_vms" {
  count = var.vm_count

  triggers = {
    vagrantfile_hash = filemd5("${path.module}/Vagrantfile")
    vm_index         = count.index
    vm_count         = var.vm_count
  }

  # Create VM using Vagrant
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      cd ${path.module}
      export VAGRANT_VM_COUNT=${var.vm_count}
      export VAGRANT_VM_NAME=${var.vm_name}
      export VAGRANT_CPUS=${var.cpus}
      export VAGRANT_MEMORY=${replace(var.memory, " mib", "")}
      export VAGRANT_BOX=${var.vagrant_box}
      vagrant up node-${count.index} --provider=virtualbox
    EOT
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      cd ${path.module}
      vagrant destroy -f node-${self.triggers.vm_index} 2>/dev/null || true
    EOT
  }
}

locals {
  # Generate the static IPs: 192.168.56.10, 11, 12, ...
  vm_ips = [for i in range(var.vm_count) : "192.168.56.${10 + i}"]
}

resource "local_file" "ansible_inventory" {
  depends_on = [null_resource.vagrant_vms]

  content = templatefile("${path.module}/inventory.tftpl", {
    ip_addrs = local.vm_ips
    ssh_key  = "~/.vagrant.d/insecure_private_key"
  })

  filename = "${path.module}/../ansible/inventory.ini"
}
