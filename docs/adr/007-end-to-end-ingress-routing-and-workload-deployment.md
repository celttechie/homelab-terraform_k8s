# ADR 007: End-to-End Ingress Routing and Visual Workload Deployment

## Status
Accepted

## Context
After provisioning Stage 1 (Nested Sandbox Hypervisor) and Stage 2 (Downstream Kubernetes Nodes inside isolated private NAT VPC network `<k8s-subnet>.0/24`), operators require a method to access deployed cluster applications (e.g. web dashboards, observability UIs, and ingress services) directly from workstations on the physical home LAN (`<physical-lan-ip>`).

Additionally, to validate end-to-end compute, networking, and storage health across all Kubernetes worker nodes, the cluster requires an active, demonstrable workload that proves internal pod overlay CNI routing, node scheduling, and external ingress accessibility.

## Decision
We adopt an **Hypervisor Ingress Proxy & Visual Cluster Dashboard Architecture** for Stage 2 Kubernetes workload verification:

1. **Demonstrable Visual Workload (Kubernetes Monitoring Dashboard)**:
   - Deploy **Headlamp / Kubernetes Dashboard** alongside a lightweight cluster status UI across Stage 2 worker nodes.
   - The dashboard visualizes real-time node health, pod scheduling, CPU/RAM utilization, and workload status across control plane and worker nodes.

2. **Ingress & Service Routing Topology**:
   - **Ingress Controller**: Deploy Nginx Ingress / NodePort Service listening on standardized NodePorts (e.g. port `30080` / `30443`).
   - **Virtual IP / LoadBalancer Pool**: Allocate LoadBalancer Virtual IPs in the parameterized range `<k8s-subnet>.200` - `<k8s-subnet>.254` (via MetalLB) on the nested `default` network.

3. **Hypervisor LAN Ingress Forwarding**:
   - To make the dashboard accessible from physical home LAN workstations (`<physical-lan-ip>`) without requiring complex static routing on home routers, the Stage 1 hypervisor (`sandbox-hypervisor-node` / `<sandbox-vm-ip>`) proxies external HTTP/HTTPS traffic to the downstream Kubernetes Ingress service:
     - **Option A (HAProxy / Nginx Reverse Proxy on Hypervisor)**: Stage 1 hypervisor proxies `http://<sandbox-vm-ip>:8080` to `<k8s-subnet>.10:30080` or `<k8s-subnet>.200:80`.
     - **Option B (SSH Tunnel / Port Forwarding)**: Workstations execute `ssh -L 8080:<k8s-control-plane-ip>:30080 ubuntu@<sandbox-vm-ip>` to access `http://localhost:8080`.

4. **Automated Verification Pipeline**:
   - Provide an automated deployment manifest (`terraform/environments/02-k8s-cluster/manifests/dashboard.yaml` or setup script) that deploys the visual monitoring dashboard and returns HTTP `200 OK` health status.

## Consequences
- **Positive:** End-to-end verification—proves K8s compute scheduling, pod overlay CNI networking, and ingress routing are fully operational.
- **Positive:** LAN Accessibility—enables workstation browser access to cluster dashboards and web apps directly from the physical home network.
- **Positive:** Non-intrusive—does not require modifying home network router configuration or exposing physical LAN to internal pod broadcast traffic.
- **Negative / Trade-off:** Hypervisor VM must run a lightweight proxy service (or SSH tunnel) to route incoming LAN traffic to internal private `<k8s-subnet>.0/24` IPs.
