output "public_records" {
  description = "Public CNAME records created for internet-exposed services"
  value = {
    for k, r in cloudflare_record.public : r.name => "${r.name}.${var.domain} -> ${r.content}"
  }
}
