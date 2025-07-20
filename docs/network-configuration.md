# Network Configuration Guide

This document provides the network configuration instructions for your UDM Pro and Fast Hosts DNS setup.

## UDM Pro Configuration (192.168.1.254)

### DNS Settings

Access your UDM Pro admin interface at https://192.168.1.254 and configure the following DNS entries:

#### Static DNS Entries

Navigate to **Settings > Networks > DNS**

Add the following static DNS entries:

```
# Infrastructure
proxmox.home.andisoft.co.uk          -> 192.168.1.10
talos-cp-01.home.andisoft.co.uk      -> 192.168.1.11  
talos-worker-01.home.andisoft.co.uk  -> 192.168.1.1

# Services (all point to worker node for LoadBalancer)
home.andisoft.co.uk                  -> 192.168.1.1
grafana.home.andisoft.co.uk          -> 192.168.1.1
prometheus.home.andisoft.co.uk       -> 192.168.1.1
alertmanager.home.andisoft.co.uk     -> 192.168.1.1
```

#### DHCP Reservations

Navigate to **Settings > Networks > DHCP**

Create the following DHCP reservations to ensure consistent IP addresses:

```
# Proxmox Host
MAC: [Your Proxmox server MAC]       -> 192.168.1.10

# Talos Control Plane
MAC: BC:24:11:2E:C8:01               -> 192.168.1.11

# Talos Worker 
MAC: BC:24:11:2E:C8:00               -> 192.168.1.1
```

### Firewall Rules

Ensure the following ports are open between your network segments:

#### Proxmox (192.168.1.10)
- Port 8006 (HTTPS) - Proxmox web interface
- Port 22 (SSH) - SSH access

#### Talos Cluster
- Port 6443 (HTTPS) - Kubernetes API
- Port 50000 (TCP) - Talos API

#### Application Ports
- Port 80/443 (HTTP/HTTPS) - Ingress traffic to applications

## Fast Hosts DNS Configuration

Log in to your Fast Hosts control panel and add the following DNS records for `andisoft.co.uk`:

### A Records

```
# Home Assistant (points to your home public IP)
home.andisoft.co.uk    IN  A    [YOUR_PUBLIC_IP]
```

### CNAME Records (Optional)

If you prefer to use CNAMEs for easier management:

```
# All services point to the main home subdomain
grafana.andisoft.co.uk      IN  CNAME  home.andisoft.co.uk
prometheus.andisoft.co.uk   IN  CNAME  home.andisoft.co.uk
alertmanager.andisoft.co.uk IN  CNAME  home.andisoft.co.uk
```

## Port Forwarding (Router/Firewall)

Configure your internet router to forward traffic to your home lab:

```
# HTTPS traffic for Home Assistant
External Port: 443  -> Internal: 192.168.1.1:443

# HTTP traffic (optional, for Let's Encrypt challenges)  
External Port: 80   -> Internal: 192.168.1.1:80
```

## Verification Steps

After configuration, verify the setup:

### 1. Internal DNS Resolution

From any device on your network:

```bash
# Test internal DNS
nslookup proxmox.home.andisoft.co.uk
nslookup home.andisoft.co.uk

# Should resolve to internal IPs
```

### 2. External DNS Resolution

From an external network:

```bash
# Test external DNS
nslookup home.andisoft.co.uk

# Should resolve to your public IP
```

### 3. Service Connectivity

```bash
# Test internal access
curl -k https://proxmox.home.andisoft.co.uk:8006

# Test application access
curl -k https://home.andisoft.co.uk
```

## SSL Certificate Considerations

The deployment uses cert-manager with Let's Encrypt for SSL certificates. Ensure:

1. Port 80 is forwarded for HTTP-01 challenges
2. Your domain points to your public IP
3. Firewall allows inbound traffic on ports 80/443

## Troubleshooting

### DNS Issues

```bash
# Check UDM Pro DNS settings
# Verify DHCP reservations are active
# Check firewall rules aren't blocking DNS

# From a client machine:
dig @192.168.1.254 home.andisoft.co.uk
```

### Connectivity Issues

```bash
# Test from outside your network
telnet your-public-ip 443

# Test from inside your network  
telnet 192.168.1.1 443
```

### Certificate Issues

```bash
# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager

# Check certificate status
kubectl get certificates -A
```

## Network Diagram

```
Internet
    │
    ▼
[Router/Firewall] (Port Forward 80/443)
    │
    ▼
[UDM Pro] 192.168.1.254 (DNS, DHCP)
    │
    ▼
192.168.1.0/24 Network
    │
    ├── 192.168.1.10  - Proxmox VE
    ├── 192.168.1.11  - Talos Control Plane
    └── 192.168.1.1   - Talos Worker (LoadBalancer)
```

This configuration ensures:
- Internal services resolve to internal IPs
- External access routes through your public IP
- Load balancing works correctly within the cluster
- SSL certificates can be obtained automatically
