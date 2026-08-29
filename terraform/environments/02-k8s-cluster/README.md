# Stage 2: Downstream Kubernetes Cluster & Isolated NAT VPC

This Terraform module deploys a downstream Kubernetes cluster (control plane and scalable worker nodes) onto the Stage 1 Nested Sandbox hypervisor VM using pure Infrastructure as Code (IaC), deterministic SSH host key injection, and isolated NAT VPC networking.

---

## 🏛️ Architecture Overview (ADR 006)

Stage 2 provisions guest virtual machines inside the Stage 1 Nested Sandbox hypervisor (`sandbox-hypervisor-node`). Rather than attaching directly to the physical LAN, Stage 2 instantiates a dedicated, isolated NAT VPC network (`k8s-network` / `192.168.10.0/24` or user-defined CIDR).

```
+-------------------------------------------------------------------------------+
| Physical Hypervisor Host (Stage 0: 192.168.9.110)                             |
|                                                                               |
|  +-------------------------------------------------------------------------+  |
|  | Stage 1 Nested Sandbox Hypervisor VM (192.168.9.189)                    |  |
|  |                                                                         |  |
|  |  +-------------------------------------------------------------------+  |  |
|  |  | Stage 2 Isolated NAT VPC (k8s-network: 192.168.10.0/24)           |  |  |
|  |  |                                                                   |  |  |
|  |  |  +-----------------------+     +-------------------------------+  |  |  |
|  |  |  | k8s-control-plane     |     | k8s-worker-01 (192.168.10.21) |  |  |  |
|  |  |  | (192.168.10.10)       |     | - Port 30080 Dashboard        |  |  |  |
|  |  |  +-----------------------+     +-------------------------------+  |  |  |
|  |  |                                                                   |  |  |
|  |  |                                +-------------------------------+  |  |  |
|  |  |                                | k8s-worker-02 (192.168.10.22) |  |  |  |
|  |  |                                +-------------------------------+  |  |  |
|  |  +-------------------------------------------------------------------+  |  |
|  |        ^ Hypervisor NAT Ingress Forwarding (8080 -> 192.168.10.21:30080)|  |
|  +--------|----------------------------------------------------------------+  |
|           |                                                                   |
+-----------|-------------------------------------------------------------------+
            | (HTTP :8080 or SSH Jump Tunnel)
     Workstation / LAN Client
```

### Subnet IPAM Allocation Matrix

As established in [ADR 006](../../../docs/adr/006-downstream-k8s-cluster-architecture-and-ipam.md), the cluster NAT subnet is organized into structured IPAM allocation ranges:

| IP Range | Allocation Purpose | Workload Description |
| :--- | :--- | :--- |
| `<k8s-subnet>.1` | Gateway / DNS | Hypervisor VM bridge gateway interface (`virbr0`/`k8s-network` dnsmasq) |
| `<k8s-subnet>.2` - `.9` | Core Infrastructure Services | Local container registries, DNS resolvers, internal proxies |
| `<k8s-subnet>.10` - `.19` | Kubernetes Control Plane Nodes | Control plane VMs (`k8s-control-plane` @ `.10`) |
| `<k8s-subnet>.20` - `.49` | Kubernetes Worker Nodes | Scalable pool of worker VMs (`k8s-worker-01` @ `.21`, `k8s-worker-02` @ `.22`) |
| `<k8s-subnet>.50` - `.99` | Standalone Helper & Storage VMs | Observability instances, persistent storage helper VMs |
| `<k8s-subnet>.100` - `.199` | Dynamic DHCP Pool | Ephemeral developer testing instances |
| `<k8s-subnet>.200` - `.254` | Virtual IPs (VIPs) & Ingress | MetalLB LoadBalancer VIP range, HAProxy ingress VIPs |

---

## 🔒 Deterministic SSH Host Keys & Zero-Trust Verification (ADR 008)

To eliminate Man-in-the-Middle (MITM) risks and satisfy pre-commit security standards, Stage 2 avoids `StrictHostKeyChecking=no` by implementing deterministic host key injection:

1. **Pre-Generated Host Keys**: Terraform generates deterministic Ed25519 key pairs (`tls_private_key.k8s_control_plane_host_key`, `tls_private_key.k8s_worker_host_key`) during execution planning.
2. **Cloud-Init Injection**: Private keys are injected into guest VM cloud-init configurations under `/etc/ssh/ssh_host_ed25519_key` on first boot.
3. **Workspace-Isolated `known_hosts`**: Terraform generates `.terraform/known_hosts` containing public host key fingerprints for all provisioned node IPs.
4. **Strict Provisioner Enforcement**: All `local-exec`, `ssh`, and `scp` commands enforce:
   `-o UserKnownHostsFile=.terraform/known_hosts -o StrictHostKeyChecking=yes`

---

## ⚡ Dynamic Monitoring Dashboard & Ingress Routing (ADR 007)

Stage 2 automatically provisions and verifies an end-to-end workload and ingress routing path:

1. **Dynamic Dashboard Service**: A live Python inspection service (`manifests/dashboard.py`) runs on `k8s-worker-01` listening on port `30080`. It dynamically discovers its live runtime IP, hostname, system uptime, and interface state (`/api/status` and HTML UI).
2. **Hypervisor NAT Port Forwarding**: The Stage 1 hypervisor VM configures `iptables` PREROUTING rules to forward external port `8080` to `k8s-worker-01:30080`.
3. **Access Methods**:
   - **Direct LAN Browser Access**: `http://<sandbox-vm-ip>:8080`
   - **Workstation SSH Tunnel**: `ssh -L 8080:<worker-ip>:30080 ubuntu@<sandbox-vm-ip>` -> access `http://localhost:8080`
   - **Kubernetes API Tunnel**: `ssh -L 6443:<control-plane-ip>:6443 ubuntu@<sandbox-vm-ip>`
4. **Production Kubernetes Manifests**: A complete Kubernetes Deployment, Service (NodePort `30080`), and ConfigMap are available in `manifests/dashboard.yaml` for full `kubectl` deployments.

---

## 🚀 Prerequisites & Deployment Guide

### Prerequisites

1. Stage 1 Nested Sandbox hypervisor VM is deployed and running (`cd ../01-nested-sandbox && terraform apply`).
2. Obtain the Stage 1 hypervisor IP address:
   ```bash
   cd ../01-nested-sandbox
   terraform output sandbox_ip_address
   ```

### Configuration

Copy `terraform.tfvars.example` to `terraform.tfvars` and set the `nested_hypervisor_ip`:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Example `terraform.tfvars`:

```hcl
nested_hypervisor_ip     = "192.168.9.189"
nested_hypervisor_user   = "ubuntu"
cluster_network_cidr     = "192.168.10.0/24"
k8s_control_plane_ip     = "192.168.10.10"
k8s_worker_count         = 2
k8s_worker_ips           = ["192.168.10.21", "192.168.10.22"]
k8s_control_plane_memory = "4096"
k8s_control_plane_vcpu   = 2
k8s_worker_memory        = "2048"
k8s_worker_vcpu          = 2
```

### Execution Steps

```bash
# 1. Initialize OpenTofu / Terraform provider plugins
terraform init

# 2. Review execution plan
terraform plan

# 3. Apply infrastructure and deploy workload
terraform apply
```

### Post-Deployment Verification

Run the automated verification script:

```bash
../../scripts/verify-stage2.sh --check
```

Or access the live cluster dashboard in your browser: `http://<nested_hypervisor_ip>:8080`

---

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.0 |
| <a name="requirement_libvirt"></a> [libvirt](#requirement\_libvirt) | ~> 0.7.0 |
| <a name="requirement_local"></a> [local](#requirement\_local) | >= 2.4.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >= 3.2.0 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | >= 4.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_libvirt"></a> [libvirt](#provider\_libvirt) | 0.7.6 |
| <a name="provider_local"></a> [local](#provider\_local) | 2.9.0 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.3.0 |
| <a name="provider_tls"></a> [tls](#provider\_tls) | 4.3.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [libvirt_cloudinit_disk.control_plane_init](https://registry.terraform.io/providers/dmacvicar/libvirt/latest/docs/resources/cloudinit_disk) | resource |
| [libvirt_cloudinit_disk.worker_init](https://registry.terraform.io/providers/dmacvicar/libvirt/latest/docs/resources/cloudinit_disk) | resource |
| [libvirt_domain.k8s_control_plane](https://registry.terraform.io/providers/dmacvicar/libvirt/latest/docs/resources/domain) | resource |
| [libvirt_domain.k8s_worker](https://registry.terraform.io/providers/dmacvicar/libvirt/latest/docs/resources/domain) | resource |
| [libvirt_network.k8s_network](https://registry.terraform.io/providers/dmacvicar/libvirt/latest/docs/resources/network) | resource |
| [libvirt_volume.k8s_control_plane_disk](https://registry.terraform.io/providers/dmacvicar/libvirt/latest/docs/resources/volume) | resource |
| [libvirt_volume.k8s_worker_disk](https://registry.terraform.io/providers/dmacvicar/libvirt/latest/docs/resources/volume) | resource |
| [libvirt_volume.ubuntu_base](https://registry.terraform.io/providers/dmacvicar/libvirt/latest/docs/resources/volume) | resource |
| [local_file.stage2_known_hosts](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [null_resource.deploy_dashboard_workload](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [tls_private_key.k8s_control_plane_host_key](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [tls_private_key.k8s_worker_host_key](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_network_cidr"></a> [cluster\_network\_cidr](#input\_cluster\_network\_cidr) | Subnet CIDR range for the downstream Kubernetes cluster NAT network | `string` | `"192.168.2.0/24"` | no |
| <a name="input_k8s_control_plane_ip"></a> [k8s\_control\_plane\_ip](#input\_k8s\_control\_plane\_ip) | Static IPv4 address allocated to the Kubernetes control plane node | `string` | `"192.168.2.10"` | no |
| <a name="input_k8s_control_plane_memory"></a> [k8s\_control\_plane\_memory](#input\_k8s\_control\_plane\_memory) | RAM allocated to the Kubernetes control plane VM (in MB) | `string` | `"4096"` | no |
| <a name="input_k8s_control_plane_vcpu"></a> [k8s\_control\_plane\_vcpu](#input\_k8s\_control\_plane\_vcpu) | vCPUs allocated to the Kubernetes control plane VM | `number` | `2` | no |
| <a name="input_k8s_worker_count"></a> [k8s\_worker\_count](#input\_k8s\_worker\_count) | Number of Kubernetes worker nodes to provision | `number` | `2` | no |
| <a name="input_k8s_worker_ips"></a> [k8s\_worker\_ips](#input\_k8s\_worker\_ips) | List of static IPv4 addresses allocated to Kubernetes worker nodes | `list(string)` | <pre>[<br>  "192.168.2.20",<br>  "192.168.2.21"<br>]</pre> | no |
| <a name="input_k8s_worker_memory"></a> [k8s\_worker\_memory](#input\_k8s\_worker\_memory) | RAM allocated to each Kubernetes worker VM (in MB) | `string` | `"2048"` | no |
| <a name="input_k8s_worker_vcpu"></a> [k8s\_worker\_vcpu](#input\_k8s\_worker\_vcpu) | vCPUs allocated to each Kubernetes worker VM | `number` | `2` | no |
| <a name="input_nested_hypervisor_ip"></a> [nested\_hypervisor\_ip](#input\_nested\_hypervisor\_ip) | IP address or hostname of the Stage 1 Nested Sandbox hypervisor VM | `string` | n/a | yes |
| <a name="input_nested_hypervisor_user"></a> [nested\_hypervisor\_user](#input\_nested\_hypervisor\_user) | SSH user for authenticating with the nested hypervisor VM | `string` | `"ubuntu"` | no |
| <a name="input_ssh_known_hosts_path"></a> [ssh\_known\_hosts\_path](#input\_ssh\_known\_hosts\_path) | Local path to the SSH known\_hosts file for server host key verification | `string` | `"~/.ssh/known_hosts"` | no |
| <a name="input_ssh_private_key_path"></a> [ssh\_private\_key\_path](#input\_ssh\_private\_key\_path) | Local path to the SSH private key used for libvirt connection | `string` | `"~/.ssh/id_ed25519"` | no |
| <a name="input_ssh_public_key_path"></a> [ssh\_public\_key\_path](#input\_ssh\_public\_key\_path) | Local path to the SSH public key injected via Cloud-Init into K8s nodes | `string` | `"~/.ssh/id_ed25519.pub"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_subnet_cidr"></a> [cluster\_subnet\_cidr](#output\_cluster\_subnet\_cidr) | Subnet CIDR range used for the downstream Kubernetes cluster NAT network |
| <a name="output_dashboard_tunnel_command"></a> [dashboard\_tunnel\_command](#output\_dashboard\_tunnel\_command) | SSH port-forward tunnel command to access the dynamic dashboard from workstation localhost |
| <a name="output_dashboard_url"></a> [dashboard\_url](#output\_dashboard\_url) | Direct HTTP URL to access the dynamic cluster monitoring dashboard via hypervisor NAT forwarding |
| <a name="output_k8s_control_plane_ip"></a> [k8s\_control\_plane\_ip](#output\_k8s\_control\_plane\_ip) | Static IPv4 address of the Kubernetes control plane node |
| <a name="output_k8s_worker_ips"></a> [k8s\_worker\_ips](#output\_k8s\_worker\_ips) | List of IPv4 addresses allocated to Kubernetes worker nodes |
| <a name="output_kubectl_tunnel_command"></a> [kubectl\_tunnel\_command](#output\_kubectl\_tunnel\_command) | SSH tunnel command to securely access the Kubernetes API server from local workstation |
| <a name="output_stage2_known_hosts_path"></a> [stage2\_known\_hosts\_path](#output\_stage2\_known\_hosts\_path) | Path to the workspace-isolated SSH known\_hosts file containing deterministic host key signatures |
<!-- END_TF_DOCS -->
