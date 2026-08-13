# ADR 008: Deterministic SSH Host Key Injection and Strict Host Verification

## Status
Accepted

## Context
During Stage 2 Kubernetes cluster provisioning (`terraform/environments/02-k8s-cluster`), `local-exec` provisioners execute remote configuration commands and file uploads (`scp`/`ssh`) to worker nodes (`k8s-worker-01`) through the Stage 1 hypervisor jump host.

To prevent SSH errors caused by ephemeral SSH host keys changing when guest VMs are destroyed and re-created, provisioners previously suppressed SSH host key validation using `-o UserKnownHostsFile=/dev/null` and `-o StrictHostKeyChecking=no`.

While this solved the immediate provisioning race condition, bypassing host key verification creates security vulnerabilities:
1. **Man-in-the-Middle (MITM) Exposure**: Disabling host key checking leaves automated provisioning connections vulnerable to network interception or IP spoofing within virtual networks.
2. **Security Compliance & Best Practices**: Bypassing SSH verification violates Zero-Trust security principles and pre-commit security standards established in [ADR 002](002-pre-commit-security-and-linting.md).

## Decision
We adopt **Strategy 1: Pre-generate and Inject Host Keys (Deterministic & Preferred)** with **Strict Host Key Verification**:

1. **Pre-Generated SSH Host Keys in Terraform**:
   - Terraform manages Ed25519 host key pairs for each guest VM (`resource "tls_private_key" "k8s_node_host_key"`).
   - Host key generation occurs deterministically during `terraform plan`/`apply` prior to virtual machine creation.

2. **Cloud-Init Host Key Provisioning**:
   - The generated private host key (`tls_private_key.k8s_node_host_key.private_key_pem`) and public key are injected into the cloud-init `user_data` template under the `ssh_keys` block.
   - Cloud-init writes the host key to `/etc/ssh/ssh_host_ed25519_key` with strict permissions (`0600`) and starts `sshd` on first boot.

3. **Managed `known_hosts` File & Strict SSH Verification**:
   - Terraform renders a workspace-isolated `known_hosts` file (`resource "local_file" "known_hosts_entry"`) containing the expected public host key signatures for all cluster nodes and jump hosts.
   - All `ssh`, `scp`, and Ansible provisioner invocations enforce `-o UserKnownHostsFile=${local_file.known_hosts_entry.filename}` and `-o StrictHostKeyChecking=yes`.

## Technical Implementation Specification

```hcl
# 1. Generate the host key deterministically within Terraform
resource "tls_private_key" "k8s_node_host_key" {
  algorithm = "ED25519"
}

# 2. Inject the private host key into Cloud-Init
data "cloudinit_config" "node_config" {
  gzip          = false
  base64_encode = false

  part {
    content_type = "text/cloud-config"
    content      = <<-EOT
      #cloud-config
      ssh_keys:
        ed25519_private: |
          ${indent(10, tls_private_key.k8s_node_host_key.private_key_pem)}
        ed25519_public: ${tls_private_key.k8s_node_host_key.public_key_openssh}
    EOT
  }
}

# 3. Save the known host entry locally BEFORE SSH connections are attempted
resource "local_file" "known_hosts_entry" {
  content         = "${var.k8s_worker_ips[0]} ${trimspace(tls_private_key.k8s_node_host_key.public_key_openssh)}\n"
  filename        = "${path.module}/.ssh/known_hosts"
  file_permission = "0600"
}

# 4. Enforce Strict Verification in Provisioners
# ssh -o UserKnownHostsFile=${local_file.known_hosts_entry.filename} -o StrictHostKeyChecking=yes ...
```

## Security & Architecture Strategy Comparison

| Strategy | Security Level | Operational Effort | Deterministic? | Evaluation Status |
| --- | --- | --- | --- | --- |
| **Bypass (`StrictHostKeyChecking=no`)** | ❌ Vulnerable to MITM | Low | No | **Rejected** (Current insecure state) |
| **Strategy 1: Inject Pre-Generated Keys (Cloud-Init)** | 🔒 High | Medium | **Yes** | **Accepted** (ADR 008 Target Architecture) |
| **Strategy 2: Extract Host Key from Console Output / Metadata** | 🔒 High | Medium | No (Boot-dependent) | **Rejected** (Console logging delays) |
| **Strategy 3: SSH Certificate Authority (SSH CA)** | 🔒 High | High Setup / Low Maint | **Yes** | **Deferred** (Enterprise scale standard) |

## Consequences

- **Positive:** **Complete Zero-Trust Compliance** — Enforces strict host key validation (`StrictHostKeyChecking=yes`) across all automated SSH and SCP operations.
- **Positive:** **Deterministic Re-creation** — VMs retain identical host keys across `terraform destroy` and `terraform apply` cycles, eliminating host key mismatch errors.
- **Positive:** **No Man-in-the-Middle Risk** — Known host signatures are generated and stored before any network connection is attempted.
- **Negative / Trade-off:** Requires storing Terraform-generated host private keys in state (secured via encrypted state storage).
