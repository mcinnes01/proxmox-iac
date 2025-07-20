globals {
  # Proxmox Configuration
  proxmox = {
    api_url   = "https://192.168.1.10:8006/api2/json"
    node      = "gateway"
    datastore = "local-lvm"
  }
  
  # Network Configuration
  network = {
    gateway = "192.168.1.254"
    nameserver = "192.168.1.254"
    cidr = "192.168.1.0/24"
  }
  
  # Talos Configuration
  talos = {
    cluster_name = "homelab"
    version = "v1.8.1"
    kubernetes_version = "v1.31.1"
  }
  
  # Domain Configuration  
  domain = {
    name = "andisoft.co.uk"
    internal = "home.andisoft.co.uk"
  }
  
  # VM Configuration
  vms = {
    control_plane = {
      cpu_cores = 4
      memory_mb = 8192
      disk_size_gb = 100
    }
    worker = {
      cpu_cores = 6
      memory_mb = 16384  
      disk_size_gb = 200
    }
  }
}
