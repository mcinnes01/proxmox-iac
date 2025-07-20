terramate {
  config {
    run {
      env {
        # Terraform variables from terramate globals
        TF_VAR_proxmox_api_url = global.proxmox.api_url
        TF_VAR_proxmox_node = global.proxmox.node
        TF_VAR_vm_datastore = global.proxmox.datastore
        TF_VAR_network_gateway = global.network.gateway
        TF_VAR_nameserver = global.network.nameserver
        TF_VAR_cluster_name = global.talos.cluster_name
        TF_VAR_domain_name = global.domain.name
        TF_VAR_internal_domain = global.domain.internal
      }
    }
  }
}
