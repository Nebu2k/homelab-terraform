# MinIO Backup VM (ABGEBAUT am 2026-08-04)
#
# S3-compatible storage, war bis 2026-08-01 das Longhorn-Backup-Ziel. Seither
# sichert Longhorn direkt per CIFS aufs UniFi-NAS
# (cifs://192.168.2.6/longhorn_backup), MinIO hatte keinen Nutzer mehr.
#
# Zwischen dem 01.08. und heute lief die VM nur noch gestoppt mit on_boot=false
# weiter, damit der alte Backup-Bestand erreichbar blieb, solange die
# NAS-Sicherung noch unbewiesen war. Der Bestand auf dem NAS ist inzwischen
# mehrere Tage tief und durchgaengig "Completed", die VM ist deshalb per apply
# zerstoert und gibt 500 GB auf nvme-2tb frei.
#
# Der Block bleibt auskommentiert stehen, statt geloescht zu werden: als Vorlage,
# falls je wieder ein S3-Ziel gebraucht wird. Auskommentiert ist fuer Terraform
# gleichbedeutend mit geloescht, der Code beschreibt also weiterhin die Wahrheit.
# Beim Reaktivieren daran denken: vm_on_boot wieder auf true, und der Datentraeger
# ist weg, der alte Bucket-Inhalt kommt nicht zurueck.
#
# Der zugehoerige minio-Provider ist bereits am 2026-08-01 aus main.tf entfallen.
# Die Variablen minio_root_user / minio_root_password stehen weiterhin in
# variables.tf, damit dieser Block ohne weitere Aenderung wieder aktiviert werden
# kann.

# module "minio_backup" {
#   source = "./vm-module"
#
#   # Proxmox Configuration (from root variables)
#   proxmox_node    = var.proxmox_node
#   snippet_storage = var.snippet_storage
#   ssh_public_key  = var.ssh_public_key
#
#   # VM Identity
#   vm_name        = "minio-backup"
#   vm_id          = 500
#   vm_description = "MinIO S3-compatible storage for Longhorn backups"
#
#   # Keep original cloud-init filename to avoid recreation
#   cloud_init_filename = "minio-cloud-init.yaml"
#
#   vm_on_boot = false
#
#   # Resources
#   vm_cpu_cores = 2
#   vm_memory    = 4096
#   vm_disk_size = 500
#   vm_disk_ssd  = true
#
#   # Storage
#   vm_storage         = "nvme-2tb"
#   cloud_init_storage = "nvme-2tb"
#
#   # Network
#   vm_network_bridge = "vmbr0"
#   vm_network_tag    = 0
#   vm_ip_address     = "192.168.2.15/24"
#   vm_gateway        = "192.168.2.1"
#   vm_dns_servers    = ["192.168.2.4", "192.168.2.16"]
#
#   # Cloud-init customization
#   cloud_init_packages = [
#     "docker.io",
#     "docker-compose"
#   ]
#
#   cloud_init_runcmd = [
#     "systemctl enable docker",
#     "systemctl start docker",
#     "mkdir -p /mnt/minio-data",
#     <<-EOT
#     docker run -d \
#       --name minio \
#       --restart unless-stopped \
#       -p 9000:9000 \
#       -p 9001:9001 \
#       -v /mnt/minio-data:/data \
#       -e MINIO_ROOT_USER=${var.minio_root_user} \
#       -e MINIO_ROOT_PASSWORD=${var.minio_root_password} \
#       minio/minio server /data --console-address ":9001"
#     EOT
#   ]
# }
#
# # Outputs specific to MinIO
# output "minio_vm_id" {
#   description = "MinIO VM ID"
#   value       = module.minio_backup.vm_id
# }
#
# output "minio_vm_ip" {
#   description = "MinIO VM IP address"
#   value       = module.minio_backup.vm_ip
# }
#
# output "minio_ssh_command" {
#   description = "SSH connection command"
#   value       = module.minio_backup.ssh_command
# }
#
# output "minio_api_endpoint" {
#   description = "MinIO API endpoint (S3-compatible)"
#   value       = "http://${module.minio_backup.vm_ip}:9000"
# }
#
# output "minio_console_url" {
#   description = "MinIO Console URL"
#   value       = "http://${module.minio_backup.vm_ip}:9001"
# }
#
# output "minio_connection_info" {
#   description = "MinIO connection information"
#   value       = <<-EOT
#
#   MinIO VM deployed successfully!
#
#   SSH Access:
#     ${module.minio_backup.ssh_command}
#
#   MinIO Console:
#     URL: http://${module.minio_backup.vm_ip}:9001
#     User: ${var.minio_root_user}
#
#   MinIO S3 API:
#     Endpoint: http://${module.minio_backup.vm_ip}:9000
#
#   EOT
# }
