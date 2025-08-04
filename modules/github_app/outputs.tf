output "app_id" {
  value = github_app.flux_app.id
  description = "GitHub App ID"
}

output "installation_id" {
  value = github_app.flux_app.installation_id
  description = "GitHub App Installation ID"
}

output "private_key_pem" {
  value = github_app.flux_app.pem
  description = "GitHub App private key in PEM format"
  sensitive = true
}
