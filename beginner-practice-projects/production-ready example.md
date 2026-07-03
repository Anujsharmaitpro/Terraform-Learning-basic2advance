# Comprehensive Azure Terraform Functions Implementation Example

This document demonstrates a practical, single-file deployment blueprint (`main.tf`) that showcases how to chain and implement various Terraform functions within a real-world Azure infrastructure scenario. 

### Scenario Breakdown
We are deploying a standardized, high-availability enterprise environment including:
1.  **Resource Group & Tags:** Standardized naming conventions and automated deployment timestamps.
2.  **Dynamic Networking:** Calculating a multi-subnet architecture from a single address space while protecting Azure's reserved IPs.
3.  **Compute Scale Set:** Calculating auto-scale baselines, managing safety caps, and rendering compressed custom bash init scripts.
4.  **Security & Identity:** Safeguarding sensitive database credentials and generating unique auditing signatures.

---

## The `main.tf` Blueprint

```hcl
# ==========================================
# 1. VARIABLES & LOCAL VARIABLES (String & Filesystem Functions)
# ==========================================
variable "environment_tier" {
  type        = string
  default     = "  Production-Environment  "
}

variable "company_prefix" {
  type        = string
  default     = "superlongcorporatenameanalytics"
}

variable "base_cidr" {
  type        = string
  default     = "10.100.0.0/16"
}

variable "requested_node_count" {
  type        = number
  default     = 2
}

locals {
  # Clean up messy inputs using trimspace and convert to uppercase for official tags
  env_clean = trimspace(var.environment_tier)
  env_tag   = upper(local.env_clean)
  
  # Azure Storage/Compute names must fit standard limits. Slice the prefix safely down to 15 chars.
  safe_prefix = substr(lower(var.company_prefix), 0, 15)

  # Systematically build a compliant resource group name
  rg_name = format("rg-%s-%s-01", local.safe_prefix, lower(substr(local.env_clean, 0, 4)))

  # Build unique tracking fingerprints using crypto hashing
  deployment_signature = sha256(local.rg_name)

  # Merge global enterprise tagging requirements with dynamic runtime execution metrics
  mandatory_tags = merge(
    {
      Environment = local.env_tag
      Signature   = local.deployment_signature
      CreatedOn   = formatdate("YYYY-MM-DD", timestamp())
    },
    {
      BillingCode = "IT-INFRA-2026"
    }
  )
}

# ==========================================
# 2. CORE INFRASTRUCTURE (Type Conversion & Date Functions)
# ==========================================
resource "azurerm_resource_group" "rg" {
  name     = local.rg_name
  location = "eastus2"
  tags     = local.mandatory_tags
}

# ==========================================
# 3. DYNAMIC NETWORKING (IP Network & Collection Functions)
# ==========================================
resource "azurerm_virtual_network" "vnet" {
  name                = "${local.safe_prefix}-vnet"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = [var.base_cidr]
  tags                = azurerm_resource_group.rg.tags
}

locals {
  # Dynamically calculate consecutive subnet masks out of the parent network block
  # Carves out two /24 blocks for Web and App tiers, and a /27 for Bastion
  subnet_allocations = cidrsubnets(var.base_cidr, 8, 8, 11)
}

resource "azurerm_subnet" "web" {
  name                 = "snet-web"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [element(local.subnet_allocations, 0)] # Pulls first index
}

resource "azurerm_subnet" "app" {
  name                 = "snet-app"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [element(local.subnet_allocations, 1)] # Pulls second index
}

locals {
  # Azure reserves the first four IP addresses (.0, .1, .2, .3) in every subnet.
  # Pinpoint the absolute first usable host IP for our private gateway device safely.
  gateway_private_ip = cidrhost(element(azurerm_subnet.app.address_prefixes, 0), 4)
}

# ==========================================
# 4. COMPUTE & SCALING (Numeric, Encoding, & Filesystem Functions)
# ==========================================
locals {
  # Ensure the cluster node count matches high-availability standards (min 3)
  # but never exceeds total infrastructure scaling thresholds (max 10)
  final_node_count = min(10, max(3, var.requested_node_count))

  # Safely check if a local deployment payload file exists prior to bootstrapping
  has_custom_init = fileexists("${path.module}/scripts/init.sh")
  
  # Pull a configuration template file, dynamically parsing variables straight into it
  raw_payload = templatefile("${path.module}/templates/bootstrap.tftpl", {
    admin_user = "azureuser"
    gateway_ip = local.gateway_private_ip
  })

  # Compress payload into Base64 Gzip format required by Azure Linux Scale Sets custom data
  custom_data_payload = base64gzip(local.raw_payload)
}

resource "azurerm_linux_virtual_machine_scale_set" "vmss" {
  name                = "${local.safe_prefix}-vmss"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Standard_D2s_v5"
  instances           = local.final_node_count
  admin_username      = "azureuser"

  admin_ssh_key {
    username   = "azureuser"
    # Clean up trailing newlines out of localized public keys using chomp
    public_key = chomp(file("${path.module}/keys/id_rsa.pub"))
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  network_interface {
    name    = "nic-vmss"
    primary = true

    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = azurerm_subnet.web.id
    }
  }

  custom_data = local.custom_data_payload
}

# ==========================================
# 5. DATA SECURITY & OUTPUTS (Type Conversion & Error Handling Functions)
# ==========================================
variable "db_password_input" {
  type        = string
  default     = "SuperSecretPa$$word123"
  sensitive   = true
}

locals {
  # Explicitly force conversion of primitive sensitive strings to avoid configuration exposure
  db_password = sensitive(tostring(var.db_password_input))

  # Build a fail-safe fallback string for non-critical logging if structural data items are missing
  fallback_status = try(azurerm_linux_virtual_machine_scale_set.vmss.name, "Deployment-In-Progress")
}

output "summary" {
  value = {
    # Check if a deployment criteria evaluates cleanly to a flat boolean flag
    is_prod_sku     = can(regex("Standard", azurerm_linux_virtual_machine_scale_set.vmss.sku))
    
    # Expose the public/private cluster mapping metrics inside clean outputs
    scale_set_name  = local.fallback_status
    gateway_routing = local.gateway_private_ip
    
    # Strip sensitive shields down only on totally safe non-identifiable structures
    network_space   = nonsensitive(one(azurerm_virtual_network.vnet.address_space))
  }
}