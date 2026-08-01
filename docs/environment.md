# Infrastructure Environment Specification

This document details the target hypervisor host specifications, control plane architecture, network bridging configuration, and host security posture.

---

## 1. Environment Architecture

| Role | Component | Environment | Details |
| --- | --- | --- | --- |
| **Control Plane** | Workstation Node | Linux / WSL2 | Runs VS Code, Git, Terraform CLI, and `virsh` client |
| **Hypervisor Target** | KVM Host | Linux Host (`<target-server-ip>`) | Runs `libvirtd`, QEMU/KVM, AppArmor, and `br0` network bridge |

---

## 2. Target Network Topology (`br0`)

Virtual machines provisioned by Terraform attach directly to the primary physical network (`<target-network-cidr>`) via an L2 Linux bridge (`br0`), enabling transparent L2/L3 communication across physical and virtual nodes.

### Netplan / NetworkManager Host Configuration
The host's primary physical ethernet interface (`<network-interface>`) operates as a slave interface to `br0`:

* **File Path:** `/etc/netplan/01-br0.yaml` (Permissions: `0600`)

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

---

## 3. Host Security & Access Control Posture

The hypervisor host uses role-based group access and AppArmor process sandboxing to support automated provisioning without requiring root privileges or disabling security controls.

### A. Non-Root API Access (RBAC)
User access to the libvirt Unix domain socket (`qemu:///system`) is granted via system group memberships:
- **`libvirt` Group:** Authorizes domain management and storage pool operations.
- **`kvm` Group:** Grants hardware-accelerated virtualization device access (`/dev/kvm`).

### B. AppArmor Sandbox Confinement
QEMU emulator processes run strictly confined under AppArmor. Access to storage pool volumes (`/var/lib/libvirt/images/**`) is scoped using Ubuntu's standard local inclusion extension:
- **File:** `/etc/apparmor.d/local/abstractions/libvirt-qemu`
- **Rule:** `/var/lib/libvirt/images/** rwk,`
