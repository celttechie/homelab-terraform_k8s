# Local Development & Control Plane Setup

This document outlines the prerequisite software, host connectivity configuration, and verification steps required to manage remote infrastructure components on a target hypervisor host using Terraform within a Linux-based control plane environment.

---

## 1. System Architecture Overview

| Role | Component | OS / Environment | Details |
| --- | --- | --- | --- |
| **Control Plane** | Workstation Node | Linux / WSL2 (Ubuntu) | Runs VS Code, Git, Terraform CLI, and `virsh` client |
| **Hypervisor Target** | KVM Host | Linux Host (`<target-server-ip>`) | Runs `libvirtd`, container runtimes, and target VMs |

---

## 2. Prerequisites & Local Tooling Installation

All provisioning commands are executed inside the control plane terminal environment.

### Install `libvirt-clients`

To manage remote QEMU/KVM domains over SSH without running a local hypervisor daemon on the control plane:

```bash
sudo apt update && sudo apt install -y libvirt-clients

```

### Install Terraform (Official HashiCorp Repository)

To ensure system stability and avoid container/sandbox restrictions, install Terraform directly from HashiCorp's official APT repository:

```bash
# Install prerequisites
sudo apt update && sudo apt install -y gnupg software-properties-common curl

# Add HashiCorp GPG key
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

# Add official repository
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

# Update & install
sudo apt update && sudo apt install -y terraform

```

---

## 3. Remote Hypervisor Authentication & Connectivity

Authentication to the hypervisor host uses passwordless SSH key authentication over the `qemu+ssh://` transport layer.

### 1. Verify SSH Key Access

Ensure your local SSH public key (`~/.ssh/id_ed25519.pub` or `~/.ssh/id_rsa.pub`) is authorized on the hypervisor host:

```bash
ssh <username>@<target-server-ip>

```

### 2. Validate Libvirt Socket Connection

Test remote domain enumeration from the control plane using `virsh`:

```bash
virsh -c qemu+ssh://<username>@<target-server-ip>/system list --all

```

**Expected Output Example (should show configured VMs and their state):**

```text
 Id   Name           State
-------------------------------
 -    vm-1       running
 -    vm-2       shut off
 -    vm-3       idle

```

---

## 4. Terraform Workspace Initialization

The primary Terraform configuration resides under the `terraform/` directory in the repository.

### Provider Configuration (`terraform/main.tf`)

```hcl
terraform {
  required_version = ">= 1.0.0"
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.7.0"
    }
  }
}

provider "libvirt" {
  uri = "qemu+ssh://<username>@<target-server-ip>/system"
}

```

### Initialize Workspace

Run the initialization step to lock provider plugins:

```bash
cd terraform
terraform init

```

Upon successful execution, Terraform creates `.terraform.lock.hcl` to lock the `dmacvicar/libvirt` provider version.