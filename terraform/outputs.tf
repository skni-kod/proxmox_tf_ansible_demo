output "container_ip" {
  value = trimsuffix(proxmox_lxc.container.network[0].ip, "/24")
}

output "container_hostname" {
  value       = proxmox_lxc.container.hostname
}