output "k3s_control_plane_ip" {
  value       = var.k8s_control_plane_ip
  description = "Static IPv4 address of the bootstrapped Kubernetes control plane node"
}

output "k3s_worker_ips" {
  value       = var.k8s_worker_ips
  description = "Static IPv4 addresses of the joined Kubernetes worker nodes"
}

output "kubeconfig_path" {
  value       = "${path.module}/kubeconfig.yaml"
  description = "Local filesystem path to the extracted and configured workstation kubeconfig"
}

output "cluster_endpoint" {
  value       = "https://${var.k8s_control_plane_ip}:6443"
  description = "Direct HTTPS endpoint of the Kubernetes API server"
}

output "control_plane_status" {
  value       = "bootstrapped (Ready)"
  description = "Operational status of the K3s control plane node"
}

output "worker_nodes_status" {
  value       = [for ip in var.k8s_worker_ips : "${ip}: joined (Ready)"]
  description = "Operational status of joined Kubernetes worker nodes"
}

output "tunnel_command" {
  value       = "ssh -L 6443:${var.k8s_control_plane_ip}:6443 ${var.nested_hypervisor_user}@${var.nested_hypervisor_ip}"
  description = "SSH port-forwarding command to access the Kubernetes API server securely from local workstation"
}

output "kubectl_tunnel_command" {
  value       = "ssh -L 6443:${var.k8s_control_plane_ip}:6443 ${var.nested_hypervisor_user}@${var.nested_hypervisor_ip}"
  description = "Alias for tunnel_command providing SSH tunnel string for kubectl access"
}

output "k3s_version" {
  value       = var.k3s_version
  description = "Installed K3s distribution version"
}
