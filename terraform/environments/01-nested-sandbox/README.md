<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.0 |
| <a name="requirement_libvirt"></a> [libvirt](#requirement\_libvirt) | ~> 0.7.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_libvirt"></a> [libvirt](#provider\_libvirt) | 0.7.6 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [libvirt_cloudinit_disk.commoninit](https://registry.terraform.io/providers/dmacvicar/libvirt/latest/docs/resources/cloudinit_disk) | resource |
| [libvirt_domain.sandbox_hypervisor](https://registry.terraform.io/providers/dmacvicar/libvirt/latest/docs/resources/domain) | resource |
| [libvirt_volume.sandbox_hypervisor_disk](https://registry.terraform.io/providers/dmacvicar/libvirt/latest/docs/resources/volume) | resource |
| [libvirt_volume.ubuntu_base](https://registry.terraform.io/providers/dmacvicar/libvirt/latest/docs/resources/volume) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_libvirt_host_ip"></a> [libvirt\_host\_ip](#input\_libvirt\_host\_ip) | IP address or hostname of the remote hypervisor host | `string` | n/a | yes |
| <a name="input_libvirt_network_name"></a> [libvirt\_network\_name](#input\_libvirt\_network\_name) | Name of the libvirt bridge network attached to br0 | `string` | `"host-bridge"` | no |
| <a name="input_libvirt_user"></a> [libvirt\_user](#input\_libvirt\_user) | SSH user for authenticating with the hypervisor host | `string` | n/a | yes |
| <a name="input_sandbox_memory"></a> [sandbox\_memory](#input\_sandbox\_memory) | RAM allocated to the nested sandbox VM (in MB) | `string` | `"4096"` | no |
| <a name="input_sandbox_vcpu"></a> [sandbox\_vcpu](#input\_sandbox\_vcpu) | vCPUs allocated to the nested sandbox VM | `number` | `2` | no |
| <a name="input_ssh_known_hosts_path"></a> [ssh\_known\_hosts\_path](#input\_ssh\_known\_hosts\_path) | Local path to the SSH known\_hosts file for server host key verification | `string` | `"~/.ssh/known_hosts"` | no |
| <a name="input_ssh_private_key_path"></a> [ssh\_private\_key\_path](#input\_ssh\_private\_key\_path) | Local path to the SSH private key used for libvirt connection | `string` | `"~/.ssh/id_ed25519"` | no |
| <a name="input_ssh_public_key_path"></a> [ssh\_public\_key\_path](#input\_ssh\_public\_key\_path) | Local path to the SSH public key injected via Cloud-Init | `string` | `"~/.ssh/id_ed25519.pub"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_sandbox_ip_address"></a> [sandbox\_ip\_address](#output\_sandbox\_ip\_address) | The IP address of the provisioned Nested Sandbox Hypervisor VM |
| <a name="output_sandbox_vm_name"></a> [sandbox\_vm\_name](#output\_sandbox\_vm\_name) | The libvirt domain name of the Nested Sandbox Hypervisor VM |
<!-- END_TF_DOCS -->
