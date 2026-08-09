terraform {
  required_version = ">= 1.0"

  required_providers {
    proxmox = {
      source = "bpg/proxmox"
      # Untergrenze am 2026-08-09 von 0.93.0 angehoben: seit dem Umbenennen auf
      # proxmox_download_file braucht dieser Stack eine Version, die den neuen
      # Typ ueberhaupt kennt. 0.111.1 ist die, gegen die es geprueft ist.
      version = ">= 0.111.1, < 1.0.0"
    }
  }
}

provider "proxmox" {
  endpoint = var.proxmox_endpoint
  username = var.proxmox_username
  password = var.proxmox_password
  insecure = var.proxmox_insecure

  ssh {
    agent    = true
    username = var.proxmox_ssh_username
  }
}

# Der minio-Provider ist am 2026-08-01 entfallen. Longhorn sichert seit dem
# Wechsel des BackupTargets direkt per CIFS aufs UniFi-NAS, MinIO hat keinen
# Nutzer mehr und die VM ist gestoppt.
#
# Wichtig, falls das je zurueckkommt: der Provider zeigte fest auf
# 192.168.2.15:9000 und wurde bei JEDEM plan/apply initialisiert. Mit
# gestoppter VM haette das den ganzen Stack blockiert, auch fuer Aenderungen,
# die mit MinIO nichts zu tun haben. Deshalb ist die Bucket-Ressource per
# "terraform state rm" aus dem State genommen worden statt per destroy: der
# Bucket-Inhalt auf der VM-Disk bleibt so erhalten.
