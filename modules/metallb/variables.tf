variable "kube_host" {
  type        = string
  description = "Kubernetes API server host"
}

variable "kube_cluster_ca_certificate" {
  type        = string
  description = "Kubernetes cluster CA certificate (base64 encoded)"
}

variable "kube_client_key" {
  type        = string
  description = "Kubernetes client key (base64 encoded)"
}

variable "kube_client_certificate" {
  type        = string
  description = "Kubernetes client certificate (base64 encoded)"
}

variable "metallb_version" {
  type        = string
  description = "MetalLB Helm chart version"
}

variable "metallb_pool_addresses" {
  type = string
  description = "IP address pool for MetalLB LoadBalancer services"
}
