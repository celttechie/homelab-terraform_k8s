# Homelab Infrastructure & Kubernetes Terraform Provisioner

Automated provisioner for KVM virtual machines on local hypervisor infrastructure using Terraform, `libvirt`, and `cloud-init`.

## 📚 Documentation Architecture

| Guide | Purpose |
| :--- | :--- |
| 🌐 **[Environment Specification](docs/environment.md)** | Target hypervisor host setup, `br0` L2 network bridging, and host AppArmor security posture. |
| 🛠️ **[Developer & Workflow Guide](DEVELOPMENT.md)** | Workstation prerequisite installation (`terraform`, `libvirt-clients`, `pre-commit`), Pull Request workflows, and provisioning commands. |
| 📑 **[Architecture Decision Records](docs/adr/)** | Project design decisions and architectural rationale. |

---

## ⚡ Quick Start

Before running Terraform, ensure all required control plane binaries are installed by following the **[Developer & Workflow Guide](DEVELOPMENT.md#1-local-tooling-prerequisites)**.

```bash
# 1. Install and register pre-commit hooks (See DEVELOPMENT.md)
pre-commit install

# 2. Configure environment variables
cp terraform/terraform.tfvars.example terraform/terraform.tfvars

# 3. Plan and apply infrastructure
cd terraform
terraform init
terraform plan
```
