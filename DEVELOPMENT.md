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

## 3. Terraform Provisioning Workflow

### Workspace Variables (`terraform/terraform.tfvars`)

Copy the example configuration file and customize variables for your control plane environment:

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Edit `terraform/terraform.tfvars`:
```hcl
libvirt_host_ip = "<target-server-ip>"
libvirt_user    = "<username>"
```

### Execution Steps

```bash
cd terraform

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
