# Developer & Workflow Guide

This guide outlines local workspace setup, pre-commit hook enforcement, secret scanning, Pull Request standards, and infrastructure deployment workflows for contributors.

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
- **Terraform Docs (`terraform-docs`)**: Automatically generates module documentation tables in `README.md`.
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

## 3. Stage 1 Terraform Provisioning Workflow (`01-nested-sandbox`)

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
cd terraform/environments/01-nested-sandbox

# Initialize provider plugins
terraform init

# Generate execution plan
terraform plan

# Apply infrastructure changes
terraform apply
```

---

## 4. Git & Pull Request Workflow

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
   Ensure all 10 active pre-commit hooks pass cleanly before staging files.

3. **Open a Pull Request Using the PR Template:**
   When submitting a Pull Request on GitHub, fill out the standard template automatically loaded from [`.github/PULL_REQUEST_TEMPLATE.md`](.github/PULL_REQUEST_TEMPLATE.md):
   - **Type of Change:** Select the change category (Feature, Bug Fix, Docs, CI/CD).
   - **Key Changes & Technical Details:** Summarize key modifications and resource definitions.
   - **Validation & Empirical Testing:** Paste terminal output proving `pre-commit run --all-files` passed cleanly.
   - **Security Checklist:** Confirm no credentials/keys were committed (`gitleaks` passed).
   - **Related ADRs:** Reference any associated Architecture Decision Records (e.g. `docs/adr/002-pre-commit-security-and-linting.md`).

---

## 5. Security & Secret Prevention

- **Never commit `.tfvars` files containing credentials.** (Enforced via `.gitignore`).
- **Always verify SSH Host Keys.** Provider URIs use strict `known_hosts` verification.
- **Run `pre-commit run --all-files` before creating Pull Requests.**
