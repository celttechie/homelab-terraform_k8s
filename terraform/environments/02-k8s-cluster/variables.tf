variable "nested_hypervisor_ip" {
  type        = string
  description = "IP address or hostname of the Stage 1 Nested Sandbox hypervisor VM"
}

variable "nested_hypervisor_user" {
  type        = string
  default     = "ubuntu"
  description = "SSH user for authenticating with the nested hypervisor VM"
}

variable "ssh_private_key_path" {
  type        = string
  default     = "~/.ssh/id_ed25519"
  description = "Local path to the SSH private key used for libvirt connection"
}

variable "ssh_known_hosts_path" {
  type        = string
  default     = "~/.ssh/known_hosts"
  description = "Local path to the SSH known_hosts file for server host key verification"
}

variable "ssh_public_key_path" {
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
  description = "Local path to the SSH public key injected via Cloud-Init into K8s nodes"
}

variable "cluster_network_cidr" {
  type        = string
  default     = "192.168.2.0/24"
  description = "Subnet CIDR range for the downstream Kubernetes cluster NAT network"
}

variable "k8s_control_plane_ip" {
  type        = string
  default     = "192.168.2.10"
  description = "Static IPv4 address allocated to the Kubernetes control plane node"
}

variable "k8s_worker_count" {
  type        = number
  default     = 2
  description = "Number of Kubernetes worker nodes to provision"
}

variable "k8s_worker_ips" {
  type        = list(string)
  default     = ["192.168.2.20", "192.168.2.21"]
  description = "List of static IPv4 addresses allocated to Kubernetes worker nodes"
}

variable "k8s_control_plane_memory" {
  type        = string
  default     = "4096"
  description = "RAM allocated to the Kubernetes control plane VM (in MB)"
}

variable "k8s_control_plane_vcpu" {
  type        = number
  default     = 2
  description = "vCPUs allocated to the Kubernetes control plane VM"
}

variable "k8s_worker_memory" {
  type        = string
  default     = "2048"
  description = "RAM allocated to each Kubernetes worker VM (in MB)"
}

variable "k8s_worker_vcpu" {
  type        = number
  default     = 2
  description = "vCPUs allocated to each Kubernetes worker VM"
}
