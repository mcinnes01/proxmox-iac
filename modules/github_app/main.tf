# GitHub App for Flux authentication
resource "github_app" "flux_app" {
  name         = var.app_name
  description  = "GitHub App for Flux GitOps automation"
  homepage_url = "https://fluxcd.io"

  # Permissions needed for Flux
  repository_permissions = {
    contents = "read"
    metadata = "read"
  }

  # Events that trigger webhooks (optional for Flux)
  events = ["push", "pull_request"]
}

# Install the app on the repository
resource "github_app_installation_repository" "flux_installation" {
  installation_id = github_app.flux_app.installation_id
  repository      = var.repository_name
}
