variable "libvirt_host_ip" {
  type        = string
  description = "IP address or hostname of the remote hypervisor host"
}

variable "libvirt_user" {
  type        = string
  description = "SSH user for authenticating with the hypervisor host"
}

variable "ssh_public_key_path" {
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
  description = "Local path to the SSH public key injected via Cloud-Init"
}