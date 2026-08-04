variable "libvirt_host_ip" {
  type        = string
  description = "IP address or hostname of the remote hypervisor host"
}

variable "libvirt_user" {
  type        = string
  description = "SSH user for authenticating with the hypervisor host"
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
  description = "Local path to the SSH public key injected via Cloud-Init"
}

variable "sandbox_memory" {
  type        = string
  default     = "4096"
  description = "RAM allocated to the nested sandbox VM (in MB)"
}

variable "sandbox_vcpu" {
  type        = number
  default     = 2
  description = "vCPUs allocated to the nested sandbox VM"
}

variable "libvirt_network_name" {
  type        = string
  default     = "host-bridge"
  description = "Name of the libvirt bridge network attached to br0"
}
