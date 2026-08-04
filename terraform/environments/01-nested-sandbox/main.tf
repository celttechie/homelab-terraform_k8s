terraform {
  required_version = ">= 1.0.0"
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.7.0"
    }
  }
}

# Construct provider URI using declared variables
provider "libvirt" {
  uri = "qemu+ssh://${var.libvirt_user}@${var.libvirt_host_ip}/system?keyfile=${pathexpand(var.ssh_private_key_path)}&known_hosts=${pathexpand(var.ssh_known_hosts_path)}"
}

# 1. Fetch official Ubuntu 22.04 LTS Cloud Image
resource "libvirt_volume" "ubuntu_base" {
  name   = "sandbox-ubuntu-22.04-base.qcow2"
  pool   = "default"
  source = "https://cloud-images.ubuntu.com/releases/22.04/release/ubuntu-22.04-server-cloudimg-amd64.img"
  format = "qcow2"
}

# 2. Create copy-on-write disk volume for the Nested Sandbox VM
resource "libvirt_volume" "sandbox_hypervisor_disk" {
  name           = "sandbox-hypervisor-disk.qcow2"
  pool           = "default"
  base_volume_id = libvirt_volume.ubuntu_base.id
  format         = "qcow2"
  size           = 42949672960 # 40 GB for nested workloads
}

# 3. Inject Cloud-Init configuration
resource "libvirt_cloudinit_disk" "commoninit" {
  name = "sandbox-commoninit.iso"
  pool = "default"
  user_data = templatefile("${path.module}/templates/cloud_init.cfg", {
    hostname         = "sandbox-hypervisor-node"
    ssh_public_key   = file(var.ssh_public_key_path)
    bootstrap_script = file("${path.module}/../../../scripts/bootstrap-host.sh")
  })
}

# 4. Define Nested Sandbox Hypervisor Domain
resource "libvirt_domain" "sandbox_hypervisor" {
  name   = "sandbox-hypervisor-node"
  memory = var.sandbox_memory
  vcpu   = var.sandbox_vcpu

  # Expose physical host CPU virtualization extensions (/dev/kvm) into guest VM
  cpu {
    mode = "host-passthrough"
  }

  cloudinit = libvirt_cloudinit_disk.commoninit.id

  # Tell libvirt to communicate with qemu-guest-agent inside the VM
  qemu_agent = true

  network_interface {
    network_name   = var.libvirt_network_name
    wait_for_lease = true
  }



  disk {
    volume_id = libvirt_volume.sandbox_hypervisor_disk.id
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
