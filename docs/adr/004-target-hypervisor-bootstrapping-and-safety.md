# ADR 004: Target Hypervisor Bootstrapping and Safety Posture

## Status
Accepted

## Context
Preparing a Linux hypervisor host to receive Terraform `libvirt` applications requires installing KVM dependencies, configuring storage pool permissions, establishing non-root socket access, setting up AppArmor process sandboxing, and verifying active hypervisor networks. Executing automated provisioning requires idempotent, repeatable host setup and audit mechanisms that conform to production infrastructure standards.

## Decision
We adopt an idempotent, unified host bootstrap script (`scripts/bootstrap-host.sh`) designed around production hypervisor standards for both bare-metal hypervisors (Stage 0) and virtualized hypervisors (Stage 1):
1. **Dual-Target Audit & Remediation**: Operates on both physical hosts and nested VM hypervisors as a single source of truth for hypervisor prerequisites. On physical hosts, it installs dependencies and configures RBAC/AppArmor; on VM hypervisors, cloud-init handles native first-boot setup and embeds the script into `/usr/local/bin/bootstrap-host.sh`, running it in `--check` mode to log a first-boot audit report to `/var/log/bootstrap-audit.log`.
2. **Read-Only Audit Mode (`--check` / `--dry-run`)**: Performs a non-destructive audit of installed packages, user group memberships (`libvirt`, `kvm`), storage pool permissions (`2775 libvirt-qemu:kvm`), AppArmor rules, and libvirt network definitions without modifying system state.
3. **RBAC & Security Posture**: Enforces non-root socket access via `libvirt` and `kvm` system groups and configures AppArmor process sandboxing (`/var/lib/libvirt/images/** rwk,`).
4. **Automated Libvirt Network Verification**: Automatically verifies and activates default libvirt networks (`default` NAT and `host-bridge` if present on physical hypervisors).
5. **Production Network Decoupling**: Hypervisors maintain a clean management interface for control plane communication, while downstream workloads operate in isolated private subnets.


## Consequences
- **Positive:** Zero-dependency host preparation—no complex configuration management frameworks required for host onboarding.
- **Positive:** Safe remote audit capability—contributors can verify host readiness via `--check` without risk of system modification.
- **Positive:** Production alignment—matches enterprise cloud patterns by keeping hypervisor management decoupled from downstream workload subnets.
