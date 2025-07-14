# Create CSI role in Proxmox
resource "proxmox_virtual_environment_role" "csi" {
  role_id = "CSI"
  privileges = [
    "VM.Audit",
    "VM.Config.Disk",
    "Datastore.Allocate",
    "Datastore.AllocateSpace",
    "Datastore.Audit"
  ]
}

# Create kubernetes-csi user
resource "proxmox_virtual_environment_user" "kubernetes_csi" {
  user_id = "kubernetes-csi@pve"
  comment = "User for Proxmox CSI Plugin"
  
  acl {
    path      = "/"
    propagate = true
    role_id   = proxmox_virtual_environment_role.csi.role_id
  }
}

# Create token for kubernetes-csi user
resource "proxmox_virtual_environment_user_token" "kubernetes_csi_token" {
  comment               = "Token for Proxmox CSI Plugin"
  token_name            = "csi"
  user_id               = proxmox_virtual_environment_user.kubernetes_csi.user_id
  privileges_separation = false
}

# Create privileged namespace for CSI plugin
resource "kubernetes_namespace" "csi_proxmox" {
  metadata {
    name = "csi-proxmox"
    labels = {
      "pod-security.kubernetes.io/enforce" = "privileged"
      "pod-security.kubernetes.io/audit"   = "baseline"
      "pod-security.kubernetes.io/warn"    = "baseline"
    }
  }
}

# Create secret with Proxmox CSI Plugin configuration
resource "kubernetes_secret" "proxmox_csi_plugin" {
  metadata {
    name      = "proxmox-csi-plugin"
    namespace = kubernetes_namespace.csi_proxmox.id
  }

  data = {
    "config.yaml" = <<EOF
clusters:
- url: "${var.proxmox.endpoint}/api2/json"
  insecure: ${var.proxmox.insecure}
  token_id: "${proxmox_virtual_environment_user_token.kubernetes_csi_token.id}"
  token_secret: "${element(split("=", proxmox_virtual_environment_user_token.kubernetes_csi_token.value), length(split("=", proxmox_virtual_environment_user_token.kubernetes_csi_token.value)) - 1)}"
  region: ${var.proxmox.cluster_name}
EOF
  }
}
