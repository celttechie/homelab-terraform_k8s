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
# 1. Audit target hypervisor host (non-destructive)
ssh <username>@<target-server-ip> 'bash -s -- --check <username>' < scripts/bootstrap-host.sh

# 2. Install and register pre-commit hooks (See DEVELOPMENT.md)
pre-commit install

# 3. Stage 1: Deploy Nested Sandbox Hypervisor
make stage1-init
make stage1-plan
make stage1-apply

# 4. Stage 2: Deploy Downstream K8s Cluster & Ingress Workload
make stage2-init
make stage2-plan
make stage2-apply

# 5. Automated Verification
make verify-stage2
```
