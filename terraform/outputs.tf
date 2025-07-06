output "support_node_ip" {
  description = "Support node IP address"
  value       = proxmox_virtual_environment_vm.k3s-support.ipv4_addresses[0]
}

output "master_node_ips" {
  description = "Master node IP addresses"
  value       = proxmox_virtual_environment_vm.k3s-master[*].ipv4_addresses[0]
}

output "k3s_server_token" {
  description = "K3s server token"
  value       = random_password.k3s-server-token.result
  sensitive   = true
}

output "support_db_password" {
  description = "Support database password"
  value       = random_password.support-db-password.result
  sensitive   = true
}

output "k3s_master_db_password" {
  description = "K3s master database password"
  value       = random_password.k3s-master-db-password.result
  sensitive   = true
}
