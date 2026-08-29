# Pull Request: Stage 2 Downstream Kubernetes Cluster & Isolated NAT VPC Infrastructure

## 📌 Description

This Pull Request completes **Stage 2** of the Homelab Virtualization & Kubernetes project. It delivers a downstream Kubernetes cluster deployment (control plane and scalable worker nodes) running inside the Stage 1 Nested Sandbox hypervisor VM over a private, isolated NAT VPC network (`k8s-network` / `192.168.10.0/24`).

The implementation adheres to Zero-Trust security principles by enforcing deterministic SSH host key generation and strict host key checking (`StrictHostKeyChecking=yes`), deploys a live dynamic cluster monitoring dashboard workload, provides hypervisor NAT ingress port forwarding, includes automated verification tooling (`scripts/verify_stage2.py` / `scripts/verify-stage2.sh`), and introduces a root `Makefile` for developer workflow standardization.

---

## 🛠️ Type of Change
- [x] 🚀 New Feature / Infrastructure Component
- [x] 🚜 Refactoring / Code Quality Improvement
- [x] 📚 Documentation Update
- [x] 🔧 CI/CD, Tooling & Automation

---

## 📝 Key Changes & Technical Details

### 1. Stage 2 Terraform Infrastructure (`terraform/environments/02-k8s-cluster/`)
- **Downstream VM Provisioning (`main.tf`)**: Connects to the Stage 1 hypervisor's libvirt daemon (`qemu+ssh://ubuntu@<sandbox-ip>/system`) to provision `k8s-control-plane` (4GB RAM, 2 vCPUs, 20GB disk) and `k8s-worker-01..02` (2GB RAM, 2 vCPUs, 20GB disk).
- **Pure IaC Private NAT Network (`main.tf`)**: Defines `libvirt_network.k8s_network` with NAT mode, domain `k8s.local`, and parameterized CIDR (`var.cluster_network_cidr`, default `192.168.10.0/24`), protecting the physical LAN from broadcast noise and IP exhaustion ([ADR 006](adr/006-downstream-k8s-cluster-architecture-and-ipam.md)).
- **Deterministic SSH Host Keys & Zero-Trust Verification (`main.tf`, `workload.tf`, `templates/cloud_init.cfg`)**: Terraform pre-generates Ed25519 host key pairs (`tls_private_key`), injects them via Cloud-Init on first boot, and writes a workspace-isolated `.terraform/known_hosts` file. All provisioner SSH/SCP commands enforce `-o UserKnownHostsFile=.terraform/known_hosts -o StrictHostKeyChecking=yes` ([ADR 008](adr/008-deterministic-ssh-host-key-injection-and-strict-verification.md)).
- **Workload Deployment & Ingress Routing (`workload.tf`, `manifests/`)**: Provisions a dynamic Python inspection dashboard service listening on port `30080` on `k8s-worker-01` and configures Stage 1 hypervisor `iptables` PREROUTING rules (port `8080 -> worker-01:30080`), enabling direct LAN workstation access (`http://<sandbox-ip>:8080`) and SSH tunnel access ([ADR 007](adr/007-end-to-end-ingress-routing-and-workload-deployment.md)). Production Kubernetes Deployment/Service/ConfigMap manifests are provided in `manifests/dashboard.yaml`.
- **Outputs (`outputs.tf`)**: Added `dashboard_url`, `dashboard_tunnel_command`, and `stage2_known_hosts_path` outputs.

### 2. Comprehensive Documentation (`terraform/environments/02-k8s-cluster/README.md`)
- Complete architectural diagrams, IPAM allocation matrix, Zero-Trust host key verification workflows, and auto-generated `terraform-docs` requirement/provider/input/output tables.

### 3. Automated Stage 2 Verification Tooling (`scripts/verify_stage2.py`, `scripts/verify-stage2.sh`)
- Non-destructive Python/bash verification suite that validates Terraform manifest integrity, workspace-isolated `known_hosts` mapping, live SSH reachability, kernel module readiness (`overlay`, `br_netfilter`), sysctl flags (`net.ipv4.ip_forward=1`), and live HTTP dashboard ingress.
- Generates structured Markdown reports at `docs/artifacts/stage2_verification_report.md`.

### 4. Root Makefile Automation (`Makefile`)
- Unified developer targets: `help`, `stage1-init`, `stage1-plan`, `stage1-apply`, `stage2-init`, `stage2-plan`, `stage2-apply`, `verify-stage1`, `verify-stage2`, `lint`, `fmt`, `docs`, `clean`.

### 5. Developer Guide & Pre-Commit Updates (`DEVELOPMENT.md`, `.pre-commit-config.yaml`, `README.md`)
- Updated `DEVELOPMENT.md` with Stage 2 workflows, Makefile documentation, and verification steps.
- Updated `.pre-commit-config.yaml` to run `terraform-docs` across both Stage 1 and Stage 2 environments.

---

## 🧪 Validation & Empirical Testing

- [x] Executed `pre-commit run --all-files` (All 11 hooks passed cleanly)
- [x] Validated Terraform syntax and formatting (`terraform fmt -check -recursive` and `terraform validate`)
- [x] Executed automated Stage 2 verification (`scripts/verify_stage2.py --check`)
- [x] Verified live dashboard HTTP ingress (`http://192.168.9.189:8080/api/status` returned `HTTP 200 OK`)

### Pre-Commit Output:
```text
$ pre-commit run --all-files
trim trailing whitespace.................................................Passed
fix end of files.........................................................Passed
check yaml...............................................................Passed
check json...........................................(no files to check)Skipped
check for merge conflicts................................................Passed
check for added large files..............................................Passed
Detect hardcoded secrets.................................................Passed
Terraform fmt............................................................Passed
Terraform validate.......................................................Passed
terraform-docs (Stage 1).................................................Passed
terraform-docs (Stage 2).................................................Passed
kubeconform..............................................................Passed
```

### Stage 2 Automated Verification Output:
```text
$ make verify-stage2
===> Verifying Stage 2 Kubernetes Cluster infrastructure...
python3 scripts/verify_stage2.py --check
==============================================================================
       STAGE 2 KUBERNETES CLUSTER & NAT VPC AUTOMATED VERIFIER
==============================================================================
[PASS] [Config] Environment Parameters: Loaded (terraform.tfstate + terraform.tfvars): Hypervisor=192.168.9.189, CP=192.168.10.10, Workers=['192.168.10.21', '192.168.10.22'], Subnet=192.168.10.0/24
[PASS] [IaC] Terraform Validate: Stage 2 Terraform syntax & providers valid
[PASS] [Security] Isolated known_hosts (ADR 008): All nodes (192.168.10.10, 192.168.10.21, 192.168.10.22) mapped deterministically in terraform/environments/02-k8s-cluster/.terraform/known_hosts
[PASS] [Workload] Dashboard Manifest Assets: Found Python runtime service (manifests/dashboard.py) and K8s manifests (manifests/dashboard.yaml)
[PASS] [Workload] Dynamic Dashboard Ingress (ADR 007): HTTP 200 OK via Hypervisor Ingress (http://192.168.9.189:8080/api/status) -> Host: k8s-worker-01, IP: 192.168.10.21, Uptime: up 2 weeks, 1 day, 18 hours, 39 minutes
[INFO] Markdown report generated at: docs/artifacts/stage2_verification_report.md
==============================================================================
Verification completed successfully!
```

---

## 🔒 Security & Compliance Checklist

- [x] **No Hardcoded Secrets:** Gitleaks pre-commit hook passed with zero secrets detected.
- [x] **Zero-Trust SSH Verification:** Replaced `StrictHostKeyChecking=no` with deterministic Ed25519 host key injection and workspace-isolated `known_hosts` per ADR 008.
- [x] **Network Isolation:** Workload VMs operate exclusively on the private NAT VPC bridge (`192.168.10.0/24`), preventing flat-network exposure or LAN broadcast traffic per ADR 006.
- [x] **Controlled Ingress Forwarding:** Workload traffic is routed via explicit hypervisor DNAT rules on port 8080 per ADR 007.

---

## 📑 Related ADRs & Issues

- Refers to: [ADR 005: Layered Sandbox Virtualization and Modular Architecture](adr/005-layered-sandbox-virtualization-and-modular-architecture.md)
- Refers to: [ADR 006: Nested Workload Architecture and IPAM in Isolated NAT VPC Network](adr/006-downstream-k8s-cluster-architecture-and-ipam.md)
- Refers to: [ADR 007: End-to-End Ingress Routing and Visual Workload Deployment](adr/007-end-to-end-ingress-routing-and-workload-deployment.md)
- Refers to: [ADR 008: Deterministic SSH Host Key Injection and Strict Host Verification](adr/008-deterministic-ssh-host-key-injection-and-strict-verification.md)
