# ADR 009: Automated K3s Distribution Bootstrapping and Dynamic Kubeconfig Management

## Status
Accepted

## Context
Following the provisioning of Stage 1 (Nested Sandbox Hypervisor) and Stage 2 (Downstream Virtual Machines inside isolated NAT network `192.168.2.0/24`), operators require an automated, repeatable, and secure mechanism to bootstrap a lightweight, production-grade Kubernetes distribution across the provisioned virtual machines.

Additionally, operators require administrative access via `kubectl` and Helm directly from workstation developer environments without exposing Kubernetes API endpoints to untrusted physical LAN networks or compromising Zero-Trust security postures.

## Decision
We adopt **K3s as the Downstream Kubernetes Distribution** managed via a decoupled Terraform execution stage (`terraform/environments/03-k8s-bootstrap`):

1. **Automated Control Plane & Worker Bootstrapping**:
   - The control plane node (`192.168.2.10`) is initialized via K3s server with parameterized Pod/Service CIDRs (`10.42.0.0/16`, `10.43.0.0/16`), cluster DNS (`10.43.0.10`), and TLS SAN entries including the node static IP, nested hypervisor IP, and `127.0.0.1`.
   - Worker nodes (`192.168.2.20`, `192.168.2.21`) join the cluster automatically using a cryptographically random cluster token (`random_password`).

2. **Strict Host Key & Jump Host Enforcement (Zero-Trust)**:
   - All bootstrap commands execute over SSH jump-host connections through the Stage 1 hypervisor enforcing workspace-isolated `known_hosts` (`../02-k8s-cluster/.terraform/known_hosts`) per ADR 008.

3. **Dynamic Kubeconfig Extraction & Workstation Proxying**:
   - The cluster kubeconfig (`/etc/rancher/k3s/k3s.yaml`) is extracted directly to the workspace as `kubeconfig.yaml` with server addresses configured for secure local SSH port forwarding (`ssh -L 6443:192.168.2.10:6443 ubuntu@<hypervisor-ip>`).

4. **Addon Management**:
   - Standardizes built-in Local Path Storage Provisioner for persistent volumes while disabling default Traefik to allow modular ingress controllers (e.g. Istio / UDS Core).

## Consequences
- **Positive:** Fully automated Kubernetes bootstrap without manual node intervention.
- **Positive:** Secure, isolated cluster control plane inaccessible from external LAN without cryptographic jump host authentication.
- **Positive:** Immediate compatibility with downstream workload orchestrators like Zarf and UDS.
