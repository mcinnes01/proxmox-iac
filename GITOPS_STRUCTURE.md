# GitOps Repository Structure for Your Homelab

This document shows how to structure your GitOps repository to work with the Terraform-bootstrapped Flux.

## Repository Structure

```
kubernetes/
├── infrastructure/          # Platform services
│   ├── metallb/            # Load balancer
│   │   ├── kustomization.yaml
│   │   ├── namespace.yaml
│   │   ├── helm-repository.yaml
│   │   ├── helm-release.yaml
│   │   └── ip-address-pool.yaml
│   ├── longhorn/           # Distributed storage
│   │   ├── kustomization.yaml
│   │   ├── namespace.yaml
│   │   ├── helm-repository.yaml
│   │   └── helm-release.yaml
│   ├── cert-manager/       # TLS certificates
│   ├── external-dns/       # DNS automation
│   └── ingress-nginx/      # Ingress controller
├── monitoring/             # Observability stack
│   ├── prometheus/
│   ├── grafana/
│   └── loki/
├── apps/                   # Your applications
│   ├── bind9/             # DNS server
│   ├── home-assistant/    # If you run it in k8s
│   └── your-apps/
└── clusters/
    └── homelab/           # Cluster-specific configs
        ├── infrastructure-kustomization.yaml
        ├── monitoring-kustomization.yaml
        └── apps-kustomization.yaml
```

## Key Benefits of This Approach

### **Terraform (Infrastructure)**
- ✅ **Reliable foundation**: VMs, cluster, CNI that Flux depends on
- ✅ **Fast recovery**: `terraform apply` rebuilds everything reliably
- ✅ **Version controlled**: Infrastructure as Code in this repo

### **Flux (Platform & Apps)**  
- ✅ **GitOps workflow**: PR-based changes, automated rollbacks
- ✅ **Kubernetes-native**: Helm charts, Kustomize, native resources
- ✅ **Continuous delivery**: Automatic updates when you push changes
- ✅ **Easy scaling**: Add new services by adding YAML files

## Example MetalLB Configuration (Flux-managed)

`kubernetes/infrastructure/metallb/helm-release.yaml`:
```yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: metallb
  namespace: metallb-system
spec:
  interval: 10m
  chart:
    spec:
      chart: metallb
      version: "0.14.9"
      sourceRef:
        kind: HelmRepository
        name: metallb
        namespace: metallb-system
  values:
    # MetalLB configuration values
```

`kubernetes/infrastructure/metallb/ip-address-pool.yaml`:
```yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: metallb-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.1.1-192.168.1.1      # Home Assistant
  - 192.168.1.20-192.168.1.30    # Other services
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: l2-advertisement
  namespace: metallb-system
spec:
  ipAddressPools:
  - metallb-pool
```

This way:
- **Terraform** ensures you have a working cluster with networking
- **Flux** manages all the services running inside that cluster
- **GitOps** workflow for everything post-bootstrap

Perfect for your homelab and scales to enterprise patterns!
