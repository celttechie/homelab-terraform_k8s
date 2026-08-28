# Developer & Workflow Guide

This guide outlines local workspace setup, pre-commit hook enforcement, secret scanning, Pull Request standards, and infrastructure deployment workflows for contributors across Stages 1, 2, and 3.

---

## 1. Local Tooling Prerequisites

Ensure the following tooling is installed on your control plane workstation:

- **Terraform CLI** (`>= 1.0.0`)
- **Libvirt Client Tools** (`libvirt-clients` / `virsh`)
- **Pre-Commit Framework** (`pre-commit`)

```bash
# On Debian/Ubuntu / WSL2:
sudo apt update && sudo apt install -y terraform libvirt-clients pre-commit
```

### Unified Hypervisor Audit & Remediation (`scripts/bootstrap-host.sh`)

The repository includes a unified, idempotent host bootstrap script (`scripts/bootstrap-host.sh`) designed to audit (`--check`) and auto-remediate/fix hypervisor requirements across both **bare-metal hypervisors (Stage 0)** and **nested VM hypervisors (Stage 1)**.

#### Architecture: Cloud-Init vs. Bootstrap Script
* **Cloud-Init (First-Boot Native Setup)**: Handles fast, declarative image initialization (package installation, user SSH keys, initial storage directory creation, and AppArmor rules) during early OS boot at native speed.
* **Bootstrap Script (Unified Audit & Remediation)**: Embedded at `/usr/local/bin/bootstrap-host.sh` on both physical and virtual hypervisors. On first boot, cloud-init invokes this script in `--check` mode to log a complete verification audit to `/var/log/bootstrap-audit.log`. It can be run manually at any time to verify posture or auto-fix missing dependencies.

#### 1. Read-Only Audit Mode (`--check` / `--dry-run`)
Performs a non-destructive audit of required KVM packages, `libvirt`/`kvm` group access, storage pool permissions (`2775`), AppArmor rules, and active network posture without modifying files:
```bash
# Run read-only audit remotely over SSH (works on physical or VM hypervisors):
ssh <username>@<target-server-ip> 'bash -s -- --check <username>' < scripts/bootstrap-host.sh

# OR run locally on hypervisor:
./scripts/bootstrap-host.sh --check <username>
```

#### 2. Auto-Remediation & Host Preparation (Apply Mode)
Installs missing KVM packages, configures non-root `libvirt`/`kvm` group access, sets up `/var/lib/libvirt/images` storage pool permissions, applies AppArmor sandbox rules, and activates `libvirtd` and default networks:
```bash
sudo ./scripts/bootstrap-host.sh <username>
```

---

## 2. Pre-Commit Hooks & Quality Assurance

This repository uses [`pre-commit`](https://pre-commit.com/) to automatically enforce code formatting, validate Terraform manifests, and scan for hardcoded secrets before code is committed.

### Hook Configuration Overview (`.pre-commit-config.yaml`)

- **Gitleaks (`gitleaks`)**: Scans all staged files for private keys, tokens, and hardcoded credentials.
- **Terraform Format (`terraform_fmt`)**: Ensures consistent canonical formatting across all `.tf` files.
- **Terraform Validation (`terraform_validate`)**: Validates manifest syntax and provider configuration integrity.
- **Terraform Docs (`terraform-docs`)**: Automatically generates module documentation tables in `README.md` for Stages 1, 2, and 3.
- **Kubernetes Validation (`kubeconform`)**: Validates Kubernetes YAML manifests against official schemas.
- **General Hygiene**: Checks YAML syntax, prevents trailing whitespace, and blocks oversized files.

### Setup Instructions

1. **Install hooks into your local `.git` folder:**
   ```bash
   pre-commit install
   ```

2. **Run pre-commit hooks manually against all files:**
   ```bash
   pre-commit run --all-files
   ```

---

## 3. Makefile Developer Workflow

For developer convenience and unified CI/CD execution, a root `Makefile` provides standardized targets:

```bash
# View all available targets and descriptions
make help

# Stage 1 Workflow (Nested Sandbox Hypervisor)
make stage1-init
make stage1-plan
make stage1-apply
make verify-stage1

# Stage 2 Workflow (Downstream K8s Cluster & NAT VPC)
make stage2-init
make stage2-plan
make stage2-apply
make verify-stage2

# Stage 3 Workflow (Automated K3s Distribution Bootstrap)
make stage3-init
make stage3-plan
make stage3-apply
make verify-stage3

# Quality & Hygiene Gates
make lint
make fmt
make docs
make clean
```

---

## 4. Stage 1 Terraform Provisioning Workflow (`01-nested-sandbox`)

### Workspace Variables (`terraform/environments/01-nested-sandbox/terraform.tfvars`)

Navigate to the Stage 1 environment workspace, copy the example configuration file, and customize variables for your control plane environment:

```bash
cd terraform/environments/01-nested-sandbox
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
libvirt_host_ip = "<target-server-ip>"
libvirt_user    = "<username>"
sandbox_memory  = "4096"
sandbox_vcpu    = 2
```

### Execution Steps

```bash
# Via Makefile (from repository root):
make stage1-init
make stage1-plan
make stage1-apply

# OR via Terraform CLI directly:
cd terraform/environments/01-nested-sandbox
terraform init
terraform plan
terraform apply
```

---

## 5. Stage 2 Downstream K8s Cluster Provisioning (`02-k8s-cluster`)

### Workspace Variables (`terraform/environments/02-k8s-cluster/terraform.tfvars`)

After Stage 1 is applied, navigate to the Stage 2 environment workspace, copy the example configuration file, and set `nested_hypervisor_ip` to the Stage 1 `sandbox_ip_address` output:

```bash
cd terraform/environments/02-k8s-cluster
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
nested_hypervisor_ip   = "<sandbox-vm-ip>" # e.g. IP from Stage 1 sandbox_ip_address output
nested_hypervisor_user = "ubuntu"
cluster_network_cidr   = "192.168.10.0/24"
k8s_control_plane_ip   = "192.168.10.10"
k8s_worker_count       = 2
k8s_worker_ips         = ["192.168.10.21", "192.168.10.22"]
```

### Execution Steps

```bash
# Via Makefile (from repository root):
make stage2-init
make stage2-plan
make stage2-apply

# OR via Terraform CLI directly:
cd terraform/environments/02-k8s-cluster
terraform init
terraform plan
terraform apply
```

### Automated Stage 2 Health Verification (`scripts/verify-stage2.sh`)

After provisioning Stage 2, run the non-destructive verification tool to validate SSH connectivity, node readiness, deterministic host keys, and live dashboard ingress:

```bash
# Run verification via Makefile:
make verify-stage2

# OR directly with custom flags:
./scripts/verify-stage2.sh --check
./scripts/verify-stage2.sh --skip-live  # Static validation only
```

Verification findings and ADR compliance status are automatically recorded in `docs/artifacts/stage2_verification_report.md`.

---

## 6. Stage 3 Automated K3s Distribution Bootstrapping (`03-k8s-bootstrap`)

### Workspace Variables (`terraform/environments/03-k8s-bootstrap/terraform.tfvars`)

After Stage 2 is applied, navigate to the Stage 3 environment workspace, copy the example configuration file, and customize parameters:

```bash
cd terraform/environments/03-k8s-bootstrap
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
nested_hypervisor_ip   = "192.168.9.189" # Stage 1 sandbox VM IP
nested_hypervisor_user = "ubuntu"
ssh_private_key_path   = "~/.ssh/id_ed25519"
ssh_known_hosts_path   = "~/.ssh/known_hosts"
stage2_known_hosts_path = "../02-k8s-cluster/.terraform/known_hosts"

k8s_control_plane_ip   = "192.168.10.10"
k8s_worker_ips         = ["192.168.10.21", "192.168.10.22"]
k3s_version            = "v1.28.8+k3s1"

cluster_cidr           = "10.42.0.0/16"
service_cidr           = "10.43.0.0/16"
cluster_dns            = "10.43.0.10"
```

### Execution Steps

```bash
# Via Makefile (from repository root):
make stage3-init
make stage3-plan
make stage3-apply

# OR via Terraform CLI directly:
cd terraform/environments/03-k8s-bootstrap
terraform init
terraform plan
terraform apply
```

### Automated Stage 3 Verification (`scripts/verify-stage3.sh`)

After bootstrapping Stage 3, run the automated verification suite to validate control plane status, worker registration, core system pods, and workstation kubeconfig:

```bash
# Run verification via Makefile:
make verify-stage3

# OR directly with custom flags:
./scripts/verify-stage3.sh --check
./scripts/verify-stage3.sh --skip-live  # Static validation only
```

Verification findings are recorded in `docs/artifacts/stage3_verification_report.md`.

### Workstation Cluster Access (`kubectl`)

Stage 3 extracts a ready-to-use `kubeconfig.yaml` configured for SSH tunnel forwarding:

```bash
# Step 1: Open SSH local port forwarding tunnel in a separate terminal:
ssh -N -L 6443:192.168.10.10:6443 ubuntu@<nested_hypervisor_ip>

# Step 2: Use the generated kubeconfig:
export KUBECONFIG=terraform/environments/03-k8s-bootstrap/kubeconfig.yaml
kubectl get nodes -o wide
kubectl get pods -A
```

---

## 7. Git & Pull Request Workflow

All contributions must follow an atomic feature branching strategy and conform to standard repository Pull Request governance.

### Step-by-Step Feature Workflow

1. **Create an Atomic Feature Branch:**
   ```bash
   git checkout main
   git pull origin main
   git checkout -b feature/<feature-name>
   ```

2. **Run Pre-Commit Verification Before Committing:**
   ```bash
   pre-commit run --all-files
   ```
   Ensure all active pre-commit hooks pass cleanly before staging files.

3. **Open a Pull Request Using the PR Template:**
   When submitting a Pull Request on GitHub, fill out the standard template automatically loaded from [`.github/PULL_REQUEST_TEMPLATE.md`](.github/PULL_REQUEST_TEMPLATE.md):
   - **Type of Change:** Select the change category (Feature, Bug Fix, Docs, CI/CD).
   - **Key Changes & Technical Details:** Summarize key modifications and resource definitions.
   - **Validation & Empirical Testing:** Paste terminal output proving `pre-commit run --all-files` passed cleanly.
   - **Security Checklist:** Confirm no credentials/keys were committed (`gitleaks` passed).
   - **Related ADRs:** Reference any associated Architecture Decision Records (e.g. `docs/adr/009-automated-k3s-distribution-bootstrap-and-kubeconfig-management.md`).

---

## 8. Security & Secret Prevention

- **Never commit `.tfvars` files containing credentials.** (Enforced via `.gitignore`).
- **Always verify SSH Host Keys.** Provider URIs and jump connections use strict `known_hosts` verification (ADR 008).
- **Run `pre-commit run --all-files` before creating Pull Requests.**
