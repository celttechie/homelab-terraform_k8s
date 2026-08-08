# ADR 006: Nested Workload Architecture and IPAM in Isolated NAT VPC Network

## Status
Accepted

## Context
Provisioning nested virtual machines, Kubernetes nodes, containerized helper services, and standalone test workloads inside the Stage 1 Nested Sandbox hypervisor requires a structured, parameterized IP Address Management (IPAM) strategy and network isolation model. Operating nested workloads directly on the physical hypervisor LAN causes IP address exhaustion, exposes internal cluster/workload communication (etcd, kubelet, pod overlay, storage sync) to external physical LAN devices, and creates tight coupling with physical network infrastructure.

## Decision
We adopt a **Configurable Isolated NAT VPC Architecture with Parameterized IPAM** for all downstream virtual machines, Kubernetes clusters, helper services, and containerized workloads provisioned inside the Stage 1 Nested Sandbox hypervisor (`terraform/environments/02-k8s-cluster`):

1. **Parameterization & Declarative Configuration**:
   - Network subnets, gateway addresses, control plane static IPs, and worker IP pools are fully parameterized as Terraform variables (`var.cluster_network_cidr`, `var.k8s_control_plane_ip`, `var.k8s_worker_ips`) defined in `terraform.tfvars`.
   - Default configurations use the private NAT CIDR `<cluster-subnet-cidr>` (default `<k8s-subnet>.0/24`, managed via libvirt's `default` NAT network on `virbr0`).

2. **Subnet IPAM Allocation Matrix**:
   - To support diverse testing setups (Kubernetes clusters, standalone database VMs, storage nodes, container registries, and ad-hoc ephemeral test instances), the parameterized cluster subnet CIDR (`<k8s-subnet>.0/24`) is partitioned into structured allocation ranges:

| Relative IP / Offset Range | Allocation Purpose | Target Workload / Examples |
| :--- | :--- | :--- |
| `<k8s-subnet>.1` | Gateway / DNS | Hypervisor VM (`virbr0` gateway interface & `dnsmasq`) |
| `<k8s-subnet>.2` - `<k8s-subnet>.9` | Core Infrastructure Services | Local container registry mirror, DNS resolvers, helper proxies |
| `<k8s-subnet>.10` - `<k8s-subnet>.19` | Kubernetes Control Plane Nodes | Single-node or HA Multi-Master Control Plane VMs (`k8s-control-plane-01..03`) |
| `<k8s-subnet>.20` - `<k8s-subnet>.49` | Kubernetes Worker Nodes | Scalable pool of Kubernetes Worker VMs (`k8s-worker-01..30`) |
| `<k8s-subnet>.50` - `<k8s-subnet>.99` | Standalone Helper VMs & Storage | Standalone database VMs, storage test nodes (Ceph/Longhorn), observability VMs (Prometheus, Grafana) |
| `<k8s-subnet>.100` - `<k8s-subnet>.199` | Dynamic DHCP Pool | Ephemeral test VMs, temporary container hosts, ad-hoc developer workloads |
| `<k8s-subnet>.200` - `<k8s-subnet>.254` | Virtual IPs (VIPs) & Ingress | MetalLB LoadBalancer VIP range, HAProxy VIPs, Ingress Controllers |


3. **Remote Control Plane Connectivity & Ingress**:
   - Workstations manage nested hypervisors and Kubernetes clusters remotely via SSH jump-host tunneling through the Stage 1 hypervisor (`<hypervisor-management-ip>`) or API server port forwarding.
   - User-facing application workloads exposed by Kubernetes or standalone VMs use NodePort, Ingress controllers, or HAProxy mapped through designated ports on the Stage 1 hypervisor.

4. **Independent Modular Lifecycle (`02-k8s-cluster` & Future Stages)**:
   - Downstream infrastructure manifests (e.g. `terraform/environments/02-k8s-cluster`) maintain independent state files (`terraform.tfstate`) connecting remotely to the Stage 1 hypervisor libvirt daemon (`qemu+ssh://${var.nested_hypervisor_user}@${var.nested_hypervisor_ip}/system`).

## Consequences
- **Positive:** Parameterized & Flexible—allows teams to customize network subnets, IP pools, and node counts per environment via `terraform.tfvars`.
- **Positive:** Universal applicability—provides structured IPAM for Kubernetes clusters, standalone VMs, storage nodes, helper container services, and ad-hoc test instances.
- **Positive:** Production alignment—matches enterprise cloud VPC patterns by isolating internal workload traffic from administrative host networks.
- **Positive:** Zero physical LAN pollution—prevents physical DHCP IP exhaustion and eliminates broadcast noise on the physical network.
- **Positive:** Reproducible orchestration—predictable IP ranges simplify `kubeadm` cluster initialization, SAN certificate generation, DNS entries, and Ansible/Terraform orchestration.
- **Negative / Trade-off:** External workstation access to internal workload APIs requires SSH jump-host tunneling or port forwarding through `<hypervisor-management-ip>`.
