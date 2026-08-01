terraform {
  required_version = ">= 1.0.0"
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.7.0"
    }
  }
}

# Construct URI dynamically using declared variables
provider "libvirt" {
  uri = "qemu+ssh://${var.libvirt_user}@${var.libvirt_host_ip}/system?keyfile=${pathexpand(var.ssh_private_key_path)}&known_hosts=${pathexpand(var.ssh_known_hosts_path)}"
}

# 1. Fetch official Ubuntu 22.04 LTS Cloud Image
resource "libvirt_volume" "ubuntu_base" {
  name   = "ubuntu-22.04-base.qcow2"
  pool   = "default"
  source = "https://cloud-images.ubuntu.com/releases/22.04/release/ubuntu-22.04-server-cloudimg-amd64.img"
  format = "qcow2"
}

# 2. Create copy-on-write disk volume for test VM
resource "libvirt_volume" "test_node_disk" {
  name           = "test-node-disk.qcow2"
  pool           = "default"
  base_volume_id = libvirt_volume.ubuntu_base.id
  format         = "qcow2"
  size           = 10737418240 # 10 GB
}

# 3. Inject Cloud-Init configuration
resource "libvirt_cloudinit_disk" "commoninit" {
  name = "commoninit.iso"
  pool = "default"
  user_data = templatefile("${path.module}/templates/cloud_init.cfg", {
    hostname       = "k8s-test-node"
    ssh_public_key = file(var.ssh_public_key_path)
  })
}

# 4. Define Virtual Machine Domain
resource "libvirt_domain" "test_vm" {
  name   = "k8s-test-node"
  memory = "2048"
  vcpu   = 2

  cloudinit = libvirt_cloudinit_disk.commoninit.id

  # Tell libvirt to communicate with qemu-guest-agent inside the VM
  qemu_agent = true

  network_interface {
    network_name   = "host-bridge"
    wait_for_lease = true
  }

  disk {
    volume_id = libvirt_volume.test_node_disk.id
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}

# 5. Output VM IP address once provisioned
output "ip_address" {
  value       = libvirt_domain.test_vm.network_interface[0].addresses
  description = "The IP address of the provisioned VM"
}
