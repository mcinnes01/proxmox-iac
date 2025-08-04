terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.35.1"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "3.4.5"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# Note: Provider configurations removed - they're now configured at the root level
# This allows the module to be used with depends_on

# Fetch the Flannel manifest from the official repository
data "http" "flannel_manifest" {
  url = "https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml"
}

# Create a temporary file with the manifest content
resource "local_file" "flannel_manifest" {
  content  = data.http.flannel_manifest.response_body
  filename = "${path.module}/flannel-manifest.yaml"
}

# Use a null_resource to apply the Flannel manifest with kubectl
resource "null_resource" "flannel" {
  depends_on = [local_file.flannel_manifest]
  
  triggers = {
    manifest_content = data.http.flannel_manifest.response_body
  }
  
  provisioner "local-exec" {
    command = "kubectl apply -f ${local_file.flannel_manifest.filename}"
  }
  
  provisioner "local-exec" {
    when    = destroy
    command = "kubectl delete -f ${path.module}/flannel-manifest.yaml --ignore-not-found=true || true"
  }
}
