# ===========================================
# SSH Key
# ===========================================

resource "hcloud_ssh_key" "homelab" {
  name       = "homelab-ssh-key"
  public_key = var.ssh_public_key
}