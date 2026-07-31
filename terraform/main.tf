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
  uri = "qemu+ssh://${var.libvirt_user}@${var.libvirt_host_ip}/system"
}