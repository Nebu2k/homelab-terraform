output "public_records" {
  description = "Public CNAME records created for internet-exposed services"
  value = {
    for k, r in cloudflare_dns_record.public : k => "${r.name} -> ${r.content}"
  }
}
