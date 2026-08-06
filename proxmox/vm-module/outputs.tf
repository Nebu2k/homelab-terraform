output "vm_id" {
  description = "VM ID"
  value       = proxmox_virtual_environment_vm.vm.vm_id
}

output "vm_name" {
  description = "VM name"
  value       = proxmox_virtual_environment_vm.vm.name
}

output "vm_ip_address" {
  description = "VM IP address (with CIDR)"
  value       = var.vm_ip_address
}

output "vm_ip" {
  description = "VM IP address (without CIDR)"
  value       = split("/", var.vm_ip_address)[0]
}

output "ssh_command" {
  description = "SSH connection command"
  value       = "ssh ${var.cloud_init_user}@${split("/", var.vm_ip_address)[0]}"
}
