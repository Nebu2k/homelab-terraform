terraform {
  backend "s3" {
    bucket  = "homelab-elmstreet79-terraform-state"
    key     = "homelab/cloudflare/terraform.tfstate"
    region  = "eu-central-1"
    encrypt = true

    # Native S3 locking (1.10+). The DynamoDB table it replaces was never
    # wired up, so until 2026-08-13 there was no locking at all.
    use_lockfile = true
  }
}
