# MinIO Buckets Configuration
# Create S3 buckets for various services

# Longhorn Backup Bucket
resource "minio_s3_bucket" "longhorn_backup" {
  bucket = "homelab-longhorn"
  acl    = "private"

  depends_on = [module.minio_backup]
}

output "longhorn_bucket_name" {
  description = "Longhorn backup bucket name"
  value       = minio_s3_bucket.longhorn_backup.id
}

output "longhorn_bucket_url" {
  description = "Longhorn backup S3 URL"
  value       = "s3://${minio_s3_bucket.longhorn_backup.id}@us-east-1/"
}
