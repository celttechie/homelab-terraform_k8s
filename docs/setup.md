# Infrastructure Setup & Deployment Guide

## Overview
This document outlines the prerequisite software, host connectivity configuration, and verification steps required to manage remote infrastructure components on a target KVM hypervisor host using Terraform within a Linux-based control plane environment. VMs attach directly to the primary LAN via an L2 bridge interface, enabling transparent L2/L3 visibility across physical and virtual nodes.

---

## 1. System Architecture Overview

| Role | Component | Environment | Details |
| --- | --- | --- | --- |
| **Control Plane** | Workstation Node | Linux / WSL2 | Runs VS Code, Git, Terraform CLI, and `virsh` client |
| **Hypervisor Target** | KVM Host | Linux Host (`<target-server-ip>`) | Runs `libvirtd`, QEMU/KVM, AppArmor, and `br0` network bridge |

---

## 2. Host Prerequisites & Networking Setup

Before running Terraform, the host server (`<target-kvm-host>`) must have its physical interface configured as part of a Linux bridge (`br0`) and registered within `libvirt`.

### Netplan / NetworkManager Configuration
Configure the host primary ethernet interface (`<network-interface>`) to operate as a slave to `br0`:

* **File:** `/etc/netplan/01-br0.yaml` (Permissions: `0600`)

```yaml
network:
  version: 2
  renderer: NetworkManager
  ethernets:
    <network-interface>:
      match:
        macaddress: "<mac-address>"
      dhcp4: no
      dhcp6: no

  bridges:
    br0:
      interfaces: [<network-interface>]
      dhcp4: yes
      dhcp6: no
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4
      parameters:
        stp: false
        forward-delay: 0
```

Apply the netplan configuration on the host:
```bash
sudo netplan apply
```

---

## 3. Host Security & Permissions Posture

To allow Terraform to provision VMs remotely under a non-root account (`<username>`) while preserving server security posture:

### A. Non-Root Group Membership (RBAC)
Grant socket access to `qemu:///system` without requiring elevated `sudo` privileges:
```bash
sudo usermod -aG libvirt,kvm <username>
```

### B. AppArmor Sandbox Confinement
Scope QEMU process access to the storage pool using Ubuntu's standard local abstraction file:
```bash
sudo mkdir -p /etc/apparmor.d/local/abstractions
echo '/var/lib/libvirt/images/** rwk,' | sudo tee /etc/apparmor.d/local/abstractions/libvirt-qemu
sudo systemctl reload apparmor
```

---

## 4. Control Plane Prerequisites & SSH Setup

### A. Local Tooling Installation
Install `libvirt-clients` and `terraform` on the workstation:
```bash
sudo apt update && sudo apt install -y libvirt-clients terraform
```

### B. Remote Hypervisor Connectivity
Test passwordless SSH and remote domain enumeration over `qemu+ssh`:
```bash
virsh -c "qemu+ssh://<username>@<target-server-ip>/system?keyfile=~/.ssh/id_ed25519" list --all
```

---

## 5. Terraform Workspace Initialization

The primary Terraform configuration resides under the `terraform/` directory.

### Provider Configuration (`terraform/main.tf`)
Uses explicit private key authentication and enforces strict host key verification against `known_hosts`:

```hcl
provider "libvirt" {
  uri = "qemu+ssh://${var.libvirt_user}@${var.libvirt_host_ip}/system?keyfile=${pathexpand(var.ssh_private_key_path)}&known_hosts=${pathexpand(var.ssh_known_hosts_path)}"
}
```

### Initialize and Plan Workspace
```bash
cd terraform
terraform init
terraform plan
```
