variable "nested_hypervisor_ip" {
  type        = string
  description = "IP address or hostname of the Stage 1 Nested Sandbox hypervisor VM (used as SSH jump host)"
}

variable "nested_hypervisor_user" {
  type        = string
  default     = "ubuntu"
  description = "SSH user for authenticating with the nested hypervisor VM"
}

variable "ssh_private_key_path" {
  type        = string
  default     = "~/.ssh/id_ed25519"
  description = "Local path to the SSH private key used for connecting to VMs"
}

variable "ssh_known_hosts_path" {
  type        = string
  default     = "~/.ssh/known_hosts"
  description = "Local path to the SSH known_hosts file for server host key verification"
}

variable "stage2_known_hosts_path" {
  type        = string
  default     = "../02-k8s-cluster/.terraform/known_hosts"
  description = "Path to Stage 2 workspace-isolated known_hosts file containing deterministic host keys"
}

variable "k8s_control_plane_ip" {
  type        = string
  default     = "192.168.10.10"
  description = "Static IPv4 address of the downstream Kubernetes control plane node"
}

variable "k8s_worker_ips" {
  type        = list(string)
  default     = ["192.168.10.21", "192.168.10.22"]
  description = "List of static IPv4 addresses for downstream Kubernetes worker nodes"
}

variable "k3s_version" {
  type        = string
  default     = "v1.28.8+k3s1"
  description = "K3s release version to install on control plane and worker nodes"
}

variable "cluster_cidr" {
  type        = string
  default     = "10.42.0.0/16"
  description = "Pod CIDR network range for internal cluster overlay"
}

variable "service_cidr" {
  type        = string
  default     = "10.43.0.0/16"
  description = "Kubernetes Service CIDR network range"
}

variable "cluster_dns" {
  type        = string
  default     = "10.43.0.10"
  description = "Cluster DNS Service IP"
}
