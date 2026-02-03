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
# Server Configuration
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
# Pangolin Configuration
# ===========================================

variable "pangolin_domain" {
  description = "Main domain for Pangolin"
  type        = string
  default     = "pangolin.elmstreet79.de"
}

variable "pangolin_api_domain" {
  description = "API domain for Pangolin Integration API"
  type        = string
  default     = "pangolin-api.elmstreet79.de"
}

variable "pangolin_server_secret" {
  description = "Pangolin server secret (from config.yml)"
  type        = string
  sensitive   = true
}

# ===========================================
# SMTP Configuration (AWS SES)
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

variable "smtp_from" {
  description = "SMTP from address"
  type        = string
  default     = "pangolin@elmstreet79.de"
}

# ===========================================
# MaxMind GeoLite2
# ===========================================

variable "maxmind_license_key" {
  description = "MaxMind License Key for GeoLite2 database download"
  type        = string
  sensitive   = true
}

# ===========================================
# Let's Encrypt
# ===========================================

variable "letsencrypt_email" {
  description = "Email for Let's Encrypt certificates"
  type        = string
  default     = "certs@seb-it.com"
}
