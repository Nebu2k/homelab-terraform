# ===========================================
# Provider Credentials
# ===========================================

variable "hcloud_token" {
  description = "Hetzner Cloud API Token"
  type        = string
  sensitive   = true
}

variable "cloudflare_api_token" {
  description = "Cloudflare API Token"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for elmstreet79.de"
  type        = string
}

# ===========================================
# Server Defaults
# ===========================================

variable "ssh_public_key" {
  description = "SSH Public Key for VPS access"
  type        = string
}

variable "location" {
  description = "Hetzner Datacenter location"
  type        = string
  default     = "nbg1"
}

variable "server_type" {
  description = "Hetzner Server Type"
  type        = string
  default     = "cax11"
}

variable "server_image" {
  description = "Hetzner Server Image"
  type        = string
  default     = "ubuntu-24.04"
}

# ===========================================
# SMTP / Email (AWS SES)
# ===========================================

variable "smtp_host" {
  description = "SMTP host"
  type        = string
  default     = "email-smtp.eu-west-1.amazonaws.com"
}

variable "smtp_port" {
  description = "SMTP port"
  type        = number
  default     = 587
}

variable "smtp_user" {
  description = "SMTP username (AWS SES)"
  type        = string
  sensitive   = true
}

variable "smtp_pass" {
  description = "SMTP password (AWS SES)"
  type        = string
  sensitive   = true
}

# ===========================================
# Certificates
# ===========================================

variable "letsencrypt_email" {
  description = "Email for Let's Encrypt certificates"
  type        = string
  default     = "certs@seb-it.com"
}
