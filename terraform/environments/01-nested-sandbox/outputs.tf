output "sandbox_ip_address" {
  value       = libvirt_domain.sandbox_hypervisor.network_interface[0].addresses
  description = "The IP address of the provisioned Nested Sandbox Hypervisor VM"
}

output "sandbox_vm_name" {
  value       = libvirt_domain.sandbox_hypervisor.name
  description = "The libvirt domain name of the Nested Sandbox Hypervisor VM"
}
