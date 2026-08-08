output "k8s_control_plane_ip" {
  value       = libvirt_domain.k8s_control_plane.network_interface[0].addresses[0]
  description = "Static IPv4 address of the Kubernetes control plane node"
}

output "k8s_worker_ips" {
  value       = [for d in libvirt_domain.k8s_worker : d.network_interface[0].addresses[0]]
  description = "List of IPv4 addresses allocated to Kubernetes worker nodes"
}

output "cluster_subnet_cidr" {
  value       = var.cluster_network_cidr
  description = "Subnet CIDR range used for the downstream Kubernetes cluster NAT network"
}

output "kubectl_tunnel_command" {
  value       = "ssh -L 6443:${libvirt_domain.k8s_control_plane.network_interface[0].addresses[0]}:6443 ${var.nested_hypervisor_user}@${var.nested_hypervisor_ip}"
  description = "SSH tunnel command to securely access the Kubernetes API server from local workstation"
}
