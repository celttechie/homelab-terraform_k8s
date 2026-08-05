# ADR 006: Nested Workload Architecture and IPAM in Isolated NAT VPC Network

## Status
Accepted

## Context
Provisioning nested virtual machines, Kubernetes nodes, containerized helper services, and standalone test workloads inside the Stage 1 Nested Sandbox hypervisor requires a structured IP Address Management (IPAM) strategy and network isolation model. Operating nested workloads directly on the physical host's LAN causes IP address exhaustion, exposes internal cluster/workload communication (etcd, kubelet, pod overlay, storage sync) to external LAN devices, and creates tight coupling with physical network infrastructure.

## Decision
We adopt an **Extensible Isolated NAT VPC Architecture with Deterministic IPAM** for all downstream virtual machines, Kubernetes clusters, helper services, and containerized workloads provisioned inside the Stage 1 Nested Sandbox hypervisor (`192.168.122.0/24`):

1. **Private Subnet Scope (`192.168.122.0/24`)**:
   - All nested workloads provisioned inside the Stage 1 hypervisor attach to the internal `default` libvirt NAT network (`virbr0`, gateway `192.168.122.1`).
   - Workload interfaces receive outbound NAT internet access for package updates, container image pulls, and external API communication.

2. **Comprehensive Subnet IPAM Allocation Matrix**:
   - To support diverse testing setups (Kubernetes clusters, standalone database VMs, storage nodes, container registries, and ad-hoc ephemeral test instances), the `192.168.122.0/24` CIDR is partitioned into dedicated IP ranges:

| IP Address Range | Allocation Purpose | Target Workload / Examples |
| :--- | :--- | :--- |
| `192.168.122.1` | Gateway / DNS | Hypervisor VM (`virbr0` gateway interface & dnsmasq) |
| `192.168.122.2` - `192.168.122.9` | Core Infrastructure Services | Local container registry mirror, DNS resolvers, helper proxies |
| `192.168.122.10` - `192.168.122.19` | Kubernetes Control Plane Nodes | Single-node or HA Multi-Master Control Plane VMs (`k8s-control-plane-01..03`) |
| `192.168.122.20` - `192.168.122.49` | Kubernetes Worker Nodes | Scalable pool of Kubernetes Worker VMs (`k8s-worker-01..30`) |
| `192.168.122.50` - `192.168.122.99` | Standalone Helper VMs & Storage | Standalone database VMs, storage test nodes (Ceph/Longhorn), observability VMs (Prometheus, Grafana) |
| `192.168.122.100` - `192.168.122.199` | Dynamic DHCP Pool | Ephemeral test VMs, temporary container hosts, ad-hoc developer workloads |
| `192.168.122.200` - `192.168.122.254` | Virtual IPs (VIPs) & Ingress | MetalLB LoadBalancer VIP range, HAProxy VIPs, Ingress Controllers |

3. **Remote Control Plane Connectivity & Ingress**:
   - Control plane workstations manage nested hypervisors and Kubernetes clusters remotely via SSH tunneling through `sandbox-hypervisor-node` (`192.168.9.x`) or API server port forwarding.
   - User-facing application workloads exposed by Kubernetes or standalone VMs use NodePort, Ingress controllers, or HAProxy mapped through designated ports on the Stage 1 hypervisor.

4. **Independent Modular Lifecycle (`02-k8s-cluster` & Future Stages)**:
   - Downstream infrastructure manifests (e.g. `terraform/environments/02-k8s-cluster`) maintain independent state files (`terraform.tfstate`) connecting remotely to the Stage 1 hypervisor libvirt daemon (`qemu+ssh://ubuntu@<sandbox-vm-ip>/system`).

## Consequences
- **Positive:** Universal applicability—provides structured IPAM for Kubernetes clusters, standalone VMs, storage nodes, helper container services, and ad-hoc test instances.
- **Positive:** Production alignment—matches enterprise cloud VPC patterns by isolating internal workload traffic from administrative host networks.
- **Positive:** Zero physical LAN pollution—prevents physical DHCP IP exhaustion and eliminates broadcast noise on the physical home network.
- **Positive:** Reproducible orchestration—predictable IP ranges simplify `kubeadm` cluster initialization, SAN certificate generation, DNS entries, and Ansible/Terraform orchestration.
- **Negative / Trade-off:** External workstation access to internal workload APIs requires SSH jump-host tunneling or port forwarding through `sandbox-hypervisor-node`.
