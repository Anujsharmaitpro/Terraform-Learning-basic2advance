# NexaCore Technologies — Internal DevOps Training Project
## Azure Infrastructure Provisioning with Terraform
**Project Code:** `NCT-INFRA-002` | **Track:** Junior DevOps Engineer | **Level:** Beginner+

---

> **A message from your Tech Lead:**
> You've completed the static website project (NCT-INFRA-001). Good work.
> This next ticket is a step up. We're provisioning a virtual machine environment
> for our internal QA team. Read the full spec before you touch any code.
> Follow naming conventions strictly — our billing team tracks costs by tag.
> — *Priya Menon, Lead DevOps, NexaCore Technologies*

---

## Org Context

| Field | Detail |
|---|---|
| **Organisation** | NexaCore Technologies Pvt. Ltd. |
| **Department** | Platform Engineering |
| **Team** | DevOps – Infrastructure |
| **Your Role** | Junior DevOps Engineer (Trainee) |
| **Reporting To** | Priya Menon (Lead DevOps) |
| **Ticket ID** | NCT-INFRA-002 |
| **Environment** | `dev` only |
| **Cloud** | Microsoft Azure |
| **IaC Tool** | Terraform `v1.6+` |
| **Azure Region** | `East US` (org default for dev workloads) |
| **Cost Centre** | `CC-DEVOPS-007` |

---

## 1. Project Overview

### What You're Building

**A Linux Virtual Machine environment on Azure for the internal QA team.**

NexaCore's QA team currently tests application builds on their local machines, which causes
"works on my machine" issues that delay sprint releases. Your task is to provision a
**standardised, cloud-hosted Linux VM** that the QA team can SSH into and run test scripts on.

This is a **real scenario** — provisioning dev/test VMs is one of the most common
infrastructure tasks in any DevOps role.

### Infrastructure You Will Provision

```
Azure Subscription (NexaCore Dev)
└── Resource Group: nct-dev-qa-rg
    ├── Virtual Network: nct-dev-vnet
    │   └── Subnet: nct-dev-qa-subnet
    ├── Network Security Group: nct-dev-qa-nsg
    │   └── Rule: Allow SSH (port 22) from defined IP only
    ├── Public IP Address: nct-dev-qa-pip
    ├── Network Interface: nct-dev-qa-nic
    └── Linux Virtual Machine: nct-dev-qa-vm
        └── OS: Ubuntu 22.04 LTS
```

### Why This Is Different from Project 001

| NCT-INFRA-001 (Static Site) | NCT-INFRA-002 (QA VM) |
|---|---|
| Single resource (Storage Account) | Multiple dependent resources |
| No networking | Full networking stack (VNet → Subnet → NSG → NIC → VM) |
| No security rules | Security Group with inbound rules |
| No sensitive data | SSH credentials — secrets management matters |
| Resources independent | Every resource depends on the previous one |

You will feel the **dependency chain** clearly for the first time in this project.

### Scope Boundaries

- Azure only, `dev` environment only
- No Terraform modules
- No remote backend — local state only
- No Load Balancer, no Managed Disks beyond the OS disk, no Azure Bastion
- One VM only — no scale sets
- SSH access only — no RDP, no web server setup

---

## 2. Naming Conventions

### Org Standard: NexaCore Resource Naming Pattern

NexaCore enforces a strict naming pattern across all cloud resources for billing and audit purposes:

```
{org-prefix}-{env}-{workload}-{resource-type}
```

| Token | Value for this project |
|---|---|
| `org-prefix` | `nct` |
| `env` | `dev` |
| `workload` | `qa` |
| `resource-type` | See table below |

### Resource Type Suffixes (NexaCore Standard)

| Azure Resource | Suffix | Full Name Example |
|---|---|---|
| Resource Group | `-rg` | `nct-dev-qa-rg` |
| Virtual Network | `-vnet` | `nct-dev-vnet` |
| Subnet | `-subnet` | `nct-dev-qa-subnet` |
| Network Security Group | `-nsg` | `nct-dev-qa-nsg` |
| Public IP Address | `-pip` | `nct-dev-qa-pip` |
| Network Interface Card | `-nic` | `nct-dev-qa-nic` |
| Virtual Machine | `-vm` | `nct-dev-qa-vm` |

### Terraform File Structure (Org Standard)

```
nct-infra-002-qa-vm/
├── providers.tf        ← provider + terraform version block
├── main.tf             ← all resource definitions
├── variables.tf        ← all variable declarations
├── outputs.tf          ← all output declarations
├── terraform.tfvars    ← actual variable values (never commit this)
└── .gitignore          ← must include *.tfvars and .terraform/
```

> **Org Policy:** `terraform.tfvars` must **never** be committed to version control.
> NexaCore uses a `.gitignore` for all Terraform repositories. Set yours up before
> writing your first line of code.

### `.gitignore` Minimum Content (required by org policy)

```
# Terraform
.terraform/
.terraform.lock.hcl
*.tfstate
*.tfstate.backup
*.tfvars
crash.log
override.tf
```

### Terraform Variable Names → `snake_case`

```
org_prefix
environment
azure_location
resource_group_name
vnet_name
subnet_name
nsg_name
vm_name
vm_size
admin_username
ssh_public_key_path
allowed_ssh_ip
cost_centre
owner_name
```

### Terraform Resource Block Labels → `snake_case`

```hcl
resource "azurerm_resource_group"             "qa_rg"       { }
resource "azurerm_virtual_network"            "qa_vnet"     { }
resource "azurerm_subnet"                     "qa_subnet"   { }
resource "azurerm_network_security_group"     "qa_nsg"      { }
resource "azurerm_public_ip"                  "qa_pip"      { }
resource "azurerm_network_interface"          "qa_nic"      { }
resource "azurerm_linux_virtual_machine"      "qa_vm"       { }
```

### NexaCore Mandatory Tags (every resource — billing team enforces this)

| Tag Key | Value |
|---|---|
| `Project` | `NCT-INFRA-002` |
| `Environment` | `dev` |
| `Owner` | `jane-doe` |
| `ManagedBy` | `terraform` |
| `CostCentre` | `CC-DEVOPS-007` |
| `Team` | `platform-engineering` |

> Missing even one tag on a resource will cause a flag in NexaCore's monthly
> cost audit. Build the habit of tagging everything from day one.

### Sample Data to Use

```hcl
# terraform.tfvars

org_prefix            = "nct"
environment           = "dev"
azure_location        = "East US"
resource_group_name   = "nct-dev-qa-rg"
vnet_name             = "nct-dev-vnet"
subnet_name           = "nct-dev-qa-subnet"
nsg_name              = "nct-dev-qa-nsg"
vm_name               = "nct-dev-qa-vm"
vm_size               = "Standard_B1s"         # free-tier eligible, 1 vCPU, 1 GB RAM
admin_username        = "nctadmin"
ssh_public_key_path   = "~/.ssh/id_rsa.pub"    # path to your LOCAL public key file
allowed_ssh_ip        = "YOUR_PUBLIC_IP/32"     # replace with your actual IP (check: whatismyip.com)
cost_centre           = "CC-DEVOPS-007"
owner_name            = "jane-doe"
```

---

## 3. Core Components to Build

### Component 1 — Networking Foundation (VNet + Subnet)

**File:** `main.tf`

Before any VM can exist, it needs a network to live in. Azure uses a
**Virtual Network (VNet)** as the top-level network boundary, and **Subnets**
as segments within that network. Every VM's NIC must be attached to a Subnet.

This is a chain: `VNet → Subnet`. The Subnet cannot exist without the VNet.
The VM cannot exist without the Subnet. This is your first real dependency chain.

**You must define:**

- `azurerm_virtual_network` resource
  - Address space: `["10.0.0.0/16"]`
  - References the Resource Group by attribute (not a string)
  - All six org tags applied

- `azurerm_subnet` resource
  - Address prefix: `["10.0.1.0/24"]`
  - References the VNet name and Resource Group by attribute

> Subnets do **not** support tags in Terraform's `azurerm_subnet` resource directly —
> this is an Azure API limitation, not a Terraform bug. Do not try to add tags to it.

---

### Component 2 — Network Security Group with SSH Rule

**File:** `main.tf`

By default, Azure VMs are unreachable from the internet. A **Network Security Group (NSG)**
is Azure's firewall layer — it controls what traffic can reach your VM.

You need to:
1. Create the NSG with one inbound rule allowing SSH (port 22) from **your IP only**
2. Associate the NSG with the Subnet

Allowing SSH from `0.0.0.0/0` (the whole internet) is a security violation at NexaCore.
The `allowed_ssh_ip` variable exists specifically to restrict this.

**You must define:**

- `azurerm_network_security_group` resource with one `security_rule` block:
  - Name: `"Allow-SSH"`
  - Priority: `100`
  - Direction: `"Inbound"`
  - Access: `"Allow"`
  - Protocol: `"Tcp"`
  - Destination port: `"22"`
  - Source address prefix: sourced from `var.allowed_ssh_ip`
  - All six org tags applied

- `azurerm_subnet_network_security_group_association` resource
  - Links the NSG to the Subnet
  - This resource has **no tags** — it is an association, not a named resource

---

### Component 3 — Public IP + Network Interface Card (NIC)

**File:** `main.tf`

The VM needs a way to be reached from outside Azure. A **Public IP** gives it
an externally accessible address. A **Network Interface Card (NIC)** is the
virtual network adapter that connects the VM to the Subnet and attaches the Public IP.

This is another dependency chain: `Public IP → NIC → VM`.

**You must define:**

- `azurerm_public_ip` resource
  - `allocation_method` = `"Static"` (so the IP doesn't change on restart)
  - `sku` = `"Standard"`
  - References Resource Group by attribute
  - All six org tags applied

- `azurerm_network_interface` resource
  - Contains one `ip_configuration` block:
    - `subnet_id` = reference to the Subnet
    - `private_ip_address_allocation` = `"Dynamic"`
    - `public_ip_address_id` = reference to the Public IP
  - All six org tags applied

---

### Component 4 — Linux Virtual Machine

**File:** `main.tf`

This is the core deliverable — the VM itself. You will use **SSH key authentication**
(not password) because that is NexaCore's security standard and industry best practice.

The VM will run **Ubuntu 22.04 LTS** — the org standard for dev/test Linux workloads.

**You must define:**

- `azurerm_linux_virtual_machine` resource
  - `size` sourced from `var.vm_size`
  - `admin_username` sourced from variable
  - `disable_password_authentication` = `true` (mandatory — no password auth)
  - One `admin_ssh_key` block:
    - `username` = same as `admin_username`
    - `public_key` = read from file using `file()` function with `var.ssh_public_key_path`
  - One `os_disk` block:
    - `caching` = `"ReadWrite"`
    - `storage_account_type` = `"Standard_LRS"`
  - One `source_image_reference` block for Ubuntu 22.04 LTS:
    - `publisher` = `"Canonical"`
    - `offer` = `"0001-com-ubuntu-server-jammy"`
    - `sku` = `"22_04-lts-gen2"`
    - `version` = `"latest"`
  - `network_interface_ids` = list containing reference to the NIC
  - All six org tags applied

---

### Component 5 — Variables and Outputs

**Files:** `variables.tf` and `outputs.tf`

Every variable from the Sample Data section must be declared with a `type` and
`description`. This is not optional at NexaCore — undocumented variables fail
the internal Terraform code review checklist.

**Outputs to expose after `apply`:**

```
resource_group_name     ← confirm which RG was used
vm_name                 ← confirm the VM name
public_ip_address       ← the IP the QA team will SSH into
vm_id                   ← Azure resource ID (used in future automation)
ssh_connection_string   ← a formatted string: "ssh nctadmin@<public_ip>"
```

> The `ssh_connection_string` output is the one the QA team lead will
> actually copy and paste. Format it cleanly using Terraform's `format()` function.

---

## 4. Hints & Pitfalls

### Hint 1 — SSH Keys Must Exist on Your Machine Before `terraform apply`

Terraform will read your SSH public key using the `file()` function at apply time.
If the file does not exist at the path you specified in `terraform.tfvars`,
the entire apply will fail with a confusing file-not-found error.

**Before you write any Terraform, generate your SSH key pair if you don't have one:**

```bash
# Check if you already have one
ls ~/.ssh/id_rsa.pub

# If not, generate one (press Enter to accept all defaults)
ssh-keygen -t rsa -b 4096 -C "jane-doe@nexacore.com"
```

The file at `~/.ssh/id_rsa.pub` is your **public key** — this goes into Azure.
The file at `~/.ssh/id_rsa` is your **private key** — this stays on your machine only.
Never put your private key path in Terraform variables.

---

### Hint 2 — The NSG Association Is a Separate Resource, Not a Block Inside NSG

A very common mistake is trying to associate the NSG with the Subnet by adding
something inside the `azurerm_network_security_group` block. That is not how it works.

The association is its own **standalone resource** in Terraform:

```
azurerm_subnet_network_security_group_association
```

It takes two inputs: the Subnet ID and the NSG ID. Both must be referenced
by attribute, not by string. If you skip this resource, your NSG will exist
in Azure but will not actually protect your Subnet — it will be a firewall
attached to nothing.

---

### Hint 3 — VM Size `Standard_B1s` Has a Catch in Some Subscriptions

`Standard_B1s` is the smallest Azure VM (1 vCPU, 1 GB RAM) and is free-tier
eligible on new Azure accounts. However, some Azure subscriptions — especially
student or restricted accounts — have **quota limits** that block certain VM sizes
in certain regions.

If your `terraform apply` fails with:
```
OperationNotAllowed: Operation could not be completed as it results
in exceeding approved standardBSFamily Cores quota
```

You have two options:
- Switch `vm_size` to `"Standard_B2s"` and try a different region in your `.tfvars`
- Request a quota increase in the Azure Portal under `Subscriptions → Usage + quotas`

Check your available quota **before** you write your Terraform files:
```bash
az vm list-usage --location "East US" --output table | grep -i "BS Family"
```

---

## 5. Real Environment Requirements

### Tools and Setup

```
Tool                    Version     Install Command / Notes
──────────────────────────────────────────────────────────────────
Terraform CLI           v1.6+       https://developer.hashicorp.com/terraform/install
Azure CLI               v2.50+      https://learn.microsoft.com/en-us/cli/azure/install-azure-cli
SSH Client              Built-in    Linux/Mac: built-in | Windows: use WSL or Git Bash
VS Code                 Any         Recommended editor
HashiCorp TF Extension  Latest      Install from VS Code marketplace
```

### Azure Authentication

```bash
# Login to Azure
az login

# Confirm your active subscription
az account show --output table

# Set correct subscription if needed
az account set --subscription "NexaCore-Dev-Subscription"

# Verify your VM quota before starting
az vm list-usage --location "East US" --output table
```

### Finding Your Public IP for the SSH Rule

```bash
# Run this and put the result in allowed_ssh_ip in your .tfvars
curl -s https://api.ipify.org
# Example output: 103.56.78.90
# Add /32 for single IP: "103.56.78.90/32"
```

### After `terraform apply` — How to Connect

```bash
# Get the public IP from Terraform output
terraform output public_ip_address

# SSH into the VM
ssh -i ~/.ssh/id_rsa nctadmin@<public_ip_from_output>

# Or use the formatted output directly
terraform output ssh_connection_string
```

### Azure Cost Awareness

```
Resource              Estimated Cost (East US, dev usage)
──────────────────────────────────────────────────────────
Standard_B1s VM       ~$0.013/hour (~$0.31/day if left running)
Standard Public IP    ~$0.004/hour when associated with a running VM
OS Disk (Standard)    ~$0.04/GB/month (30 GB default = ~$1.20/month)
VNet / Subnet / NSG   Free
──────────────────────────────────────────────────────────
Total (if left 24hrs) ~$0.40/day

ALWAYS run terraform destroy when done with a session.
```

> NexaCore's policy: any dev VM left running over a weekend without approval
> triggers an automatic alert to your team lead. Build the `destroy` habit now.

---

## 6. NexaCore Code Review Checklist

Before you consider this ticket done, verify every item:

```
[ ] providers.tf has version constraints — no unpinned providers
[ ] Every resource has all 6 required org tags
[ ] No resource names are hardcoded strings — all use variable references
[ ] No resource attributes use plain strings where attribute refs should be used
[ ] terraform.tfvars is listed in .gitignore
[ ] terraform fmt has been run — code is properly formatted
[ ] terraform validate passes with no errors
[ ] terraform plan output reviewed line by line before apply
[ ] All 5 outputs are declared and return correct values after apply
[ ] terraform destroy confirmed working at end of session
```

---

## 7. Workflow

```bash
# 1. Generate SSH key (if not already done)
ssh-keygen -t rsa -b 4096 -C "jane-doe@nexacore.com"

# 2. Check your Azure quota
az vm list-usage --location "East US" --output table

# 3. Initialise Terraform (downloads Azure provider)
terraform init

# 4. Validate your configuration syntax
terraform validate

# 5. Format your code to org standard
terraform fmt

# 6. Preview what will be created — read every line
terraform plan

# 7. Apply (type 'yes' when prompted)
terraform apply

# 8. Connect to your VM
ssh -i ~/.ssh/id_rsa nctadmin@$(terraform output -raw public_ip_address)

# 9. Destroy when done — mandatory
terraform destroy
```

---

## 8. How This Connects to Real Work

Once you complete this ticket, you will have hands-on experience with the
exact pattern used to provision developer and QA environments in most
mid-size tech companies:

```
Project 001 (NCT-INFRA-001)     →    Storage, Provider, basic resources
Project 002 (NCT-INFRA-002)     →    Networking, Security, Compute, dependency chains
─────────────────────────────────────────────────────────────────────────
Next logical step                →    Terraform Modules (DRY up this config)
Then                             →    Remote State (Azure Blob backend)
Then                             →    Multiple environments (dev/staging/prod)
```

You are not learning Terraform in isolation.
You are learning how infrastructure is actually built in teams.

---

*NexaCore Technologies — Platform Engineering | Internal Training Material*
*NCT-INFRA-002 | Do not distribute outside the DevOps team*
