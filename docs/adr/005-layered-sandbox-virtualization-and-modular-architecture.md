# ADR 005: Layered Sandbox Virtualization and Modular Architecture

## Status
Accepted

## Context
Deploying software workloads or Kubernetes clusters directly onto a physical hypervisor host introduces risks of environment pollution, resource contention, and flat-network security exposure. To reflect production cloud VPC patterns (where workloads run in private isolated subnets) while enabling safe local testing, we require a layered sandbox architecture.

## Decision
We adopt a multi-stage modular environment structure with **Layered Sandbox Virtualization**:
1. **Decoupled Environment Execution (`terraform/environments/`)**: Infrastructure deployments are separated into sequential execution stages (`01-nested-sandbox`, `02-k8s-cluster`), each containing independent state files (`terraform.tfstate`) and stage-specific variable configurations (`terraform.tfvars`).
2. **Stage 1 Nested Sandbox (`01-nested-sandbox`)**: Provisions a self-contained "Sandbox Hypervisor VM" (`sandbox-hypervisor-node`) on the physical host using `host-passthrough` CPU mode (Nested KVM). Cloud-init configures KVM dependencies, user groups (`libvirt`, `kvm`), storage pools, AppArmor rules, and libvirtd on first boot.
3. **Stage 2 Production-Like Private VPC (`02-k8s-cluster`)**: Connects to the nested sandbox hypervisor's libvirt daemon (`qemu+ssh://ubuntu@<sandbox-vm-ip>/system`) to provision downstream Kubernetes nodes inside an isolated private NAT subnet (`default` / `virbr0` / `192.168.122.0/24`), creating a production-like network perimeter.

## Consequences
- **Positive:** Production alignment—workloads run in isolated private subnets with controlled ingress, matching enterprise cloud VPC topologies.
- **Positive:** Complete isolation—contributors and automated pipelines can test downstream infrastructure without risking physical host stability.
- **Positive:** Modular architecture allows testing each deployment stage (`01-nested-sandbox` -> `02-k8s-cluster`) independently.
- **Negative / Trade-off:** Nested virtualization incurs a minor CPU/RAM overhead compared to bare-metal execution.
