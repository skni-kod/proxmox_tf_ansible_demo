output "container_ip" {
  value       = proxmox_lxc.container.network[0].ip
}

output "container_hostname" {
  value       = proxmox_lxc.container.hostname
}