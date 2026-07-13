# Terraform Data Sources — Read Existing Azure Infrastructure
## Deep-Dive Learning Guide — Day 13 / 28 Days of Easy Terraform
### Beginner-First Edition | Azure VM + Shared Network Examples | PowerShell Throughout

---

## Before You Start

This is Day 13. By now you know:
- Day 1–6: Fundamentals, providers, resources, state, variables, file structure
- Day 7–9: Type constraints, count/for_each, lifecycle
- Day 10–12: Dynamic blocks, expressions, functions

Today is about **data sources** — one of the most important and most
misunderstood concepts in Terraform. It is the answer to the question:
"What do I do when I need to USE a resource that already exists, but
I didn't create it with my Terraform code?"

By the end of this guide you will understand:
- WHY data sources exist (the real enterprise problem they solve)
- WHAT a data source actually is
- HOW to write data blocks for Azure resources
- HOW to chain data sources together using references
- HOW to use data sources inside resource blocks

---

## Table of Contents

1. The Real-World Problem — Shared Infrastructure in Enterprises
2. What Is a Data Source? (Plain English)
3. Data Source vs Resource — The Critical Distinction
4. When Do You Use a Data Source?
5. Data Source Syntax — Anatomy of a `data` Block
6. Chaining Data Sources — Using One Data Source Inside Another
7. Available Azure Data Sources — Where to Find Them
8. The Demo Scenario — Creating a VM in a Shared Network
9. Step 1 — Pre-existing Shared Network Infrastructure
10. Step 2 — Writing Data Sources for Existing Resources
11. Step 3 — Using Data Source Attributes in Resource Blocks
12. Step 4 — Running the Plan and Apply
13. Verifying the Result in Azure Portal
14. The Complete Working Code — All Files
15. Common Mistakes Beginners Make
16. Practice Exercises
17. Complete Cheat Sheet

---

## 1. The Real-World Problem — Shared Infrastructure in Enterprises

### The scenario that makes data sources necessary

Imagine you've just joined a company as a DevOps engineer. The company
has already set up Azure infrastructure. There's a networking team that
owns and manages all Virtual Networks and Subnets.

```
THE EXISTING SHARED INFRASTRUCTURE (managed by Network Team):
─────────────────────────────────────────────────────────────
  Resource Group:   shared-network-rg
  Virtual Network:  shared-network-vnet
  Subnets:
    subnet-1  → Dev environment
    subnet-2  → Test environment
    subnet-3  → Staging environment
    subnet-4  → Production environment
    subnet-5  → Development team
    subnet-6  → DevOps team        ← YOU will use this
─────────────────────────────────────────────────────────────
```

Your task: provision a Virtual Machine for your team's POC work. The VM
must go into the DevOps team's subnet (`subnet-6`) inside the shared network.

### The problem with the naive approach

You might think: "Easy, I'll just create a new VNet and subnet in my
Terraform code."

**Why you can't do that:**

1. **Security** — The network team controls IP address spaces to prevent
   conflicts. Two VNets with overlapping CIDRs can't be peered.

2. **Compliance** — Your organization may require ALL subnets to go through
   the network team's review for firewall rules, NSG policies, etc.

3. **Cost** — You don't need another VNet. One already exists. Creating
   duplicates wastes money.

4. **Governance** — The network team might have specific naming conventions,
   tagging requirements, and routing configurations that only they set up.

### The question data sources answer

```
"How do I reference the subnet-6 that the network team created,
without creating my own subnet and without hardcoding the subnet's ID?"
```

Answer: **Terraform Data Sources.**

---

## 2. What Is a Data Source? (Plain English)

### The one-sentence definition

A **data source** lets Terraform READ information about a resource that
already exists in Azure — without CREATING, MODIFYING, or DESTROYING it.

### The library book analogy

Think of it this way:

- A **resource block** is like BUYING a book — Terraform creates the book,
  owns it, and manages it. If you delete the resource block, Terraform
  deletes the book.

- A **data block** is like CHECKING OUT a library book — Terraform reads
  the book's information (title, author, ISBN), uses that information,
  but never claims ownership of the book. If you delete the data block,
  the book stays in the library untouched.

```
resource "azurerm_subnet" "mine" { ... }   ← I CREATE and OWN this subnet
data "azurerm_subnet" "theirs" { ... }     ← I READ information about their subnet
```

### What a data source does technically

When Terraform encounters a `data` block:
1. During `terraform plan` or `terraform apply`, it makes a READ-ONLY
   API call to Azure
2. Azure returns all the attributes of that resource (ID, name, location,
   address prefix, etc.)
3. Terraform stores those values in memory
4. You can reference those values anywhere in your configuration

**No resources are created. No resources are modified. No resources are destroyed.**

---

## 3. Data Source vs Resource — The Critical Distinction

| | `resource` block | `data` block |
|---|---|---|
| Keyword | `resource` | `data` |
| Creates infrastructure? | ✅ Yes | ❌ No |
| Modifies infrastructure? | ✅ Yes | ❌ No |
| Destroys infrastructure? | ✅ Yes | ❌ No |
| Reads infrastructure? | ✅ Yes | ✅ Yes |
| Tracked in state file? | ✅ Yes (as managed) | ✅ Yes (as read-only) |
| Appears in `terraform plan` | ✅ Yes | 🔵 As a "read" operation |
| Owned by Terraform? | ✅ Yes | ❌ No |

### The address syntax difference

```hcl
# Resource — you create it, you reference it as:
resource "azurerm_subnet" "my_subnet" { ... }
# Reference: azurerm_subnet.my_subnet.id

# Data source — it already exists, you reference it as:
data "azurerm_subnet" "shared_subnet" { ... }
# Reference: data.azurerm_subnet.shared_subnet.id
#            ↑
#            Always starts with "data."
```

**Important:** Data source references ALWAYS start with `data.` followed
by the resource type and local name. This distinguishes them from
resource references.

---

## 4. When Do You Use a Data Source?

Use a data source when:

```
✅ The resource was created outside your Terraform configuration
   (by another team, manually, or by a different Terraform project)

✅ You need information about a resource that you don't manage
   (shared VNet, shared subnet, existing Key Vault, shared DNS zone)

✅ You need dynamic information at apply time
   (current Azure region's resource SKUs, available VM sizes)

✅ You want to look up a resource by name without hardcoding its ID
   (IDs are long and change between environments)

✅ Multiple teams share infrastructure but manage their own workloads
   (network team owns VNet, app team owns VMs inside that VNet)
```

Do NOT use a data source when:

```
❌ You want Terraform to create, manage, and own the resource
   → Use a resource block

❌ You want to pass values between different parts of your OWN Terraform code
   → Use locals, variables, or direct resource references
```

---

## 5. Data Source Syntax — Anatomy of a `data` Block

### The complete syntax

```hcl
data "resource_type" "local_name" {
  # Filter arguments — how to find the right resource
  name                = "exact-resource-name-in-azure"
  resource_group_name = "the-resource-group-it-lives-in"
  # (other identifying fields specific to this resource type)
}
```

### Every part explained

**`data`** — the keyword. Always lowercase. Signals this is a read-only operation.

**`"resource_type"`** — exactly the same types you use for resources.
`azurerm_virtual_network`, `azurerm_subnet`, `azurerm_resource_group`, etc.

**`"local_name"`** — your nickname for this data source. Used in references.
You choose this. Convention: descriptive names like `"shared"`, `"existing"`.

**Filter arguments** — enough information for Azure to identify the unique
resource you want. Usually `name` + `resource_group_name`.

### The reference syntax

After declaring a data source, you reference its attributes using:

```hcl
data.<resource_type>.<local_name>.<attribute>
```

Examples:
```hcl
data.azurerm_resource_group.shared.location   # the location of the RG
data.azurerm_virtual_network.vnet.name        # the VNet's name
data.azurerm_subnet.subnet.id                 # the subnet's Azure resource ID
```

---

## 6. Chaining Data Sources — Using One Data Source Inside Another

This is a powerful technique the instructor demonstrated. When multiple
resources depend on each other, you can chain their data sources together
— using one data source's output as input to the next.

### The chain for the demo

```
azurerm_resource_group (data)
  └── provides: .name, .location
      ↓
azurerm_virtual_network (data)
  └── needs: resource_group_name ← from resource_group.name
  └── provides: .name, .id
      ↓
azurerm_subnet (data)
  └── needs: resource_group_name ← from resource_group.name
  └── needs: virtual_network_name ← from virtual_network.name
  └── provides: .id, .address_prefix
```

### The code for the chain

```hcl
# Level 1 — Read the Resource Group
data "azurerm_resource_group" "rg_shared" {
  name = "shared-network-rg"
  # Only needs the name — resource groups have no parent
}

# Level 2 — Read the Virtual Network
# Uses the RG data source output for resource_group_name
data "azurerm_virtual_network" "vnet_shared" {
  name                = "shared-network-vnet"
  resource_group_name = data.azurerm_resource_group.rg_shared.name
  #                     ↑ References Level 1 output — no hardcoding!
}

# Level 3 — Read the Subnet
# Uses both Level 1 and Level 2 outputs
data "azurerm_subnet" "subnet_shared" {
  name                 = "shared-primary-sn"
  resource_group_name  = data.azurerm_resource_group.rg_shared.name
  #                      ↑ References Level 1
  virtual_network_name = data.azurerm_virtual_network.vnet_shared.name
  #                      ↑ References Level 2
}
```

### Why chain instead of hardcode?

```hcl
# ❌ FRAGILE — hardcoded values
data "azurerm_subnet" "subnet_shared" {
  name                 = "shared-primary-sn"
  resource_group_name  = "shared-network-rg"     # hardcoded
  virtual_network_name = "shared-network-vnet"   # hardcoded
}

# ✅ ROBUST — dynamic references
data "azurerm_subnet" "subnet_shared" {
  name                 = "shared-primary-sn"
  resource_group_name  = data.azurerm_resource_group.rg_shared.name    # dynamic
  virtual_network_name = data.azurerm_virtual_network.vnet_shared.name  # dynamic
}
```

The chained version is more maintainable. If the RG name ever changes,
you update only the first data source — all downstream references automatically
pick up the new name.

---

## 7. Available Azure Data Sources — Where to Find Them

Every Azure resource type that has a `resource` block also has a corresponding
`data` block. The naming is identical — just replace `resource` with `data`.

### How to find data source documentation

```
Terraform Registry:
https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs

→ Click "Data Sources" in the left navigation
→ Find the resource type you need
→ See required arguments and available attributes
```

### Common Azure data sources you'll use regularly

```hcl
# Read an existing Resource Group
data "azurerm_resource_group" "example" {
  name = "my-existing-rg"
}

# Read an existing Virtual Network
data "azurerm_virtual_network" "example" {
  name                = "my-existing-vnet"
  resource_group_name = "my-existing-rg"
}

# Read an existing Subnet
data "azurerm_subnet" "example" {
  name                 = "my-existing-subnet"
  virtual_network_name = "my-existing-vnet"
  resource_group_name  = "my-existing-rg"
}

# Read an existing Key Vault
data "azurerm_key_vault" "example" {
  name                = "my-existing-kv"
  resource_group_name = "my-existing-rg"
}

# Read an existing Storage Account
data "azurerm_storage_account" "example" {
  name                = "myexistingstorageaccount"
  resource_group_name = "my-existing-rg"
}

# Read a specific VM image
data "azurerm_platform_image" "example" {
  location  = "East US"
  publisher = "Canonical"
  offer     = "UbuntuServer"
  sku       = "18.04-LTS"
}

# Read your current Azure subscription
data "azurerm_subscription" "current" {}

# Read your current Azure client configuration (tenant, subscription IDs)
data "azurerm_client_config" "current" {}
```

### The `data "azurerm_client_config"` special case

This data source takes NO arguments — it returns information about the
currently authenticated Azure account:

```hcl
data "azurerm_client_config" "current" {}

# Access values:
data.azurerm_client_config.current.tenant_id        # your Azure AD tenant
data.azurerm_client_config.current.subscription_id  # your subscription
data.azurerm_client_config.current.object_id        # the authenticated user's ID
```

This is extremely useful for Key Vault access policies and RBAC assignments.

---

## 8. The Demo Scenario — Creating a VM in a Shared Network

### What the instructor built

```
ALREADY EXISTS (network team manages this):
─────────────────────────────────────────────────────────────
  Resource Group:   shared-network-rg        (location: Canada Central)
  Virtual Network:  shared-network-vnet
  Subnet:           shared-primary-sn
─────────────────────────────────────────────────────────────

YOUR TERRAFORM CODE CREATES:
─────────────────────────────────────────────────────────────
  Resource Group:   day13-rg                 (NEW — yours)
  Network Interface: day13-nic               (NEW — yours)
  Virtual Machine:   day13-vm                (NEW — yours)
─────────────────────────────────────────────────────────────

THE KEY POINT:
  Your VM exists in YOUR resource group
  BUT is connected to the SHARED network team's subnet
  Your Terraform didn't create the VNet or subnet
  It only READS them via data sources
─────────────────────────────────────────────────────────────
```

After `terraform apply`:
- The VM appears in YOUR resource group
- The VM's network interface is attached to `shared-primary-sn`
- The network team's infrastructure is UNTOUCHED

This is exactly the enterprise pattern the instructor described.

---

## 9. Step 1 — Pre-existing Shared Network Infrastructure

Before running your Terraform, the network team's infrastructure must
already exist. The instructor created it manually in the Azure Portal.

**PowerShell — create the shared infrastructure (simulating the network team):**

```powershell
# Authenticate
az login

# Create the shared Resource Group
az group create `
  --name "shared-network-rg" `
  --location "canadacentral"

# Create the shared Virtual Network
az network vnet create `
  --name "shared-network-vnet" `
  --resource-group "shared-network-rg" `
  --location "canadacentral" `
  --address-prefix "10.0.0.0/16"

# Create the shared Subnet
az network vnet subnet create `
  --name "shared-primary-sn" `
  --resource-group "shared-network-rg" `
  --vnet-name "shared-network-vnet" `
  --address-prefix "10.0.1.0/24"
```

**Verify it exists:**
```powershell
az group show --name "shared-network-rg" --query "name" -o tsv
az network vnet show --name "shared-network-vnet" --resource-group "shared-network-rg" --query "name" -o tsv
az network vnet subnet show --name "shared-primary-sn" --vnet-name "shared-network-vnet" --resource-group "shared-network-rg" --query "name" -o tsv
```

All three should return their names without error.

---

## 10. Step 2 — Writing Data Sources for Existing Resources

Create a new file `data.tf` in your Day 13 project folder:

**`data.tf`**
```hcl
# ─── DATA SOURCE 1: The Shared Resource Group ──────────────────────────────
# Reads the existing resource group managed by the network team
# Only needs the name — resource groups are at subscription level
data "azurerm_resource_group" "rg_shared" {
  name = "shared-network-rg"
  # After this, we can access:
  # data.azurerm_resource_group.rg_shared.location  → "canadacentral"
  # data.azurerm_resource_group.rg_shared.name      → "shared-network-rg"
  # data.azurerm_resource_group.rg_shared.id        → full Azure resource ID
}

# ─── DATA SOURCE 2: The Shared Virtual Network ─────────────────────────────
# Reads the existing VNet managed by the network team
# Uses the RG data source for resource_group_name — no hardcoding
data "azurerm_virtual_network" "vnet_shared" {
  name                = "shared-network-vnet"
  resource_group_name = data.azurerm_resource_group.rg_shared.name
  # ↑ Takes "shared-network-rg" from the data source above — chaining!
}

# ─── DATA SOURCE 3: The Shared Subnet ──────────────────────────────────────
# Reads the specific subnet we'll use for our VM
# Needs both RG name and VNet name — chain from previous data sources
data "azurerm_subnet" "subnet_shared" {
  name                 = "shared-primary-sn"
  resource_group_name  = data.azurerm_resource_group.rg_shared.name
  virtual_network_name = data.azurerm_virtual_network.vnet_shared.name
  # ↑ Takes from vnet_shared data source — full chain!
  # After this, we can use:
  # data.azurerm_subnet.subnet_shared.id  → the subnet's Azure resource ID
  #                                          (needed for network_interface)
}
```

### What attributes are available after reading?

Once a data source is declared, Terraform reads the resource and makes
ALL of its attributes available. For a subnet, this includes:

```hcl
data.azurerm_subnet.subnet_shared.id
data.azurerm_subnet.subnet_shared.name
data.azurerm_subnet.subnet_shared.resource_group_name
data.azurerm_subnet.subnet_shared.virtual_network_name
data.azurerm_subnet.subnet_shared.address_prefix
data.azurerm_subnet.subnet_shared.address_prefixes
# ... and more
```

---

## 11. Step 3 — Using Data Source Attributes in Resource Blocks

Now that the data sources are declared, use their outputs in your own
resource blocks.

**`main.tf`**
```hcl
# ─── YOUR RESOURCE GROUP ──────────────────────────────────────────────────
# This is YOUR resource group — Terraform creates and manages it
resource "azurerm_resource_group" "rg" {
  name = "${var.prefix}-rg"

  # Use the SAME location as the shared network's resource group
  # → data source provides the location dynamically
  location = data.azurerm_resource_group.rg_shared.location
  # ↑ "canadacentral" — read from the shared RG data source
}

# ─── YOUR NETWORK INTERFACE ────────────────────────────────────────────────
# Connects your VM to the shared subnet
resource "azurerm_network_interface" "nic" {
  name                = "${var.prefix}-nic"
  location            = data.azurerm_resource_group.rg_shared.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.subnet_shared.id
    # ↑ THIS IS THE KEY — connecting to the shared subnet via data source!
    private_ip_address_allocation = "Dynamic"
  }
}

# ─── YOUR VIRTUAL MACHINE ──────────────────────────────────────────────────
# Created in YOUR resource group, connected to SHARED network
resource "azurerm_linux_virtual_machine" "vm" {
  name                = "${var.prefix}-vm"
  resource_group_name = azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg_shared.location
  size                = "Standard_D2s_v3"
  admin_username      = "adminuser"
  admin_password      = "P@ssword1234!"

  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.nic.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}
```

### The flow of information

```
data.azurerm_resource_group.rg_shared.location
  └── Used for: azurerm_resource_group.rg.location
  └── Used for: azurerm_network_interface.nic.location
  └── Used for: azurerm_linux_virtual_machine.vm.location

data.azurerm_subnet.subnet_shared.id
  └── Used for: azurerm_network_interface.nic → ip_configuration → subnet_id
      └── This connects the VM to the shared subnet
```

---

## 12. Step 4 — Running the Plan and Apply

**PowerShell:**

```powershell
# Navigate to Day 13 project
Set-Location "C:\projects\day13"

# Set Azure authentication
$env:ARM_CLIENT_ID       = "your-client-id"
$env:ARM_CLIENT_SECRET   = "your-client-secret"
$env:ARM_TENANT_ID       = "your-tenant-id"
$env:ARM_SUBSCRIPTION_ID = "your-subscription-id"

# Initialise
terraform init

# Validate syntax
terraform validate

# Preview — note what will be CREATED vs READ
terraform plan
```

### What `terraform plan` shows with data sources

```
data.azurerm_resource_group.rg_shared: Reading...     ← DATA SOURCE
data.azurerm_resource_group.rg_shared: Read complete after 1s

data.azurerm_virtual_network.vnet_shared: Reading...  ← DATA SOURCE
data.azurerm_virtual_network.vnet_shared: Read complete after 1s

data.azurerm_subnet.subnet_shared: Reading...         ← DATA SOURCE
data.azurerm_subnet.subnet_shared: Read complete after 1s

Terraform will perform the following actions:

  # azurerm_resource_group.rg will be created  ← RESOURCE (creates)
  + resource "azurerm_resource_group" "rg" {
      + location = "canadacentral"
      + name     = "day13-rg"
    }

  # azurerm_network_interface.nic will be created  ← RESOURCE (creates)
  + resource "azurerm_network_interface" "nic" {
      + name = "day13-nic"
      ...
    }

  # azurerm_linux_virtual_machine.vm will be created  ← RESOURCE (creates)
  + resource "azurerm_linux_virtual_machine" "vm" {
      + name = "day13-vm"
      ...
    }

Plan: 3 to add, 0 to change, 0 to destroy.
```

**Key observation:** Data sources show as "Reading..." — they are NOT
in the "Plan: N to add" count. They don't add, change, or destroy anything.

**If you see an error like "not found":**
```
Error: Unable to find data source "azurerm_resource_group"
with name "shared-network-rg"
```
This means the resource doesn't exist in Azure. The data source can only
read what's already there. Verify the resource name is exactly correct
(case-sensitive in some scenarios).

### Apply

```powershell
# Apply
terraform apply --auto-approve

# Verify which resources were created vs already existed
terraform state list
```

`terraform state list` output:
```
data.azurerm_resource_group.rg_shared      ← read-only, not owned
data.azurerm_virtual_network.vnet_shared   ← read-only, not owned
data.azurerm_subnet.subnet_shared          ← read-only, not owned
azurerm_resource_group.rg                  ← owned by this Terraform
azurerm_network_interface.nic              ← owned by this Terraform
azurerm_linux_virtual_machine.vm           ← owned by this Terraform
```

### Clean up

```powershell
# Destroy YOUR resources (VNet and subnet are NOT touched)
terraform destroy --auto-approve

# Clear credentials
Remove-Item Env:ARM_CLIENT_ID
Remove-Item Env:ARM_CLIENT_SECRET
Remove-Item Env:ARM_TENANT_ID
Remove-Item Env:ARM_SUBSCRIPTION_ID
```

After `terraform destroy`, only the three data-sourced resources
(`shared-network-rg`, `shared-network-vnet`, `shared-primary-sn`)
remain in Azure. Your three resources are gone.

---

## 13. Verifying the Result in Azure Portal

The instructor verified the VM was correctly connected to the shared subnet
by:

1. Opening Azure Portal
2. Going to Resource Groups → `day13-rg`
3. Clicking on the VM
4. Going to **Networking** → **Network settings**
5. Confirming: Virtual network = `shared-network-vnet`, Subnet = `shared-primary-sn`

This proves the VM exists in your resource group but is connected to the
network team's subnet — exactly the enterprise pattern described at the start.

---

## 14. The Complete Working Code — All Files

**`provider.tf`**
```hcl
terraform {
  required_version = ">= 1.9.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}
```

---

**`variables.tf`**
```hcl
variable "prefix" {
  type        = string
  description = "Prefix for all resource names"
  default     = "day13"
}
```

---

**`data.tf`**
```hcl
# ─── READ existing shared infrastructure (managed by network team) ──────────

# Data Source 1: Shared Resource Group
data "azurerm_resource_group" "rg_shared" {
  name = "shared-network-rg"
}

# Data Source 2: Shared Virtual Network
# Chains from Data Source 1 — no hardcoding of RG name
data "azurerm_virtual_network" "vnet_shared" {
  name                = "shared-network-vnet"
  resource_group_name = data.azurerm_resource_group.rg_shared.name
}

# Data Source 3: Shared Subnet
# Chains from both Data Source 1 and 2
data "azurerm_subnet" "subnet_shared" {
  name                 = "shared-primary-sn"
  resource_group_name  = data.azurerm_resource_group.rg_shared.name
  virtual_network_name = data.azurerm_virtual_network.vnet_shared.name
}
```

---

**`main.tf`**
```hcl
# ─── YOUR Resource Group ─────────────────────────────────────────────────────
# Created and managed by this Terraform configuration
resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-rg"
  location = data.azurerm_resource_group.rg_shared.location
  # Uses the same region as the shared infrastructure
}

# ─── YOUR Network Interface ──────────────────────────────────────────────────
# Bridges your VM to the SHARED subnet
resource "azurerm_network_interface" "nic" {
  name                = "${var.prefix}-nic"
  location            = data.azurerm_resource_group.rg_shared.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.subnet_shared.id
    # ↑ KEY: connects NIC to the shared subnet via data source
    private_ip_address_allocation = "Dynamic"
  }
}

# ─── YOUR Virtual Machine ────────────────────────────────────────────────────
# Lives in your RG, but on the shared network
resource "azurerm_linux_virtual_machine" "vm" {
  name                = "${var.prefix}-vm"
  resource_group_name = azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg_shared.location
  size                = "Standard_D2s_v3"
  admin_username      = "adminuser"
  admin_password      = "P@ssword1234!"

  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.nic.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  tags = {
    Environment = "dev"
    ManagedBy   = "Terraform"
    Team        = "DevOps"
  }
}
```

---

**`outputs.tf`**
```hcl
# Outputs from data sources — proving we read from shared infrastructure
output "shared_vnet_name" {
  description = "The shared VNet name (read via data source)"
  value       = data.azurerm_virtual_network.vnet_shared.name
}

output "shared_subnet_id" {
  description = "The shared subnet ID used by our VM"
  value       = data.azurerm_subnet.subnet_shared.id
}

output "shared_location" {
  description = "Location inherited from shared infrastructure"
  value       = data.azurerm_resource_group.rg_shared.location
}

# Outputs from your created resources
output "vm_name" {
  description = "Name of the created Virtual Machine"
  value       = azurerm_linux_virtual_machine.vm.name
}

output "vm_private_ip" {
  description = "Private IP address assigned to the VM"
  value       = azurerm_network_interface.nic.private_ip_address
}

output "vm_resource_group" {
  description = "Resource group where your VM was created"
  value       = azurerm_resource_group.rg.name
}
```

---

**PowerShell — complete workflow:**

```powershell
# ─── STEP 0: Create the shared infrastructure (do this once, simulates network team)
az login
az group create --name "shared-network-rg" --location "canadacentral"
az network vnet create `
  --name "shared-network-vnet" `
  --resource-group "shared-network-rg" `
  --address-prefix "10.0.0.0/16"
az network vnet subnet create `
  --name "shared-primary-sn" `
  --resource-group "shared-network-rg" `
  --vnet-name "shared-network-vnet" `
  --address-prefix "10.0.1.0/24"

# ─── STEP 1: Navigate to your project
Set-Location "C:\projects\day13"

# ─── STEP 2: Set credentials
$env:ARM_CLIENT_ID       = "your-client-id"
$env:ARM_CLIENT_SECRET   = "your-client-secret"
$env:ARM_TENANT_ID       = "your-tenant-id"
$env:ARM_SUBSCRIPTION_ID = "your-subscription-id"

# ─── STEP 3: Initialise
terraform init

# ─── STEP 4: Validate
terraform validate

# ─── STEP 5: Preview — watch data sources show as "Reading"
terraform plan

# ─── STEP 6: Apply
terraform apply --auto-approve

# ─── STEP 7: Verify what Terraform manages
terraform state list

# ─── STEP 8: Check outputs
terraform output

# ─── STEP 9: Verify VM subnet in portal (optional)
az vm show `
  --name "day13-vm" `
  --resource-group "day13-rg" `
  --query "networkProfile.networkInterfaces[0]" -o tsv

# ─── STEP 10: Clean up YOUR resources (shared infra stays)
terraform destroy --auto-approve

# Verify shared infra still exists
az group show --name "shared-network-rg" --query "name" -o tsv
# Output: "shared-network-rg" ← still exists, untouched by destroy

# ─── STEP 11: Clear credentials
Remove-Item Env:ARM_CLIENT_ID
Remove-Item Env:ARM_CLIENT_SECRET
Remove-Item Env:ARM_TENANT_ID
Remove-Item Env:ARM_SUBSCRIPTION_ID
```

---

## 15. Common Mistakes Beginners Make

### Mistake 1 — Forgetting `data.` prefix when referencing data sources

```hcl
# ❌ WRONG — missing "data." prefix
subnet_id = azurerm_subnet.subnet_shared.id
# Error: No resource "azurerm_subnet.subnet_shared" found

# ✅ CORRECT — include "data." prefix
subnet_id = data.azurerm_subnet.subnet_shared.id
```

---

### Mistake 2 — Providing wrong resource name (case matters!)

```hcl
data "azurerm_virtual_network" "vnet_shared" {
  name = "Shared-Network-Vnet"   # ❌ wrong capitalisation
}
# Error: "Shared-Network-Vnet" was not found
# (Azure resource names are case-insensitive but Terraform may be strict)

data "azurerm_virtual_network" "vnet_shared" {
  name = "shared-network-vnet"   # ✅ matches exactly what's in Azure
}
```

---

### Mistake 3 — Trying to use a data source for a resource that doesn't exist yet

```hcl
# ❌ WRONG — reading a resource that Terraform also creates in the same apply
data "azurerm_resource_group" "my_rg" {
  name = "my-rg"   # doesn't exist yet!
}

resource "azurerm_resource_group" "my_rg" {
  name     = "my-rg"   # creating it here
  location = "East US"
}
```

```
Error: "my-rg" was not found
```

Data sources read what already exists BEFORE the apply runs. If you're
creating AND reading the same resource, use a resource reference instead:

```hcl
# ✅ Reference the resource directly
resource "azurerm_resource_group" "my_rg" {
  name     = "my-rg"
  location = "East US"
}

resource "azurerm_storage_account" "example" {
  resource_group_name = azurerm_resource_group.my_rg.name   # direct reference
}
```

---

### Mistake 4 — Using data source when a resource reference would work

```hcl
# ❌ UNNECESSARY — you created this resource, just reference it directly
resource "azurerm_resource_group" "rg" {
  name     = "my-rg"
  location = "East US"
}

data "azurerm_resource_group" "rg_data" {
  name = "my-rg"   # reading back what you just created
}

resource "azurerm_storage_account" "example" {
  resource_group_name = data.azurerm_resource_group.rg_data.name   # unnecessary!
}

# ✅ CORRECT — use the resource reference directly
resource "azurerm_storage_account" "example" {
  resource_group_name = azurerm_resource_group.rg.name   # simpler and correct
}
```

---

### Mistake 5 — Putting wrong argument for `virtual_network_name`

The instructor's bug in the video:

```hcl
data "azurerm_subnet" "subnet_shared" {
  name                 = "shared-primary-sn"
  resource_group_name  = data.azurerm_resource_group.rg_shared.name
  virtual_network_name = "shared-network-rg"    # ❌ WRONG — that's the RG name!
}
# Error: subnet "shared-primary-sn" was not found

data "azurerm_subnet" "subnet_shared" {
  name                 = "shared-primary-sn"
  resource_group_name  = data.azurerm_resource_group.rg_shared.name
  virtual_network_name = "shared-network-vnet"  # ✅ CORRECT — the VNet name
}
```

---

### Mistake 6 — Expecting `terraform destroy` to delete data-sourced resources

```powershell
terraform destroy --auto-approve
```

```
Terraform will destroy:
  azurerm_linux_virtual_machine.vm
  azurerm_network_interface.nic
  azurerm_resource_group.rg

Data sources (will NOT be destroyed):
  data.azurerm_resource_group.rg_shared
  data.azurerm_virtual_network.vnet_shared
  data.azurerm_subnet.subnet_shared
```

`terraform destroy` ONLY destroys resources you own (declared with `resource`).
Data sources are read-only references — they are never destroyed by Terraform.
This is by design and is the correct behaviour.

---

## 16. Practice Exercises

### Exercise 1 — Identify Data Source vs Resource

For each scenario, should you use a `data` block or a `resource` block?

```
a) Your team needs a new Azure Storage Account
b) Your team's app needs to connect to an existing Key Vault managed by SecOps
c) You need to create a new Resource Group for your project
d) You need the ID of a VNet that a different team created
e) Your VM needs to be created in an existing subnet
f) You need to create a new NSG and apply it to your new subnet
```

**Answers:**
```
a) resource — you're creating new infrastructure
b) data     — reading existing infrastructure owned by another team
c) resource — you're creating it
d) data     — reading, not creating
e) data     — the subnet exists; use data source for its ID
   resource — the VM itself is new; use resource block
f) resource — you're creating both NSG and subnet
```

---

### Exercise 2 — Write the Data Block Chain

You need to read an existing Azure Key Vault named `"kv-platform-prod"`
in resource group `"rg-platform-prod"`. Write all data blocks needed.

**Answer:**
```hcl
# Step 1: Read the Resource Group
data "azurerm_resource_group" "platform" {
  name = "rg-platform-prod"
}

# Step 2: Read the Key Vault
data "azurerm_key_vault" "platform_kv" {
  name                = "kv-platform-prod"
  resource_group_name = data.azurerm_resource_group.platform.name
  # ↑ Chained from Step 1 — no hardcoding
}

# Use it in a resource:
# resource "azurerm_key_vault_secret" "my_secret" {
#   key_vault_id = data.azurerm_key_vault.platform_kv.id
#   ...
# }
```

---

### Exercise 3 — Fix the Reference Error

```hcl
data "azurerm_subnet" "shared" {
  name                 = "app-subnet"
  resource_group_name  = "network-rg"
  virtual_network_name = "app-vnet"
}

resource "azurerm_network_interface" "nic" {
  ip_configuration {
    subnet_id = azurerm_subnet.shared.id    # ← What's wrong here?
  }
}
```

**Answer:**
```hcl
resource "azurerm_network_interface" "nic" {
  ip_configuration {
    subnet_id = data.azurerm_subnet.shared.id   # Fixed: added "data." prefix
  }
}
```

---

### Exercise 4 — Predict the Plan Output

You have this configuration. What will `terraform plan` show?

```hcl
data "azurerm_resource_group" "existing" { name = "my-existing-rg" }
resource "azurerm_resource_group" "new" { name = "my-new-rg"; location = "East US" }
```

**Answer:**
```
data.azurerm_resource_group.existing: Reading...
data.azurerm_resource_group.existing: Read complete after 1s

Terraform will perform the following actions:

  # azurerm_resource_group.new will be created
  + resource "azurerm_resource_group" "new" { ... }

Plan: 1 to add, 0 to change, 0 to destroy.

Explanation:
- Data source "existing" shows as "Reading..." — no plan entry
- Resource "new" shows as "+ will be created" — in the plan count
```

---

## 17. Complete Cheat Sheet

```
╔══════════════════════════════════════════════════════════════════════════════╗
║              TERRAFORM DATA SOURCES — DAY 13 QUICK REFERENCE                ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  WHAT IS A DATA SOURCE?                                                      ║
║  A read-only reference to existing infrastructure                           ║
║  Does NOT create, modify, or destroy resources                              ║
║  Reads Azure and returns all attributes of the matching resource            ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  SYNTAX                                                                      ║
║                                                                              ║
║  data "azurerm_subnet" "my_label" {                                          ║
║    name                 = "exact-subnet-name"                               ║
║    resource_group_name  = "its-resource-group"                              ║
║    virtual_network_name = "its-vnet-name"                                   ║
║  }                                                                           ║
║                                                                              ║
║  Reference: data.azurerm_subnet.my_label.id                                 ║
║             ↑                              ↑                                ║
║             always starts with "data."    any attribute                     ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  DATA SOURCE vs RESOURCE                                                     ║
║                                                                              ║
║  resource → Creates & owns infrastructure                                   ║
║  data     → Reads existing infrastructure (no ownership)                    ║
║                                                                              ║
║  Reference: azurerm_subnet.mine.id        (resource — no "data." prefix)    ║
║  Reference: data.azurerm_subnet.theirs.id (data source — "data." prefix)   ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  CHAINING DATA SOURCES                                                       ║
║                                                                              ║
║  data "azurerm_resource_group" "rg" { name = "shared-rg" }                  ║
║  data "azurerm_virtual_network" "vnet" {                                    ║
║    name                = "shared-vnet"                                      ║
║    resource_group_name = data.azurerm_resource_group.rg.name  ← chain      ║
║  }                                                                           ║
║  data "azurerm_subnet" "sn" {                                               ║
║    name                 = "shared-sn"                                       ║
║    resource_group_name  = data.azurerm_resource_group.rg.name   ← chain    ║
║    virtual_network_name = data.azurerm_virtual_network.vnet.name ← chain   ║
║  }                                                                           ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  WHAT terraform plan SHOWS                                                   ║
║                                                                              ║
║  data.azurerm_subnet.shared: Reading...    ← data source (no plan entry)   ║
║  data.azurerm_subnet.shared: Read complete                                  ║
║                                                                              ║
║  # azurerm_linux_virtual_machine.vm will be created  ← resource (in plan)  ║
║  Plan: 3 to add, 0 to change, 0 to destroy.                                 ║
║                                                                              ║
║  Data sources are NOT counted in "to add" — they add nothing               ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  TERRAFORM DESTROY + DATA SOURCES                                            ║
║  Data sources are NEVER destroyed by terraform destroy                      ║
║  Only resources you OWN (declared with "resource") are destroyed            ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  COMMON AZURE DATA SOURCES                                                   ║
║  data "azurerm_resource_group"   → read existing RG                        ║
║  data "azurerm_virtual_network"  → read existing VNet                      ║
║  data "azurerm_subnet"           → read existing subnet                    ║
║  data "azurerm_key_vault"        → read existing Key Vault                  ║
║  data "azurerm_storage_account"  → read existing storage                   ║
║  data "azurerm_client_config"    → current auth context (no args needed)   ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  POWERSHELL COMMANDS                                                         ║
║                                                                              ║
║  terraform init            → download providers                             ║
║  terraform validate        → check syntax                                   ║
║  terraform plan            → preview (data sources show as "Reading...")    ║
║  terraform apply --auto-approve → create YOUR resources                     ║
║  terraform state list      → see what Terraform manages (data + resources)  ║
║  terraform destroy --auto-approve → delete YOUR resources (data untouched) ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

---

## The Core Mental Model for This Video

```
TERRAFORM MANAGES INFRASTRUCTURE in two modes:

  resource "..." "..." { }   = OWNER mode
    → Terraform creates it, tracks it, and deletes it when you say so
    → Like BUYING a house — you own it, you maintain it, you demolish it

  data "..." "..." { }       = READER mode
    → Terraform reads information about something it doesn't own
    → Like READING the address of someone else's house to send them a letter
    → You can know everything about the house — its size, location, layout
    → But you cannot knock it down, and it still belongs to its owner

THE ENTERPRISE USE CASE:
  Network Team owns:     VNet, Subnets, NSGs       → they use resource blocks
  DevOps Team uses them: VM connects to their subnet → we use data blocks

  This separation of ownership + data source references is how large
  organisations scale Terraform across multiple teams without conflict.

THE CHAIN:
  data(RG) → provides name
  data(VNet) uses data(RG).name → provides name
  data(Subnet) uses data(RG).name + data(VNet).name → provides id
  resource(NIC) uses data(Subnet).id → VM connects to shared network
```

---

*Guide covers: Terraform data sources, data block syntax, data vs resource
distinction, read-only vs managed infrastructure, data source reference
prefix "data.", chaining data sources, azurerm_resource_group data source,
azurerm_virtual_network data source, azurerm_subnet data source,
azurerm_key_vault data source, azurerm_client_config, enterprise shared
infrastructure pattern, network team vs DevOps team separation, subnet_id
in ip_configuration, terraform plan reading behaviour, terraform destroy
data source immunity, terraform state list for data sources, common mistakes
with data sources, missing data prefix error, wrong virtual_network_name
error, reading non-existent resource error, PowerShell Azure CLI commands for
creating shared infrastructure, az network vnet create, az network vnet
subnet create, ARM credential management.*
