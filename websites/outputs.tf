output "canonical_redirects" {
  description = "Which hostname redirects to which, per site"
  value = {
    for domain in keys(var.sites) :
    domain => "${local.redirected_host[domain]} -> ${local.canonical_host[domain]} (301)"
  }
}
