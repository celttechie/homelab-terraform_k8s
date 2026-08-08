terraform {
  required_version = ">= 1.0.0"
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.7.0"
    }
  }
}

# Construct provider URI targeting the Stage 1 Nested Sandbox hypervisor VM
provider "libvirt" {
  uri = "qemu+ssh://${var.nested_hypervisor_user}@${var.nested_hypervisor_ip}/system?keyfile=${pathexpand(var.ssh_private_key_path)}&known_hosts=${pathexpand(var.ssh_known_hosts_path)}"
}

# 1. Base Ubuntu 22.04 LTS Cloud Image stored in Stage 1 default pool
resource "libvirt_volume" "ubuntu_base" {
  name   = "k8s-ubuntu-22.04-base.qcow2"
  pool   = "default"
  source = "https://cloud-images.ubuntu.com/releases/22.04/release/ubuntu-22.04-server-cloudimg-amd64.img"
  format = "qcow2"
}

# 2. Control Plane Disk Volume
resource "libvirt_volume" "k8s_control_plane_disk" {
  name           = "k8s-control-plane-disk.qcow2"
  pool           = "default"
  base_volume_id = libvirt_volume.ubuntu_base.id
  format         = "qcow2"
  size           = 21474836480 # 20 GB
}

# 3. Worker Node Disk Volumes
resource "libvirt_volume" "k8s_worker_disk" {
  count          = var.k8s_worker_count
  name           = "k8s-worker-${format("%02d", count.index + 1)}-disk.qcow2"
  pool           = "default"
  base_volume_id = libvirt_volume.ubuntu_base.id
  format         = "qcow2"
  size           = 21474836480 # 20 GB
}

# 4. Cloud-Init Disk for Control Plane
resource "libvirt_cloudinit_disk" "control_plane_init" {
  name = "k8s-control-plane-init.iso"
  pool = "default"
  user_data = templatefile("${path.module}/templates/cloud_init.cfg", {
    hostname       = "k8s-control-plane"
    ssh_public_key = file(var.ssh_public_key_path)
  })
}

# 5. Cloud-Init Disks for Worker Nodes
resource "libvirt_cloudinit_disk" "worker_init" {
  count = var.k8s_worker_count
  name  = "k8s-worker-${format("%02d", count.index + 1)}-init.iso"
  pool  = "default"
  user_data = templatefile("${path.module}/templates/cloud_init.cfg", {
    hostname       = "k8s-worker-${format("%02d", count.index + 1)}"
    ssh_public_key = file(var.ssh_public_key_path)
  })
}

# 6. Kubernetes Control Plane VM Domain
resource "libvirt_domain" "k8s_control_plane" {
  name       = "k8s-control-plane"
  memory     = var.k8s_control_plane_memory
  vcpu       = var.k8s_control_plane_vcpu
  qemu_agent = true

  cloudinit = libvirt_cloudinit_disk.control_plane_init.id

  network_interface {
    network_name   = "default"
    addresses      = [var.k8s_control_plane_ip]
    wait_for_lease = true
  }

  disk {
    volume_id = libvirt_volume.k8s_control_plane_disk.id
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

# 7. Kubernetes Worker Node VM Domains
resource "libvirt_domain" "k8s_worker" {
  count      = var.k8s_worker_count
  name       = "k8s-worker-${format("%02d", count.index + 1)}"
  memory     = var.k8s_worker_memory
  vcpu       = var.k8s_worker_vcpu
  qemu_agent = true

  cloudinit = libvirt_cloudinit_disk.worker_init[count.index].id

  network_interface {
    network_name   = "default"
    addresses      = [var.k8s_worker_ips[count.index]]
    wait_for_lease = true
  }

  disk {
    volume_id = libvirt_volume.k8s_worker_disk[count.index].id
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
