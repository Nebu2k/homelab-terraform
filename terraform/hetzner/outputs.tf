# ===========================================
# Outputs
# ===========================================

output "server_ipv4" {
  description = "Public IPv4 address of the Pangolin server"
  value       = hcloud_server.pangolin.ipv4_address
}

output "server_ipv6" {
  description = "Public IPv6 address of the Pangolin server"
  value       = hcloud_server.pangolin.ipv6_address
}

output "server_id" {
  description = "Hetzner server ID"
  value       = hcloud_server.pangolin.id
}

output "ssh_command" {
  description = "SSH command to connect to the server"
  value       = "ssh root@${hcloud_server.pangolin.ipv4_address}"
}

output "pangolin_url" {
  description = "Pangolin Dashboard URL"
  value       = "https://${var.pangolin_domain}"
}

output "pangolin_api_url" {
  description = "Pangolin Integration API URL"
  value       = "https://${var.pangolin_api_domain}/v1/docs"
}

output "dns_records" {
  description = "Created DNS records"
  value = {
    pangolin     = "${var.pangolin_domain} -> ${hcloud_server.pangolin.ipv4_address}"
    pangolin_api = "${var.pangolin_api_domain} -> ${hcloud_server.pangolin.ipv4_address}"
  }
}
