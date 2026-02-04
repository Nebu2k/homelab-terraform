# ===========================================
# SSH Key
# ===========================================

resource "hcloud_ssh_key" "homelab" {
  name       = "homelab-ssh-key"
  public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIINAmiR21sgqeyWKIcX1Vf2qSdFoA/6skC+xZGR6vOWa homelab"
}