# ADR 001: Libvirt Remote Management via SSH Transport

## Status
Accepted

## Context
We need Terraform running locally within a WSL Ubuntu environment to provision and manage virtual machines on an existing Linux host (Dell Precision T5600) without exposing unauthenticated network ports or disrupting existing host workloads.

## Decision
We will connect to the remote hypervisor using the `dmacvicar/libvirt` Terraform provider via the `qemu+ssh://` URI scheme. Authentication is secured using SSH key pairs.

## Consequences
- **Positive:** Passwordless key authentication allows unattended Terraform execution.
- **Positive:** Traffic between the local control plane and remote hypervisor is encrypted over SSH.
- **Positive:** Preserves existing host workloads (Docker containers and libvirt VMs) without requiring host re-architecting.
- **Negative / Trade-off:** Requires maintaining valid SSH key pairs across local and remote systems.