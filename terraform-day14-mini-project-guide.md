# Terraform Mini Project — Azure VMSS, Load Balancer & Auto-scaling
## Deep-Dive Learning Guide — Day 14 / 28 Days of Easy Terraform
### Beginner-First Edition | Full Project Walkthrough | PowerShell Throughout

---

## Before You Start

This is Day 14 — your first **real mini project**. Every previous day was
a building block. Today you assemble them all into a working, publicly
accessible web application running on Azure.

By the end of this guide you will have:
- A complete 3-tier Azure network (VNet → Subnet → NSG)
- A Virtual Machine Scale Set (VMSS) running a web game
- A Public Load Balancer distributing traffic across VMs
- A NAT Gateway providing secure outbound internet access
- Auto-scaling rules that grow and shrink your VM pool automatically
- A live URL you can open in a browser and play a game on

This is real infrastructure. It works. Real Azure charges apply — always
destroy at the end.

---

## Table of Contents

1. Understanding the Architecture — Every Component Explained
2. The Full Resource Map — What Gets Created
3. Networking Concepts You Need to Know First
4. Component 1 — Resource Group
5. Component 2 — Virtual Network and Subnet
6. Component 3 — Network Security Group (NSG)
7. Component 4 — Public IP Addresses (Two of Them)
8. Component 5 — Load Balancer, Backend Pool, Health Probe, Rules
9. Component 6 — NAT Gateway
10. Component 7 — Virtual Machine Scale Set (VMSS)
11. Component 8 — User Data Script — Deploying the Application
12. Component 9 — Auto-scaling Rules (Your Assignment)
13. Component 10 — NSG Security Hardening (Your Assignment)
14. The `random_pet` Provider — Generating Unique Names
15. The `filebase64()` Function — Encoding the Startup Script
16. The Complete Working Code — All Files
17. Running the Deployment
18. Verifying the Deployment
19. Assignment Tasks — Your 20%
20. Common Mistakes in This Project
21. Cleanup — Always Destroy When Done
22. Complete Architecture Cheat Sheet

---

## 1. Understanding the Architecture — Every Component Explained

### The big picture

```
Internet
    │
    ▼
[Public IP]          ← One IP, publicly accessible
    │
    ▼
[Load Balancer]      ← Distributes traffic across VMs
    │  ↕ health probes on Port 80
    ▼
[Backend Pool]       ← Group of VM instances
    │
    ▼
[VMSS - 3 VMs]       ← Scale Set: min 1, default 3, max 10
    │
[Subnet A]           ← All compute resources live here
    │
[VNet 10.0.0.0/16]   ← Private network boundary
    │
[NSG]                ← Firewall rules for the subnet
    │
[NAT Gateway]        ← VMs use this for outbound internet (apt-get, etc.)
    │
[NAT Public IP]      ← Separate public IP for outbound traffic only
```

### Why each component exists

| Component | Why it exists |
|---|---|
| VNet | Private network boundary — all resources live inside |
| Subnet | Subdivision of VNet for organising resources |
| NSG | Firewall — controls what traffic is allowed in/out |
| Public IP (LB) | The address users type into their browser |
| Load Balancer | Splits traffic across multiple VMs for reliability |
| Backend Pool | The list of VMs the load balancer sends traffic to |
| Health Probe | LB checks if each VM is alive before sending traffic |
| LB Rule | Maps public port to VM port (Port 80 → Port 80) |
| VMSS | Group of identical VMs that auto-scale up and down |
| User Data Script | Runs automatically on each VM at startup to install the app |
| NAT Gateway | VMs have no public IP, so they use this for outbound traffic |
| NAT Public IP | The IP address used for outbound traffic from VMs |
| Auto-scale | Rules that automatically add/remove VMs based on CPU usage |

---

## 2. The Full Resource Map — What Gets Created

```
Resources Terraform creates (18 total):

1.  azurerm_resource_group              "rg"
2.  azurerm_virtual_network             "vnet"
3.  azurerm_subnet                      "subnet_a"
4.  azurerm_network_security_group      "nsg"
5.  azurerm_subnet_network_security_group_association  "nsg_assoc"
6.  azurerm_public_ip                   "lb_pip"         (for Load Balancer)
7.  azurerm_lb                          "lb"
8.  azurerm_lb_backend_address_pool     "bpool"
9.  azurerm_lb_probe                    "lb_probe"
10. azurerm_lb_rule                     "lb_rule"
11. azurerm_lb_nat_rule                 "ssh_nat"         (SSH access)
12. azurerm_public_ip                   "nat_pip"         (for NAT Gateway)
13. azurerm_nat_gateway                 "nat_gw"
14. azurerm_nat_gateway_public_ip_association  "nat_pip_assoc"
15. azurerm_subnet_nat_gateway_association    "nat_sn_assoc"
16. azurerm_orchestrated_virtual_machine_scale_set  "vmss"
17. azurerm_monitor_autoscale_setting   "autoscale"
18. random_pet                          "rg_name"        (naming helper)
```

---

## 3. Networking Concepts You Need to Know First

### CIDR notation — what is `10.0.0.0/16`?

CIDR tells you how many IP addresses are in a range.

```
10.0.0.0/16
         ↑
         The number after / = how many bits are fixed
         16 fixed bits = 65,536 total addresses in this range

10.0.0.0/24
         ↑
         24 fixed bits = 256 total addresses

Rule: Higher number = smaller range
  /8  = ~16 million addresses
  /16 = ~65,000 addresses
  /24 = 256 addresses
```

In this project:
- VNet: `10.0.0.0/16` — the entire private network (65k addresses)
- Subnet: `10.0.0.0/20` — a portion inside the VNet (4,096 addresses)

The subnet must be WITHIN the VNet's range. `10.0.0.0/20` is inside `10.0.0.0/16`.

### What is a Backend Pool?

A backend pool is the Load Balancer's list of servers it can send traffic to.
When a user's request arrives at the Load Balancer, it picks one healthy server
from the backend pool and forwards the request there.

### What is a Health Probe?

The Load Balancer regularly sends a test request to each VM (on Port 80, at
a specific URL path). If the VM responds: it's healthy, keep sending traffic.
If it doesn't respond: it's unhealthy, stop sending traffic to it until it recovers.

### What is NAT Gateway?

Your VMs have no public IP addresses (for security). But they need to reach
the internet for things like `apt-get install`. The NAT Gateway sits between
the VMs and the internet, translates the VM's private IP to the NAT's public IP
for outbound requests, and routes responses back. VMs can reach out, but nothing
from the internet can reach in.

---

## 4. Component 1 — Resource Group

```hcl
# resource_group.tf
resource "azurerm_resource_group" "rg" {
  name     = "day14-rg"
  location = "Canada Central"

  tags = {
    Environment = "demo"
    ManagedBy   = "Terraform"
    Project     = "Day14-MiniProject"
  }
}
```

All 18 resources will live inside this resource group. When you destroy the
project, deleting this resource group deletes everything inside it.

---

## 5. Component 2 — Virtual Network and Subnet

```hcl
# network.tf

# The private network boundary
resource "azurerm_virtual_network" "vnet" {
  name                = "day14-vnet"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = ["10.0.0.0/16"]   # ~65k private addresses

  tags = {
    ManagedBy = "Terraform"
  }
}

# A single subnet containing all compute resources
resource "azurerm_subnet" "subnet_a" {
  name                 = "subnet-a"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.0.0/20"]  # 4,096 addresses inside the VNet
}
```

### Why one subnet?

For this demo, all resources (VMSS, load balancer backend, NAT gateway) share
one subnet. In production you'd create separate subnets for frontend, backend,
and database tiers with different NSG rules applied to each.

---

## 6. Component 3 — Network Security Group (NSG)

An NSG is a list of rules. Each rule specifies:
- Direction: Inbound or Outbound
- Priority: Lower number = checked first
- Protocol: TCP, UDP, or *
- Source: Where traffic comes from
- Destination: Where traffic goes
- Action: Allow or Deny

```hcl
# nsg.tf

resource "azurerm_network_security_group" "nsg" {
  name                = "day14-nsg"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  # ── Starter Rules (Instructor's baseline) ──────────────────────────────
  # TODO (Your Assignment): Restrict these to only allow from Load Balancer

  # Rule 1: Allow HTTP from anywhere (your assignment: restrict to LB only)
  security_rule {
    name                       = "allow-http"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"           # TODO: change to LB source tag
    destination_address_prefix = "*"
  }

  # Rule 2: Allow HTTPS from anywhere
  security_rule {
    name                       = "allow-https"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"           # TODO: restrict
    destination_address_prefix = "*"
  }

  # Rule 3: Allow SSH (your assignment: should be IP-restricted)
  security_rule {
    name                       = "allow-ssh"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"           # TODO: restrict to your IP
    destination_address_prefix = "*"
  }

  tags = {
    ManagedBy = "Terraform"
  }
}

# Associate the NSG with the Subnet
# This applies all NSG rules to every resource inside subnet-a
resource "azurerm_subnet_network_security_group_association" "nsg_assoc" {
  subnet_id                 = azurerm_subnet.subnet_a.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}
```

### How NSG association works

```
Without NSG association: All traffic flows freely — no filtering
With NSG association:    All traffic to/from subnet-a is filtered by NSG rules
```

The association is a separate Terraform resource (`azurerm_subnet_network_security_group_association`),
not an argument inside the subnet or NSG block.

---

## 7. Component 4 — Public IP Addresses (Two of Them)

This project needs TWO public IPs for different purposes:

```
Public IP 1 (lb-pip):    For the Load Balancer frontend
                          Users type this IP to access the app
                          Inbound traffic IN to your VMs

Public IP 2 (nat-pip):   For the NAT Gateway
                          Your VMs use this for outbound internet access
                          Traffic going OUT from your VMs
```

```hcl
# public_ips.tf

# Public IP 1: Load Balancer frontend
resource "azurerm_public_ip" "lb_pip" {
  name                = "day14-lb-pip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"       # IP doesn't change (important for DNS)
  sku                 = "Standard"     # Standard SKU supports zones
  zones               = ["1", "2", "3"] # High availability across zones

  # Domain name label — creates a DNS name like:
  # day14-rg-<random>.canadacentral.cloudapp.azure.com
  domain_name_label = "${azurerm_resource_group.rg.name}-${random_pet.rg_name.id}"

  tags = {
    ManagedBy = "Terraform"
    Purpose   = "LoadBalancer-Frontend"
  }
}

# Public IP 2: NAT Gateway
resource "azurerm_public_ip" "nat_pip" {
  name                = "day14-nat-pip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1"]

  tags = {
    ManagedBy = "Terraform"
    Purpose   = "NAT-Gateway-Outbound"
  }
}
```

### Why `allocation_method = "Static"`?

- **Dynamic**: Azure assigns an IP when you create the resource, may change
  if you deallocate. Unpredictable.
- **Static**: Azure reserves a specific IP permanently. Users can bookmark it
  or point DNS to it. Required for Load Balancers.

### Why `zones = ["1", "2", "3"]` for the Load Balancer IP?

Azure divides regions into Availability Zones. If one zone's datacenter fails,
the other zones keep running. A zone-redundant public IP stays online even
if one zone has an outage.

---

## 8. Component 5 — Load Balancer, Backend Pool, Health Probe, Rules

### The Load Balancer itself

```hcl
# load_balancer.tf

resource "azurerm_lb" "lb" {
  name                = "day14-lb"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Standard"

  # Frontend IP configuration — connects the LB to the public IP
  frontend_ip_configuration {
    name                 = "frontend-ip"
    public_ip_address_id = azurerm_public_ip.lb_pip.id
    # ↑ Implicit dependency: public IP must exist before load balancer
  }

  tags = { ManagedBy = "Terraform" }
}
```

### The Backend Address Pool — where traffic goes

```hcl
# The pool of VMs that will receive traffic
resource "azurerm_lb_backend_address_pool" "bpool" {
  name            = "day14-backend-pool"
  loadbalancer_id = azurerm_lb.lb.id
  # VMs add themselves to this pool via their network interface configuration
}
```

### The Health Probe — checking VM health

```hcl
# Load Balancer checks each VM by requesting GET http://vm:80/index.php
resource "azurerm_lb_probe" "lb_probe" {
  name                = "http-health-probe"
  loadbalancer_id     = azurerm_lb.lb.id
  protocol            = "Http"
  port                = 80
  request_path        = "/index.php"   # the URL path to check
  interval_in_seconds = 5              # check every 5 seconds
  number_of_probes    = 2              # 2 failures = unhealthy
}
```

### The Load Balancer Rule — mapping ports

```hcl
# Map: external port 80 → backend pool port 80
resource "azurerm_lb_rule" "lb_rule" {
  name                           = "http-lb-rule"
  loadbalancer_id                = azurerm_lb.lb.id
  protocol                       = "Tcp"
  frontend_port                  = 80     # users connect on port 80
  backend_port                   = 80     # VMs receive on port 80
  frontend_ip_configuration_name = "frontend-ip"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.bpool.id]
  probe_id                       = azurerm_lb_probe.lb_probe.id
  # ↑ Uses health probe — only sends traffic to healthy VMs
}
```

### NAT Rule for SSH access

```hcl
# Allows direct SSH into specific VMs through the Load Balancer
# External port 50000 → VM on port 22 (SSH)
resource "azurerm_lb_nat_rule" "ssh_nat" {
  name                           = "ssh-nat-rule"
  resource_group_name            = azurerm_resource_group.rg.name
  loadbalancer_id                = azurerm_lb.lb.id
  protocol                       = "Tcp"
  frontend_port_range_start      = 50000
  frontend_port_range_end        = 50005
  backend_port                   = 22
  frontend_ip_configuration_name = "frontend-ip"
  backend_address_pool_id        = azurerm_lb_backend_address_pool.bpool.id
}
```

---

## 9. Component 6 — NAT Gateway

```hcl
# nat_gateway.tf

# The NAT Gateway resource
resource "azurerm_nat_gateway" "nat_gw" {
  name                    = "day14-nat-gw"
  resource_group_name     = azurerm_resource_group.rg.name
  location                = azurerm_resource_group.rg.location
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10

  tags = { ManagedBy = "Terraform" }
}

# Associate the NAT public IP with the NAT Gateway
resource "azurerm_nat_gateway_public_ip_association" "nat_pip_assoc" {
  nat_gateway_id       = azurerm_nat_gateway.nat_gw.id
  public_ip_address_id = azurerm_public_ip.nat_pip.id
}

# Associate the NAT Gateway with the Subnet
# All outbound traffic from subnet-a goes through this gateway
resource "azurerm_subnet_nat_gateway_association" "nat_sn_assoc" {
  subnet_id      = azurerm_subnet.subnet_a.id
  nat_gateway_id = azurerm_nat_gateway.nat_gw.id
}
```

### Why the NAT Gateway needs three separate resources

```
1. azurerm_nat_gateway              → creates the gateway itself
2. azurerm_nat_gateway_public_ip_association → links it to a public IP
3. azurerm_subnet_nat_gateway_association   → links it to a subnet

Azure separates these into three independent resources so you can:
- Share one gateway across multiple subnets
- Swap public IPs without recreating the gateway
- Manage each relationship independently
```

---

## 10. Component 7 — Virtual Machine Scale Set (VMSS)

A VMSS is a group of identical VMs managed together. When load increases,
Azure automatically creates new VMs from the same template. When load decreases,
it removes VMs. You don't manually create or delete individual VMs.

```hcl
# vmss.tf

resource "azurerm_orchestrated_virtual_machine_scale_set" "vmss" {
  name                = "day14-vmss"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  # Starting instance count
  instances = 3

  # Distribute VMs across availability zones for resilience
  zones = ["1", "2", "3"]

  # Platform fault domain count — for high availability grouping
  platform_fault_domain_count = 1

  # ── OS Configuration ────────────────────────────────────────────────────
  os_profile {
    linux_configuration {
      # Admin SSH key for secure login
      admin_username = "adminuser"
      admin_ssh_key {
        username   = "adminuser"
        public_key = file("~/.ssh/id_rsa.pub")
        # ↑ Uses your existing SSH public key
        # Create with: ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa
      }
      disable_password_authentication = true
    }
  }

  # ── Startup Script ──────────────────────────────────────────────────────
  # This script runs ONCE when each VM first boots up
  # Installs Apache, PHP, and deploys the game application
  custom_data = filebase64("${path.module}/user_data.sh")
  # filebase64() reads the script file and base64-encodes it
  # Azure requires cloud-init scripts in base64 format

  # ── VM Image ────────────────────────────────────────────────────────────
  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  # ── VM Size ─────────────────────────────────────────────────────────────
  sku_name = "Standard_D2s_v3"

  # ── OS Disk ─────────────────────────────────────────────────────────────
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  # ── Network Interface Configuration ─────────────────────────────────────
  network_interface {
    name    = "vmss-nic"
    primary = true

    ip_configuration {
      name      = "ip-config"
      primary   = true
      subnet_id = azurerm_subnet.subnet_a.id

      # Add VMs to the Load Balancer's backend pool
      load_balancer_backend_address_pool_ids = [
        azurerm_lb_backend_address_pool.bpool.id
      ]
      # ↑ This is what makes the Load Balancer send traffic to these VMs!

      load_balancer_inbound_nat_rules_ids = [
        azurerm_lb_nat_rule.ssh_nat.id
      ]
    }
  }

  # ── Lifecycle Rule ───────────────────────────────────────────────────────
  # Don't recreate the VMSS template when instance count changes
  # Auto-scaling changes instance count — we don't want that to trigger a rebuild
  lifecycle {
    ignore_changes = [instances]
  }

  tags = { ManagedBy = "Terraform" }
}
```

### Why `ignore_changes = [instances]`?

```
Terraform manages the VMSS template.
Auto-scaling changes the INSTANCE COUNT at runtime.

Without this:
  Auto-scale adds a VM (instances goes from 3 → 4)
  Next terraform apply sees: desired=3, actual=4
  Terraform says: "I need to change instances from 4 back to 3"
  Terraform removes the VM auto-scaling just added!

With ignore_changes = [instances]:
  Terraform manages the template
  Auto-scaling manages the count
  They don't interfere with each other ✓
```

---

## 11. Component 8 — User Data Script

The user data script is the piece of magic that automatically installs and
deploys the application on every VM when it boots.

**`user_data.sh`**
```bash
#!/bin/bash

# Update package list
apt-get update -y

# Install Apache web server, PHP, and curl
apt-get install -y apache2 php libapache2-mod-php curl

# Create application user
useradd -m -s /bin/bash webapp

# Set up web directory
mkdir -p /var/www/html
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html

# Deploy the game application
# Downloads index.php which serves a Tetris-style game
curl -o /var/www/html/index.php \
  https://raw.githubusercontent.com/digininja/DVWA/master/index.php \
  || echo "<?php echo 'Hello from VM: ' . gethostname(); ?>" \
  > /var/www/html/index.php

# Start Apache and enable it to start on boot
systemctl start apache2
systemctl enable apache2

# Log the startup completion
echo "User data script completed on $(hostname)" >> /var/log/startup.log
```

### What `filebase64()` does

```hcl
custom_data = filebase64("${path.module}/user_data.sh")
```

```
filebase64() does two things:
1. Reads the file content (the shell script)
2. Encodes it as base64 (Azure requires this format for cloud-init)

Why base64?
  The script contains special characters, newlines, quotes, etc.
  Base64 encoding makes it safe to transmit in an API call as a single string

${path.module} is a Terraform variable that always resolves to the
directory of the current .tf file — so the path works regardless of
where you run terraform from.
```

---

## 12. Component 9 — Auto-scaling Rules (Your Assignment)

The instructor removed the auto-scaling rules before sharing the code —
this is your assignment. Here is the complete auto-scaling implementation
for you to understand and implement:

```hcl
# autoscale.tf

resource "azurerm_monitor_autoscale_setting" "autoscale" {
  name                = "day14-autoscale"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  target_resource_id  = azurerm_orchestrated_virtual_machine_scale_set.vmss.id

  profile {
    name = "default-autoscale-profile"

    # ── Instance Capacity ────────────────────────────────────────────────
    capacity {
      default = 3   # Start with 3 VMs
      minimum = 1   # Never go below 1 VM
      maximum = 10  # Never exceed 10 VMs
    }

    # ── Scale OUT Rule: Add VM when CPU > 80% ────────────────────────────
    # If average CPU across all VMs > 80% for 5 minutes → add 1 VM
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_orchestrated_virtual_machine_scale_set.vmss.id
        time_grain         = "PT1M"     # measure every 1 minute
        statistic          = "Average"  # average across all VMs
        time_window        = "PT5M"     # look at a 5-minute window
        time_aggregation   = "Average"  # average over that window
        operator           = "GreaterThan"
        threshold          = 80         # trigger above 80% CPU
      }
      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"               # add 1 VM at a time
        cooldown  = "PT5M"            # wait 5 minutes before scaling again
      }
    }

    # ── Scale IN Rule: Remove VM when CPU < 10% ──────────────────────────
    # If average CPU across all VMs < 10% for 5 minutes → remove 1 VM
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_orchestrated_virtual_machine_scale_set.vmss.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 10         # trigger below 10% CPU
      }
      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"               # remove 1 VM at a time
        cooldown  = "PT5M"
      }
    }
  }

  tags = { ManagedBy = "Terraform" }
}
```

### Understanding the time format (ISO 8601 Duration)

```
PT1M  = 1 Minute   (P=Period, T=Time, 1M=1 Minute)
PT5M  = 5 Minutes
PT1H  = 1 Hour
P1D   = 1 Day
```

### How auto-scaling works step by step

```
Every 1 minute (time_grain):
  Azure measures current CPU for each VM

Every 5 minutes (time_window):
  Azure calculates the AVERAGE of those measurements

If average > 80%:
  Scale OUT: add 1 VM
  Wait 5 minutes (cooldown) before checking again

If average < 10%:
  Scale IN: remove 1 VM
  Wait 5 minutes (cooldown) before checking again

Boundaries:
  Never go below 1 VM (minimum)
  Never go above 10 VMs (maximum)
```

---

## 13. Component 10 — NSG Security Hardening (Your Assignment)

The instructor's baseline NSG allows HTTP from `*` (anywhere). Your
assignment is to restrict traffic so only the Load Balancer can send
HTTP traffic to the VMs.

### Azure Service Tags — the key concept

Azure provides **Service Tags** — named groups of IP ranges for Azure services.
Instead of listing all Load Balancer IP addresses (which change), you use the tag:

```hcl
source_address_prefix = "AzureLoadBalancer"
# This represents all Azure Load Balancer infrastructure IPs
# Automatically kept up to date by Microsoft
```

### The hardened NSG rules

```hcl
resource "azurerm_network_security_group" "nsg" {
  name                = "day14-nsg"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  # ── ALLOW: HTTP only from Load Balancer ─────────────────────────────────
  security_rule {
    name                       = "allow-http-from-lb"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "AzureLoadBalancer"  # ← Only from Azure LB
    destination_address_prefix = "*"
  }

  # ── ALLOW: HTTPS only from Load Balancer ────────────────────────────────
  security_rule {
    name                       = "allow-https-from-lb"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "AzureLoadBalancer"  # ← Only from Azure LB
    destination_address_prefix = "*"
  }

  # ── ALLOW: SSH only from your specific IP ───────────────────────────────
  security_rule {
    name                       = "allow-ssh-from-admin"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "YOUR_PUBLIC_IP/32"  # ← Replace with your IP
    destination_address_prefix = "*"
  }

  # ── DENY: All other inbound traffic ─────────────────────────────────────
  security_rule {
    name                       = "deny-all-inbound"
    priority                   = 4096    # Lowest priority — checked last
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = { ManagedBy = "Terraform" }
}
```

**PowerShell — find your public IP:**
```powershell
# Get your current public IP address
(Invoke-WebRequest -Uri "https://api.ipify.org").Content
```

---

## 14. The `random_pet` Provider — Generating Unique Names

The instructor used a provider called `random_pet` to generate a unique
suffix for the load balancer's DNS name.

```hcl
# providers.tf

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" { features {} }
provider "random"  {}
```

```hcl
# random_pet generates names like "casual-bear" or "noble-hawk"
resource "random_pet" "rg_name" {
  prefix    = "day14"   # always starts with "day14"
  length    = 2         # two random words
  separator = "-"
}

# Usage in domain_name_label:
domain_name_label = "${azurerm_resource_group.rg.name}-${random_pet.rg_name.id}"
# Example result: "day14-rg-casual-bear"
# Full URL: day14-rg-casual-bear.canadacentral.cloudapp.azure.com
```

### Why unique names matter

Azure requires globally unique DNS names for public IPs. If you use
the same domain name as someone else, your deployment fails. Random suffixes
guarantee uniqueness.

---

## 15. The `filebase64()` Function — Encoding the Startup Script

```hcl
custom_data = filebase64("${path.module}/user_data.sh")
```

### What each part does

```
filebase64()      → a Terraform built-in function
  Step 1: Read the file at the given path
  Step 2: Convert the entire file content to base64 encoding

"${path.module}"  → resolves to the directory containing the current .tf file
  If your .tf file is at: C:\projects\day14\vmss.tf
  Then path.module = "C:\projects\day14"
  Full path: C:\projects\day14\user_data.sh

Why base64?
  Azure's API for cloud-init scripts requires base64
  The script may contain special characters that would break JSON encoding
  Base64 is safe to transmit through any API
```

### Creating the user_data.sh file

**PowerShell:**
```powershell
@"
#!/bin/bash
apt-get update -y
apt-get install -y apache2 php libapache2-mod-php curl
mkdir -p /var/www/html
curl -o /var/www/html/index.php https://raw.githubusercontent.com/digininja/DVWA/master/index.php || echo '<?php echo "VM: " . gethostname(); ?>' > /var/www/html/index.php
systemctl start apache2
systemctl enable apache2
"@ | Out-File -FilePath ".\user_data.sh" -Encoding utf8 -NoNewline
```

---

## 16. The Complete Working Code — All Files

**`providers.tf`**
```hcl
terraform {
  required_version = ">= 1.9.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" { features {} }
provider "random"  {}
```

---

**`variables.tf`**
```hcl
variable "location" {
  type    = string
  default = "Canada Central"
}

variable "prefix" {
  type    = string
  default = "day14"
}

variable "vm_size_map" {
  type        = map(string)
  description = "VM size per environment (use lookup() to select)"
  default = {
    dev     = "Standard_B2s"
    staging = "Standard_D2s_v3"
    prod    = "Standard_D4s_v3"
  }
}

variable "environment" {
  type    = string
  default = "dev"
}
```

---

**`locals.tf`**
```hcl
locals {
  # Use lookup to select VM size based on environment
  vm_size = lookup(var.vm_size_map, var.environment, "Standard_D2s_v3")

  # Common tags applied to all resources
  # Uses timestamp() for the "modified_on" requirement
  common_tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = "Day14-MiniProject"
    ModifiedOn  = formatdate("DD-MM-YYYY hh:mm", timestamp())
  }
}
```

---

**`main.tf`** — orchestrates all components
```hcl
# ── Random name for DNS uniqueness ──────────────────────────────────────────
resource "random_pet" "rg_name" {
  prefix    = var.prefix
  length    = 2
  separator = "-"
}

# ── Resource Group ───────────────────────────────────────────────────────────
resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-rg"
  location = var.location
  tags     = local.common_tags
}

# ── Virtual Network ──────────────────────────────────────────────────────────
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.prefix}-vnet"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = ["10.0.0.0/16"]
  tags                = local.common_tags
}

# ── Subnet ───────────────────────────────────────────────────────────────────
resource "azurerm_subnet" "subnet_a" {
  name                 = "${var.prefix}-subnet-a"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.0.0/20"]
}

# ── NSG ──────────────────────────────────────────────────────────────────────
resource "azurerm_network_security_group" "nsg" {
  name                = "${var.prefix}-nsg"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tags                = local.common_tags

  security_rule {
    name                       = "allow-http-from-lb"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-ssh"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"    # TODO: restrict to your IP
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "nsg_assoc" {
  subnet_id                 = azurerm_subnet.subnet_a.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# ── Public IPs ───────────────────────────────────────────────────────────────
resource "azurerm_public_ip" "lb_pip" {
  name                = "${var.prefix}-lb-pip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  domain_name_label   = "${azurerm_resource_group.rg.name}-${random_pet.rg_name.id}"
  tags                = local.common_tags
}

resource "azurerm_public_ip" "nat_pip" {
  name                = "${var.prefix}-nat-pip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1"]
  tags                = local.common_tags
}

# ── Load Balancer ────────────────────────────────────────────────────────────
resource "azurerm_lb" "lb" {
  name                = "${var.prefix}-lb"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Standard"
  frontend_ip_configuration {
    name                 = "frontend-ip"
    public_ip_address_id = azurerm_public_ip.lb_pip.id
  }
  tags = local.common_tags
}

resource "azurerm_lb_backend_address_pool" "bpool" {
  name            = "${var.prefix}-bpool"
  loadbalancer_id = azurerm_lb.lb.id
}

resource "azurerm_lb_probe" "lb_probe" {
  name                = "http-probe"
  loadbalancer_id     = azurerm_lb.lb.id
  protocol            = "Http"
  port                = 80
  request_path        = "/index.php"
  interval_in_seconds = 5
  number_of_probes    = 2
}

resource "azurerm_lb_rule" "lb_rule" {
  name                           = "http-rule"
  loadbalancer_id                = azurerm_lb.lb.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "frontend-ip"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.bpool.id]
  probe_id                       = azurerm_lb_probe.lb_probe.id
}

resource "azurerm_lb_nat_rule" "ssh_nat" {
  name                           = "ssh-nat"
  resource_group_name            = azurerm_resource_group.rg.name
  loadbalancer_id                = azurerm_lb.lb.id
  protocol                       = "Tcp"
  frontend_port_range_start      = 50000
  frontend_port_range_end        = 50005
  backend_port                   = 22
  frontend_ip_configuration_name = "frontend-ip"
  backend_address_pool_id        = azurerm_lb_backend_address_pool.bpool.id
}

# ── NAT Gateway ──────────────────────────────────────────────────────────────
resource "azurerm_nat_gateway" "nat_gw" {
  name                    = "${var.prefix}-nat-gw"
  resource_group_name     = azurerm_resource_group.rg.name
  location                = azurerm_resource_group.rg.location
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
  tags                    = local.common_tags
}

resource "azurerm_nat_gateway_public_ip_association" "nat_pip_assoc" {
  nat_gateway_id       = azurerm_nat_gateway.nat_gw.id
  public_ip_address_id = azurerm_public_ip.nat_pip.id
}

resource "azurerm_subnet_nat_gateway_association" "nat_sn_assoc" {
  subnet_id      = azurerm_subnet.subnet_a.id
  nat_gateway_id = azurerm_nat_gateway.nat_gw.id
}

# ── Virtual Machine Scale Set ────────────────────────────────────────────────
resource "azurerm_orchestrated_virtual_machine_scale_set" "vmss" {
  name                        = "${var.prefix}-vmss"
  resource_group_name         = azurerm_resource_group.rg.name
  location                    = azurerm_resource_group.rg.location
  instances                   = 3
  zones                       = ["1", "2", "3"]
  platform_fault_domain_count = 1
  sku_name                    = local.vm_size
  custom_data                 = filebase64("${path.module}/user_data.sh")
  tags                        = local.common_tags

  os_profile {
    linux_configuration {
      admin_username = "adminuser"
      admin_ssh_key {
        username   = "adminuser"
        public_key = file("~/.ssh/id_rsa.pub")
      }
      disable_password_authentication = true
    }
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  network_interface {
    name    = "vmss-nic"
    primary = true
    ip_configuration {
      name                                         = "ip-config"
      primary                                      = true
      subnet_id                                    = azurerm_subnet.subnet_a.id
      load_balancer_backend_address_pool_ids       = [azurerm_lb_backend_address_pool.bpool.id]
      load_balancer_inbound_nat_rules_ids          = [azurerm_lb_nat_rule.ssh_nat.id]
    }
  }

  lifecycle {
    ignore_changes = [instances]
  }
}

# ── Auto-scaling ─────────────────────────────────────────────────────────────
resource "azurerm_monitor_autoscale_setting" "autoscale" {
  name                = "${var.prefix}-autoscale"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  target_resource_id  = azurerm_orchestrated_virtual_machine_scale_set.vmss.id

  profile {
    name = "default"
    capacity {
      default = 3
      minimum = 1
      maximum = 10
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_orchestrated_virtual_machine_scale_set.vmss.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 80
      }
      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_orchestrated_virtual_machine_scale_set.vmss.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 10
      }
      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
  }
  tags = local.common_tags
}
```

---

**`outputs.tf`**
```hcl
output "lb_public_ip" {
  description = "Load Balancer public IP address"
  value       = azurerm_public_ip.lb_pip.ip_address
}

output "app_url" {
  description = "Application URL (access after ~2 minutes for startup)"
  value       = "http://${azurerm_public_ip.lb_pip.ip_address}/index.php"
}

output "app_dns_url" {
  description = "Application DNS URL"
  value       = "http://${azurerm_public_ip.lb_pip.fqdn}/index.php"
}

output "vmss_name" {
  description = "VMSS resource name"
  value       = azurerm_orchestrated_virtual_machine_scale_set.vmss.name
}
```

---

## 17. Running the Deployment

**PowerShell — complete workflow:**

```powershell
# ─── STEP 1: Setup ───────────────────────────────────────────────────────────
Set-Location "C:\projects\day14"

# Create SSH key if you don't have one
# On Windows, use OpenSSH (included in Windows 10+):
ssh-keygen -t rsa -b 4096 -f "$HOME\.ssh\id_rsa" -N '""'

# Get your public IP for SSH restriction
$myIP = (Invoke-WebRequest -Uri "https://api.ipify.org").Content
Write-Host "Your public IP: $myIP"

# Create the user_data.sh file
@"
#!/bin/bash
apt-get update -y
apt-get install -y apache2 php libapache2-mod-php curl
echo '<?php echo "<h1>VM: " . gethostname() . "</h1>"; ?>' > /var/www/html/index.php
systemctl start apache2
systemctl enable apache2
"@ | Out-File -FilePath ".\user_data.sh" -Encoding utf8 -NoNewline

# ─── STEP 2: Authentication ───────────────────────────────────────────────────
$env:ARM_CLIENT_ID       = "your-client-id"
$env:ARM_CLIENT_SECRET   = "your-client-secret"
$env:ARM_TENANT_ID       = "your-tenant-id"
$env:ARM_SUBSCRIPTION_ID = "your-subscription-id"

# ─── STEP 3: Initialise ───────────────────────────────────────────────────────
terraform init

# If prompted to upgrade due to random provider:
terraform init -upgrade

# ─── STEP 4: Plan ─────────────────────────────────────────────────────────────
terraform plan

# Check what will be created
terraform plan | Select-String "will be created"
# Should show 18 resources

# ─── STEP 5: Apply ────────────────────────────────────────────────────────────
terraform apply --auto-approve

# Wait ~2-3 minutes for VMs to boot and install the application

# ─── STEP 6: Get the app URL ──────────────────────────────────────────────────
terraform output app_url

# ─── STEP 7: Open in browser ──────────────────────────────────────────────────
Start-Process (terraform output -raw app_url)

# ─── STEP 8: Test load balancing (refresh multiple times)
# Each refresh should sometimes show a different VM hostname
$url = terraform output -raw app_url
for ($i = 1; $i -le 10; $i++) {
  $response = (Invoke-WebRequest -Uri $url).Content
  Write-Host "Request $i`: $($response.Substring(0, [Math]::Min(50, $response.Length)))"
  Start-Sleep -Milliseconds 500
}
```

---

## 18. Verifying the Deployment

```powershell
# Check all resources were created
az resource list --resource-group "day14-rg" --output table

# Check VMSS instances
az vmss list-instances `
  --resource-group "day14-rg" `
  --name "day14-vmss" `
  --output table

# Check Load Balancer public IP
az network public-ip show `
  --resource-group "day14-rg" `
  --name "day14-lb-pip" `
  --query "{IP: ipAddress, DNS: dnsSettings.fqdn}" `
  --output table

# Check auto-scaling configuration
az monitor autoscale show `
  --resource-group "day14-rg" `
  --name "day14-autoscale" `
  --query "{Min: profiles[0].capacity.minimum, Max: profiles[0].capacity.maximum}" `
  --output table
```

### In the Azure Portal

1. Go to Resource Groups → `day14-rg`
2. Should show 16-18 resources
3. Click the Load Balancer → Frontend IP configuration → note the public IP
4. Click the VMSS → Instances tab → see all 3 VMs and their zones
5. Click the NSG → Inbound security rules → verify your rules

---

## 19. Assignment Tasks — Your 20%

### Task 1 — Add Modified-On Tag Using Timestamp

Every resource must have a tag with key `"modified_on"` and the current
timestamp formatted as `"DD-MM-YYYY hh:mm"`.

**Hint:** This is already implemented in `locals.tf` via `local.common_tags`.
Make sure every resource uses `tags = local.common_tags`.

### Task 2 — Implement Auto-scaling Rules

Add the two auto-scaling rules covered in Section 12:
- Scale out when CPU > 80% for 5 minutes (add 1 VM)
- Scale in when CPU < 10% for 5 minutes (remove 1 VM)

### Task 3 — Harden the NSG

Restrict the HTTP and HTTPS rules so only the Azure Load Balancer can
send traffic to the backend VMs (use `"AzureLoadBalancer"` service tag).
Restrict SSH to your specific IP address only.

### Task 4 — Use `lookup` for VM Size

In `locals.tf`, use the `lookup()` function to select the VM size based
on `var.environment`:
```hcl
vm_size = lookup(var.vm_size_map, var.environment, "Standard_D2s_v3")
```

This is already in the guide — verify it's wired up to `sku_name` in the VMSS.

### Task 5 — Use Dynamic Blocks for NSG Rules

Refactor the NSG to use a dynamic block instead of hardcoded security_rule
blocks. Store the rule definitions in a local map variable.

---

## 20. Common Mistakes in This Project

### Mistake 1 — SSH key file not found

```
Error: Error reading file: open ~/.ssh/id_rsa.pub: no such file or directory
```

**PowerShell fix:**
```powershell
# Create SSH key if it doesn't exist
if (-not (Test-Path "$HOME\.ssh\id_rsa.pub")) {
  ssh-keygen -t rsa -b 4096 -f "$HOME\.ssh\id_rsa" -N '""'
}
```

---

### Mistake 2 — `random` provider not initialised

```
Error: Required plugins are not installed
  - hashicorp/random ~> 3.0
```

**Fix:**
```powershell
terraform init -upgrade
```

---

### Mistake 3 — `user_data.sh` file not found

```
Error: Error reading file user_data.sh: no such file or directory
```

**Fix:** Make sure `user_data.sh` exists in the same folder as your `.tf` files.

```powershell
Get-ChildItem *.sh   # should show user_data.sh
```

---

### Mistake 4 — App not accessible immediately after apply

The VMs need ~2 minutes to boot, run the user data script, and start Apache.
If you get a connection refused or timeout, wait 2 minutes and try again.

```powershell
# Wait for app to be ready
$url = terraform output -raw app_url
$maxAttempts = 20
for ($i = 1; $i -le $maxAttempts; $i++) {
  try {
    $response = Invoke-WebRequest -Uri $url -TimeoutSec 5
    Write-Host "App is ready! Status: $($response.StatusCode)"
    break
  } catch {
    Write-Host "Attempt $i/$maxAttempts - waiting 15 seconds..."
    Start-Sleep -Seconds 15
  }
}
```

---

### Mistake 5 — Forgetting to destroy (cost warning!)

This project creates real Azure resources:
- 3 Virtual Machines (Standard_D2s_v3)
- 2 Public IP addresses
- 1 Load Balancer
- 1 NAT Gateway

**These WILL be billed by the hour. Always destroy when done:**

```powershell
terraform destroy --auto-approve
```

---

## 21. Cleanup — Always Destroy When Done

```powershell
# Destroy all resources created by this Terraform
terraform destroy --auto-approve

# Verify nothing remains (should show empty resource group or not found)
az resource list --resource-group "day14-rg" --output table
# If resource group deleted: "ERROR: ResourceGroupNotFound"

# Clear credentials
Remove-Item Env:ARM_CLIENT_ID
Remove-Item Env:ARM_CLIENT_SECRET
Remove-Item Env:ARM_TENANT_ID
Remove-Item Env:ARM_SUBSCRIPTION_ID
```

---

## 22. Complete Architecture Cheat Sheet

```
╔══════════════════════════════════════════════════════════════════════════════╗
║          DAY 14 MINI PROJECT — ARCHITECTURE QUICK REFERENCE                  ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  TRAFFIC FLOW                                                                ║
║                                                                              ║
║  User Browser                                                                ║
║      ↓ HTTP port 80                                                          ║
║  Public IP (lb-pip) — Static, zone-redundant, has DNS name                  ║
║      ↓                                                                       ║
║  Load Balancer — distributes traffic to healthy VMs                         ║
║      ↓ Health Probe checks each VM on port 80 every 5 seconds               ║
║  Backend Pool — list of VMSS instances                                       ║
║      ↓                                                                       ║
║  VMSS (3 VMs in zones 1,2,3) — runs Apache + PHP app                       ║
║      ↕ outbound internet                                                     ║
║  NAT Gateway → NAT Public IP → Internet (for apt-get, downloads)           ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  AUTO-SCALING RULES                                                          ║
║                                                                              ║
║  Default: 3 VMs   Minimum: 1 VM   Maximum: 10 VMs                          ║
║  Scale OUT: avg CPU > 80% for 5 min → add 1 VM (cooldown: 5 min)           ║
║  Scale IN:  avg CPU < 10% for 5 min → remove 1 VM (cooldown: 5 min)        ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  NSG RULES (hardened version)                                                ║
║                                                                              ║
║  Priority 100: Allow HTTP port 80  from AzureLoadBalancer                   ║
║  Priority 110: Allow HTTPS port 443 from AzureLoadBalancer                  ║
║  Priority 120: Allow SSH port 22   from YOUR_IP/32                          ║
║  Priority 4096: Deny all other inbound traffic                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  KEY TERRAFORM CONCEPTS USED IN THIS PROJECT                                 ║
║                                                                              ║
║  filebase64()          → encodes user_data.sh for VMSS custom_data          ║
║  random_pet            → generates unique DNS name suffix                   ║
║  lookup()              → selects VM size from map by environment            ║
║  timestamp()           → adds modified_on tag to all resources              ║
║  lifecycle ignore_changes = [instances] → lets auto-scale manage count      ║
║  implicit dependencies  → resources reference each other (no depends_on)   ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  POWERSHELL WORKFLOW                                                         ║
║                                                                              ║
║  terraform init          → download azurerm + random providers              ║
║  terraform plan          → expect 18 resources to add                       ║
║  terraform apply --auto-approve → takes 3-5 minutes                        ║
║  terraform output app_url → get the URL to open in browser                 ║
║  terraform destroy --auto-approve → ALWAYS DO THIS when done               ║
║                                                                              ║
║  ⚠️  This project costs real money per hour — DESTROY WHEN DONE            ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

---

## The Core Mental Model for This Video

```
The project builds a COMPLETE web hosting platform from scratch:

LAYER 1 — NETWORK BOUNDARY
  VNet + Subnet = your private data centre floor
  NSG = the security guard at the entrance

LAYER 2 — EDGE
  Public IP = your street address (what the internet knows)
  Load Balancer = the receptionist who routes visitors

LAYER 3 — COMPUTE
  VMSS = a self-managing team of identical workers
  Each VM boots, installs the app, and joins the team automatically

LAYER 4 — OUTBOUND ACCESS
  NAT Gateway = the private exit door for VMs to reach the internet
  (they can leave, but no one can enter through that door)

LAYER 5 — INTELLIGENCE
  Auto-scaling = the manager who hires/fires workers based on workload
  Health probe = the supervisor who checks each worker is functioning

The key insight: Each layer solves ONE problem.
Terraform lets you define all 5 layers as code,
deploy them in the right order automatically,
and tear them all down with one command.
```

---

*Guide covers: Azure VMSS, Virtual Machine Scale Set, orchestrated VMSS,
azurerm_orchestrated_virtual_machine_scale_set, Load Balancer, azurerm_lb,
backend address pool, azurerm_lb_backend_address_pool, health probe,
azurerm_lb_probe, load balancer rules, azurerm_lb_rule, NAT Gateway,
azurerm_nat_gateway, NAT gateway associations, public IP addresses static
allocation, zone-redundant resources, NSG security rules, AzureLoadBalancer
service tag, subnet NSG association, auto-scaling, azurerm_monitor_autoscale_setting,
scale out and scale in rules, CPU percentage threshold, time grain and time
window, ISO 8601 duration format PT5M, lifecycle ignore_changes instances,
custom_data filebase64, user_data.sh startup script, random_pet provider,
domain_name_label, path.module, lookup function for VM size mapping,
timestamp formatdate for tags, implicit dependencies in multi-resource projects,
PowerShell ssh-keygen, azure CLI verification commands.*
