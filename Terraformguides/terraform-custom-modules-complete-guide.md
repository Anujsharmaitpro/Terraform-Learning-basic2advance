# Terraform Custom Modules — Complete Beginner's Guide
### Azure · VS Code · Windows · Zero Coding Experience Required

> **How to use this guide:**
> Read every section in order. Do not skip ahead.
> Every concept builds on the one before it.
> Every command is meant to be typed exactly as written.

---

## Table of Contents

1. [What is a Module? — The Big Idea](#1-what-is-a-module--the-big-idea)
2. [What We Are Building — Project Overview](#2-what-we-are-building--project-overview)
3. [Setting Up Your Windows Machine](#3-setting-up-your-windows-machine)
4. [Understanding the Folder Structure Before Writing Anything](#4-understanding-the-folder-structure-before-writing-anything)
5. [The Three Files Every Module Must Have](#5-the-three-files-every-module-must-have)
6. [Building Module 1 — Resource Group](#6-building-module-1--resource-group)
7. [Building Module 2 — Storage Account](#7-building-module-2--storage-account)
8. [Building Module 3 — Virtual Network](#8-building-module-3--virtual-network)
9. [The Root Configuration — Calling Your Modules](#9-the-root-configuration--calling-your-modules)
10. [Running the Full Project — Step by Step](#10-running-the-full-project--step-by-step)
11. [Understanding What Just Happened](#11-understanding-what-just-happened)
12. [Changing a Module — What Happens Next](#12-changing-a-module--what-happens-next)
13. [Cleaning Up](#13-cleaning-up)
14. [Common Errors and How to Fix Them](#14-common-errors-and-how-to-fix-them)
15. [Module Rules — Quick Reference](#15-module-rules--quick-reference)

---

## 1. What is a Module? — The Big Idea

Before touching VS Code, understand this concept completely. Everything else depends on it.

### The problem modules solve

Imagine you need to build the same set of Azure resources — a Resource Group, a Storage Account, and a Virtual Network — for three different projects: a website, an API, and a database platform.

**Without modules**, you write the same Terraform code three times:

```
website-project/
    main.tf  ← 150 lines of resource code

api-project/
    main.tf  ← same 150 lines, slightly different names

database-project/
    main.tf  ← same 150 lines again
```

If you discover a bug or need to add a tag to all storage accounts, you fix it in three places. You will inevitably miss one. This is how production mistakes happen.

**With modules**, you write the resource code once, in one place, and call it from all three projects:

```
modules/
    storage-account/   ← written ONCE
    virtual-network/   ← written ONCE
    resource-group/    ← written ONCE

website-project/
    main.tf  ← calls the modules, passes different values

api-project/
    main.tf  ← calls the same modules, different values

database-project/
    main.tf  ← calls the same modules, different values
```

Fix the bug once in the module — all three projects get the fix automatically on next apply.

### The LEGO analogy

Think of a Terraform module like a LEGO brick mold.

- The **mold** (the module) defines the shape of the brick
- The **bricks** (the resources) are what gets created when you use the mold
- You can use the same mold to make red bricks, blue bricks, large bricks — by passing different inputs
- The mold itself never changes when you change the color

A module defines *what to build*. The values you pass in define *how to build it* for each specific use case.

### Two roles in every module setup

| Role | What it means | Which files |
|---|---|---|
| **Module** | The reusable template. Defines resources. Accepts inputs. Returns outputs. | Files inside `modules/` folder |
| **Root / Caller** | The file that uses the module. Passes values in. Receives outputs back. | `main.tf` in your project root |

You always work in both places. The module defines the shape. The root decides the values.

---

## 2. What We Are Building — Project Overview

### The project

A simple Azure foundation — the infrastructure skeleton that sits underneath any real application. Three modules, one project.

```
What gets created in Azure:
┌─────────────────────────────────────────────────┐
│            Resource Group                        │
│            "myapp-dev-rg"                        │
│                                                  │
│   ┌──────────────────┐   ┌──────────────────┐   │
│   │  Storage Account │   │  Virtual Network  │   │
│   │  "myappdevsa"    │   │  "myapp-dev-vnet" │   │
│   │                  │   │  ┌────────────┐   │   │
│   │  container:      │   │  │ app-subnet │   │   │
│   │  "app-data"      │   │  └────────────┘   │   │
│   └──────────────────┘   └──────────────────┘   │
└─────────────────────────────────────────────────┘
```

### Three modules you will build

| Module | What it creates | Folder name |
|---|---|---|
| Resource Group Module | One Azure Resource Group | `modules/resource-group` |
| Storage Account Module | One Storage Account + one container | `modules/storage-account` |
| Virtual Network Module | One VNet + one subnet | `modules/virtual-network` |

### What you will learn

- How to create a module from scratch
- How inputs flow into a module (`variables.tf`)
- How outputs flow back out of a module (`outputs.tf`)
- How the root configuration calls modules and wires them together
- How changing one module affects the plan output
- Why modules are the correct way to organise Terraform code

---

## 3. Setting Up Your Windows Machine

Follow every step. Do not skip any.

### Step 3.1 — Install VS Code

1. Open your browser and go to `https://code.visualstudio.com`
2. Click the blue **Download for Windows** button
3. Run the downloaded `.exe` file
4. During installation, tick the box that says **"Add to PATH"** — this is important
5. Click through the rest of the installer with default settings
6. Open VS Code from the Start Menu

### Step 3.2 — Install the Terraform extension in VS Code

The Terraform extension gives you syntax highlighting, auto-completion, and error detection while you type.

1. Open VS Code
2. Click the **Extensions** icon on the left sidebar (it looks like four squares)
3. In the search box type: `HashiCorp Terraform`
4. Click the result by **HashiCorp** (the official one — it has a purple logo)
5. Click **Install**
6. Wait for it to finish — you will see a green checkmark

### Step 3.3 — Install Terraform on Windows

1. Go to `https://developer.hashicorp.com/terraform/install`
2. Click **Windows**
3. Download the **AMD64** version (the `.zip` file)
4. Open the downloaded `.zip` file
5. Inside it you will see one file: `terraform.exe`
6. Copy `terraform.exe` to `C:\Windows\System32\` (this puts it on your PATH automatically)

**Verify it worked:**
1. Press `Windows + R`, type `cmd`, press Enter — this opens Command Prompt
2. Type this and press Enter:

```
terraform -version
```

You should see something like:

```
Terraform v1.9.0
on windows_amd64
```

If you see this, Terraform is installed correctly. If you see `'terraform' is not recognized`, the file was not copied to the right place — try again.

### Step 3.4 — Install Azure CLI

The Azure CLI lets you log in to Azure from the terminal so Terraform can create resources.

1. Go to `https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-windows`
2. Click **Download the MSI installer**
3. Run the installer with all default settings
4. Close and reopen Command Prompt

**Verify it worked:**

```
az version
```

You should see a block of version information. If you see it, Azure CLI is installed.

### Step 3.5 — Log in to Azure

In Command Prompt:

```
az login
```

A browser window will open. Log in with your Azure account. When it says "You have logged in", go back to Command Prompt. You will see your subscription information printed.

**Find and note your Subscription ID** — you will need it in a moment:

```
az account show --query id --output tsv
```

Copy the long string it prints (looks like: `a1b2c3d4-e5f6-7890-abcd-ef1234567890`). Save it in Notepad.

### Step 3.6 — Create a Service Principal

A Service Principal is a dedicated login for Terraform so it doesn't use your personal account.

In Command Prompt, run this command — replace `YOUR_SUBSCRIPTION_ID` with the ID you just copied:

```
az ad sp create-for-rbac --name "terraform-learning-sp" --role contributor --scopes /subscriptions/YOUR_SUBSCRIPTION_ID
```

You will see output like this — **copy all of it into Notepad immediately**:

```json
{
  "appId": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
  "displayName": "terraform-learning-sp",
  "password": "your-password-will-appear-here",
  "tenant": "ffffffff-gggg-hhhh-iiii-jjjjjjjjjjjj"
}
```

You will use these four values in the next section. The password is shown only once — do not close this window until you have saved it.

### Step 3.7 — Set environment variables in Windows

Terraform reads these four environment variables automatically. Setting them here means you never put credentials inside your code files.

Open Command Prompt **as Administrator** (right-click Command Prompt → Run as Administrator) and run these four commands one at a time — replace each placeholder with your actual value:

```
setx ARM_CLIENT_ID "your-appId-value-here" /M
setx ARM_CLIENT_SECRET "your-password-value-here" /M
setx ARM_TENANT_ID "your-tenant-value-here" /M
setx ARM_SUBSCRIPTION_ID "your-subscription-id-here" /M
```

**Close Command Prompt and reopen it** — environment variables only take effect in new windows.

Verify they are set:

```
echo %ARM_CLIENT_ID%
```

You should see your App ID printed. If you see a blank line, the variable was not set — try again.

---

## 4. Understanding the Folder Structure Before Writing Anything

### Create the project folder

1. Open VS Code
2. Press `Ctrl + Shift + E` to open the file explorer sidebar
3. Click **Open Folder**
4. Navigate to your Documents folder
5. Click **New Folder**, name it `terraform-modules-project`
6. Click **Select Folder**

### Create the complete folder structure

In VS Code, look at the left sidebar (the Explorer panel). You will create folders and files here.

**Right-click in the empty space** of the Explorer panel → **New Folder** for each folder below.

The final structure you are building looks like this:

```
terraform-modules-project/          ← your project root (already open in VS Code)
│
├── main.tf                         ← root: calls all three modules
├── variables.tf                    ← root: input variables for the whole project
├── outputs.tf                      ← root: outputs from the whole project
├── terraform.tf                    ← root: terraform block + provider config
├── dev.tfvars                      ← values for dev environment
│
└── modules/                        ← folder that holds all your modules
    │
    ├── resource-group/             ← Module 1
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    │
    ├── storage-account/            ← Module 2
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    │
    └── virtual-network/            ← Module 3
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

### Create the folders now

In VS Code Explorer (left panel):

1. Right-click → **New Folder** → name it `modules`
2. Right-click on `modules` → **New Folder** → name it `resource-group`
3. Right-click on `modules` → **New Folder** → name it `storage-account`
4. Right-click on `modules` → **New Folder** → name it `virtual-network`

Leave all files empty for now. You will create them in each section below.

### What each level means

```
terraform-modules-project/     ← ROOT LEVEL
                                  This is where YOU run terraform commands.
                                  This is what terraform init, plan, apply all read.
                                  This is the "caller" — it uses modules.

modules/resource-group/        ← MODULE LEVEL
                                  This is a self-contained unit.
                                  It only defines resources and what inputs it needs.
                                  It does NOT know anything about your project.
                                  You could pick this folder up and use it in
                                  any other project and it would work.
```

---

## 5. The Three Files Every Module Must Have

Every module folder contains exactly three files. Understand what each one does before writing any code.

### `variables.tf` — The module's front door (inputs)

This file answers the question: **"What information does this module need to do its job?"**

A storage account module needs a name, a location, a resource group name. These are its inputs. The module itself does not decide what those values are — the caller (your root `main.tf`) passes them in.

```
Think of it like ordering a pizza:
- variables.tf is the ORDER FORM (what size? what toppings? delivery address?)
- The pizza shop (the module) needs this info before it can do anything
- You (the root) fill in the form with specific values
```

### `main.tf` — The module's engine (resources)

This file answers the question: **"What does this module actually create?"**

It contains the real Azure resource blocks. It uses `var.something` to reference the inputs defined in `variables.tf`. It never hardcodes values — everything comes from variables.

### `outputs.tf` — The module's receipt (outputs)

This file answers the question: **"What information does this module give back after it's done?"**

After the module creates a storage account, the caller might need the storage account's name, its ID, or its endpoint URL to pass into another module. Outputs make that possible.

```
The flow every time:
ROOT main.tf → passes values → MODULE variables.tf
MODULE main.tf → creates resources → using var.something
MODULE outputs.tf → returns values → back to ROOT main.tf
ROOT outputs.tf → can expose those values → to the terminal
```

---

## 6. Building Module 1 — Resource Group

### What this module does

Creates one Azure Resource Group. Takes a name, location, and tags as inputs. Returns the resource group name and ID as outputs.

### Step 1 — Create `modules/resource-group/variables.tf`

Right-click on the `resource-group` folder in VS Code → **New File** → name it `variables.tf`

Click on the file to open it. Type this exactly:

```hcl
# modules/resource-group/variables.tf
# -------------------------------------------------------
# This file defines what information this module needs.
# The person calling this module must provide these values.
# -------------------------------------------------------

variable "name" {
  type        = string
  description = "The name of the resource group to create."
}

variable "location" {
  type        = string
  description = "The Azure region where the resource group will be created."
}

variable "tags" {
  type        = map(string)
  description = "A map of tags to apply to the resource group."
  default     = {}
}
```

**What you just wrote — explained line by line:**

- `variable "name"` — declares an input called `name`. Anyone calling this module must provide it.
- `type = string` — this input must be text (not a number, not a list).
- `description` — explains what this input is for. Always write this — it is documentation.
- `variable "tags"` — a `map(string)` means a collection of key-value pairs, like `{ Environment = "dev" }`.
- `default = {}` — tags are optional. If the caller doesn't provide tags, the module uses an empty map.

Press `Ctrl + S` to save.

### Step 2 — Create `modules/resource-group/main.tf`

Right-click on the `resource-group` folder → **New File** → name it `main.tf`

```hcl
# modules/resource-group/main.tf
# -------------------------------------------------------
# This file contains the actual Azure resource.
# It uses var.name, var.location, var.tags — these come
# from the variables.tf file in this same folder.
# -------------------------------------------------------

resource "azurerm_resource_group" "this" {
  name     = var.name
  location = var.location
  tags     = var.tags
}
```

**What you just wrote — explained:**

- `azurerm_resource_group` — this is the Azure resource type. `azurerm` = Azure provider. `resource_group` = what kind of resource.
- `"this"` — the label for this resource inside this module. The convention inside a module is to use `"this"` because there is only one of it.
- `var.name` — uses the `name` input from `variables.tf`. The module does not decide what this name is — the caller does.
- `var.location` and `var.tags` — same pattern.

Press `Ctrl + S` to save.

### Step 3 — Create `modules/resource-group/outputs.tf`

Right-click on the `resource-group` folder → **New File** → name it `outputs.tf`

```hcl
# modules/resource-group/outputs.tf
# -------------------------------------------------------
# This file defines what information this module
# gives back to whoever called it.
# After creating the resource group, the caller might
# need its name or ID to use in other resources.
# -------------------------------------------------------

output "name" {
  description = "The name of the created resource group."
  value       = azurerm_resource_group.this.name
}

output "id" {
  description = "The Azure resource ID of the created resource group."
  value       = azurerm_resource_group.this.id
}

output "location" {
  description = "The location of the created resource group."
  value       = azurerm_resource_group.this.location
}
```

**What you just wrote — explained:**

- `output "name"` — exposes the resource group's name after creation.
- `value = azurerm_resource_group.this.name` — reads the `name` attribute from the resource you created in `main.tf`. The pattern is always `resource_type.label.attribute`.
- The `.id` output is the full Azure resource ID — a long string like `/subscriptions/abc.../resourceGroups/myapp-dev-rg`. Other resources sometimes need this.
- The `.location` output — returned so callers can pass it to other modules without hardcoding the region twice.

Press `Ctrl + S` to save.

**Module 1 is complete.** Your `modules/resource-group/` folder now has three files. Do not touch them again unless you want to change what the module does.

---

## 7. Building Module 2 — Storage Account

### What this module does

Creates one Azure Storage Account and one Storage Container inside it. Takes a name, location, resource group name, and container name as inputs. Returns the storage account's name and primary endpoint as outputs.

### Step 1 — Create `modules/storage-account/variables.tf`

Right-click on the `storage-account` folder → **New File** → name it `variables.tf`

```hcl
# modules/storage-account/variables.tf
# -------------------------------------------------------
# Inputs this module needs from the caller.
# -------------------------------------------------------

variable "name" {
  type        = string
  description = "The name of the storage account. Must be globally unique, lowercase, alphanumeric, 3-24 characters."

  validation {
    condition     = length(var.name) >= 3 && length(var.name) <= 24 && can(regex("^[a-z0-9]+$", var.name))
    error_message = "Storage account name must be 3-24 characters, lowercase letters and numbers only. No hyphens or uppercase."
  }
}

variable "resource_group_name" {
  type        = string
  description = "The name of the resource group to create the storage account in."
}

variable "location" {
  type        = string
  description = "The Azure region where the storage account will be created."
}

variable "container_name" {
  type        = string
  description = "The name of the storage container to create inside the storage account."
  default     = "app-data"
}

variable "account_replication_type" {
  type        = string
  description = "The replication type for the storage account. LRS for dev, GRS for prod."
  default     = "LRS"
}

variable "tags" {
  type        = map(string)
  description = "A map of tags to apply to the storage account."
  default     = {}
}
```

**New things to understand here:**

- `validation` block — this runs a check on the input value before Terraform even tries to create anything in Azure. If someone passes `"My-Storage"` (has uppercase and a hyphen), this validation catches it immediately with a clear message. Azure would also reject it, but the Azure error message is confusing — your custom message is much clearer.
- `can(regex(...))` — `can()` returns `true` if the expression inside it succeeds without error. `regex()` checks if the value matches a pattern. `^[a-z0-9]+$` means "only lowercase letters and numbers, nothing else."
- `default = "LRS"` on `account_replication_type` — if the caller doesn't say which replication type they want, use LRS (Locally Redundant Storage — cheaper, fine for dev).

Press `Ctrl + S` to save.

### Step 2 — Create `modules/storage-account/main.tf`

```hcl
# modules/storage-account/main.tf
# -------------------------------------------------------
# Creates a Storage Account and one Container inside it.
# -------------------------------------------------------

resource "azurerm_storage_account" "this" {
  name                     = var.name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = var.account_replication_type
  min_tls_version          = "TLS1_2"
  tags                     = var.tags
}

resource "azurerm_storage_container" "this" {
  name                  = var.container_name
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "private"
}
```

**What you just wrote — explained:**

- `azurerm_storage_account.this` — creates the storage account using inputs from `var.*`.
- `account_tier = "Standard"` — this is hardcoded inside the module because there is only one reasonable choice for this project. Hardcoding *inside* a module is acceptable for values that never change based on the caller's input.
- `azurerm_storage_container.this` — creates the container inside the storage account.
- `storage_account_id = azurerm_storage_account.this.id` — this is how Terraform knows the container must be created *after* the storage account. This reference creates an **implicit dependency** — you do not need to write `depends_on` because Terraform can see the connection.

Press `Ctrl + S` to save.

### Step 3 — Create `modules/storage-account/outputs.tf`

```hcl
# modules/storage-account/outputs.tf
# -------------------------------------------------------
# Values this module returns to whoever called it.
# -------------------------------------------------------

output "name" {
  description = "The name of the created storage account."
  value       = azurerm_storage_account.this.name
}

output "id" {
  description = "The Azure resource ID of the storage account."
  value       = azurerm_storage_account.this.id
}

output "primary_blob_endpoint" {
  description = "The primary blob endpoint URL of the storage account."
  value       = azurerm_storage_account.this.primary_blob_endpoint
}

output "container_name" {
  description = "The name of the storage container created inside this storage account."
  value       = azurerm_storage_container.this.name
}
```

Press `Ctrl + S` to save.

**Module 2 is complete.**

---

## 8. Building Module 3 — Virtual Network

### What this module does

Creates one Azure Virtual Network and one Subnet inside it. Takes a name, location, resource group, address space, and subnet prefix as inputs. Returns the VNet and subnet IDs.

### Step 1 — Create `modules/virtual-network/variables.tf`

```hcl
# modules/virtual-network/variables.tf
# -------------------------------------------------------
# Inputs this module needs from the caller.
# -------------------------------------------------------

variable "name" {
  type        = string
  description = "The name of the Virtual Network."
}

variable "resource_group_name" {
  type        = string
  description = "The name of the resource group to create the VNet in."
}

variable "location" {
  type        = string
  description = "The Azure region where the VNet will be created."
}

variable "address_space" {
  type        = string
  description = "The address space (CIDR) for the Virtual Network. Example: 10.0.0.0/16"
  default     = "10.0.0.0/16"
}

variable "subnet_name" {
  type        = string
  description = "The name of the subnet to create inside the VNet."
  default     = "app-subnet"
}

variable "subnet_prefix" {
  type        = string
  description = "The address prefix (CIDR) for the subnet. Example: 10.0.1.0/24"
  default     = "10.0.1.0/24"
}

variable "tags" {
  type        = map(string)
  description = "A map of tags to apply to the Virtual Network."
  default     = {}
}
```

Press `Ctrl + S` to save.

### Step 2 — Create `modules/virtual-network/main.tf`

```hcl
# modules/virtual-network/main.tf
# -------------------------------------------------------
# Creates a Virtual Network and one Subnet inside it.
# -------------------------------------------------------

resource "azurerm_virtual_network" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [var.address_space]
  tags                = var.tags
}

resource "azurerm_subnet" "this" {
  name                 = var.subnet_name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.subnet_prefix]
}
```

**Important note on `address_space`:**

`address_space` in Azure requires a **list**, not a single string. Even though you are only providing one CIDR block, it must go inside square brackets `[]`. That is why you see `[var.address_space]` and not just `var.address_space`. The variable itself is a `string` for simplicity — the `[]` wrapping happens inside the resource block.

Press `Ctrl + S` to save.

### Step 3 — Create `modules/virtual-network/outputs.tf`

```hcl
# modules/virtual-network/outputs.tf
# -------------------------------------------------------
# Values this module returns to whoever called it.
# -------------------------------------------------------

output "vnet_id" {
  description = "The Azure resource ID of the Virtual Network."
  value       = azurerm_virtual_network.this.id
}

output "vnet_name" {
  description = "The name of the Virtual Network."
  value       = azurerm_virtual_network.this.name
}

output "subnet_id" {
  description = "The Azure resource ID of the subnet."
  value       = azurerm_subnet.this.id
}

output "subnet_name" {
  description = "The name of the subnet."
  value       = azurerm_subnet.this.name
}
```

Press `Ctrl + S` to save.

**Module 3 is complete. All three modules are now written.**

---

## 9. The Root Configuration — Calling Your Modules

Now you write the files that live at the **root level** of your project — the files that call your modules and tie everything together. These files live directly in `terraform-modules-project/`, not inside any module folder.

### Step 1 — Create `terraform.tf` (the setup file)

Right-click in the root of the Explorer panel (above the `modules` folder) → **New File** → name it `terraform.tf`

```hcl
# terraform.tf
# -------------------------------------------------------
# Terraform setup: which version to use, which provider,
# and how to configure Azure authentication.
# -------------------------------------------------------

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  # Terraform reads ARM_CLIENT_ID, ARM_CLIENT_SECRET,
  # ARM_TENANT_ID, and ARM_SUBSCRIPTION_ID automatically
  # from the environment variables you set in Section 3.7.
  # You do not need to write them here.
}
```

Press `Ctrl + S` to save.

### Step 2 — Create `variables.tf` (root inputs)

```hcl
# variables.tf  (ROOT level — not inside any module)
# -------------------------------------------------------
# These are the inputs for the overall project.
# Values come from dev.tfvars.
# -------------------------------------------------------

variable "project" {
  type        = string
  description = "Short project name used in all resource names. Lowercase, no spaces."
}

variable "environment" {
  type        = string
  description = "Deployment environment. Must be dev or prod."

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "Environment must be 'dev' or 'prod'."
  }
}

variable "location" {
  type        = string
  description = "Azure region for all resources."
  default     = "eastus"
}

variable "cost_center" {
  type        = string
  description = "Cost center code for Finance tagging."
}

variable "address_space" {
  type        = string
  description = "CIDR address space for the Virtual Network."
  default     = "10.0.0.0/16"
}

variable "subnet_prefix" {
  type        = string
  description = "CIDR prefix for the app subnet."
  default     = "10.0.1.0/24"
}

variable "replication_type" {
  type        = string
  description = "Storage account replication. LRS for dev, GRS for prod."
  default     = "LRS"
}
```

Press `Ctrl + S` to save.

### Step 3 — Create `locals.tf` (derived values)

```hcl
# locals.tf  (ROOT level)
# -------------------------------------------------------
# Derived values computed from variables.
# Define once here, use everywhere.
# -------------------------------------------------------

locals {
  # The master naming prefix — used by every resource name
  name_prefix = "${var.project}-${var.environment}"

  # Storage account name — no hyphens allowed by Azure
  storage_name = lower(replace("${var.project}${var.environment}sa", "-", ""))

  # Tags applied to every resource through every module
  common_tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.project
    CostCenter  = var.cost_center
  }
}
```

Press `Ctrl + S` to save.

### Step 4 — Create `main.tf` (the module caller — the most important file)

This is where module calling happens. Read every comment carefully.

```hcl
# main.tf  (ROOT level)
# -------------------------------------------------------
# This file CALLS your three modules.
# It does not define resources directly.
# It passes values INTO modules and receives values back.
# -------------------------------------------------------


# ── MODULE CALL 1: Resource Group ────────────────────────────────────────────
#
# Syntax to call a module:
#
# module "label" {
#   source = "path/to/module/folder"
#   input_variable_name = value_to_pass_in
# }
#
# "label" is what you name THIS call. You can call the same module
# multiple times with different labels and different values.

module "resource_group" {
  source = "./modules/resource-group"

  # These names on the LEFT must match variable names in
  # modules/resource-group/variables.tf exactly.
  name     = "${local.name_prefix}-rg"
  location = var.location
  tags     = local.common_tags
}


# ── MODULE CALL 2: Storage Account ───────────────────────────────────────────
#
# Notice: resource_group_name comes from the resource group MODULE's output.
# Syntax: module.label.output_name
# This creates a dependency — storage account is created AFTER resource group.

module "storage_account" {
  source = "./modules/storage-account"

  name                     = local.storage_name
  resource_group_name      = module.resource_group.name      # ← output from Module 1
  location                 = module.resource_group.location  # ← output from Module 1
  container_name           = "app-data"
  account_replication_type = var.replication_type
  tags                     = local.common_tags
}


# ── MODULE CALL 3: Virtual Network ───────────────────────────────────────────

module "virtual_network" {
  source = "./modules/virtual-network"

  name                = "${local.name_prefix}-vnet"
  resource_group_name = module.resource_group.name      # ← output from Module 1
  location            = module.resource_group.location  # ← output from Module 1
  address_space       = var.address_space
  subnet_name         = "app-subnet"
  subnet_prefix       = var.subnet_prefix
  tags                = local.common_tags
}
```

**The most important concept in this file:**

Look at `resource_group_name = module.resource_group.name` inside the storage account module call.

- `module` — the keyword
- `resource_group` — the label you gave the module call (defined on the `module "resource_group"` line above)
- `name` — the output name from `modules/resource-group/outputs.tf`

This is how modules talk to each other. The storage account module does not hardcode the resource group name — it receives it from the resource group module's output. Terraform automatically knows to create the resource group first, then the storage account, because of this reference.

Press `Ctrl + S` to save.

### Step 5 — Create `outputs.tf` (root outputs)

```hcl
# outputs.tf  (ROOT level)
# -------------------------------------------------------
# These are the values printed to your terminal after
# terraform apply completes.
# They read from the module outputs.
# -------------------------------------------------------

output "resource_group_name" {
  description = "The name of the resource group created."
  value       = module.resource_group.name
}

output "storage_account_name" {
  description = "The name of the storage account created."
  value       = module.storage_account.name
}

output "storage_blob_endpoint" {
  description = "The blob endpoint URL of the storage account."
  value       = module.storage_account.primary_blob_endpoint
}

output "vnet_name" {
  description = "The name of the virtual network created."
  value       = module.virtual_network.vnet_name
}

output "subnet_id" {
  description = "The resource ID of the app subnet."
  value       = module.virtual_network.subnet_id
}

output "applied_tags" {
  description = "The tag set applied to all resources."
  value       = local.common_tags
}
```

Press `Ctrl + S` to save.

### Step 6 — Create `dev.tfvars` (your input values)

```hcl
# dev.tfvars
# -------------------------------------------------------
# The actual values for the dev environment.
# Run: terraform apply -var-file="dev.tfvars"
# -------------------------------------------------------

project          = "myapp"
environment      = "dev"
location         = "eastus"
cost_center      = "CC-LEARN-001"
address_space    = "10.0.0.0/16"
subnet_prefix    = "10.0.1.0/24"
replication_type = "LRS"
```

Press `Ctrl + S` to save.

---

## 10. Running the Full Project — Step by Step

### Open the VS Code terminal

In VS Code:
1. Press `Ctrl + `` ` `` ` (the backtick key, usually top-left below Escape)
2. A terminal panel opens at the bottom of VS Code
3. It should already be in your project folder. Confirm by typing:

```
pwd
```

You should see the path ending in `terraform-modules-project`. If not, type:

```
cd C:\Users\YourName\Documents\terraform-modules-project
```

### Command 1 — `terraform init`

```
terraform init
```

**What this does:**
- Downloads the Azure provider plugin
- Scans all your `.tf` files including inside `modules/`
- Creates a `.terraform` folder (do not touch this)
- Creates a `.terraform.lock.hcl` file (this pins provider versions — commit this to Git)

**What you should see:**

```
Initializing the backend...
Initializing modules...
- resource_group in modules/resource-group
- storage_account in modules/storage-account
- virtual_network in modules/virtual-network

Initializing provider plugins...
- Finding hashicorp/azurerm versions matching "~> 4.0"...
- Installing hashicorp/azurerm v4.x.x...

Terraform has been successfully initialized!
```

Notice the line `Initializing modules...` — Terraform has found and registered all three of your modules.

### Command 2 — `terraform validate`

```
terraform validate
```

**What this does:** Checks every file for syntax errors without contacting Azure. If you made a typo in a variable name or forgot a closing brace, this catches it.

**What you should see:**

```
Success! The configuration is valid.
```

If you see errors, read them carefully. They tell you the file name and line number where the problem is.

### Command 3 — `terraform plan`

```
terraform plan -var-file="dev.tfvars"
```

**What this does:** Contacts Azure, compares what exists with what you want to build, and shows you exactly what it will create. Nothing is changed yet.

**What you should see (approximately):**

```
Terraform used the selected providers to generate the following execution plan.

  # module.resource_group.azurerm_resource_group.this will be created
  + resource "azurerm_resource_group" "this" {
      + id       = (known after apply)
      + location = "eastus"
      + name     = "myapp-dev-rg"
      + tags     = {
          + "CostCenter"  = "CC-LEARN-001"
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Project"     = "myapp"
        }
    }

  # module.storage_account.azurerm_storage_account.this will be created
  + resource "azurerm_storage_account" "this" {
      + name                     = "myappdevsa"
      ...
    }

  # module.storage_account.azurerm_storage_container.this will be created
  + resource "azurerm_storage_container" "this" {
      + name = "app-data"
      ...
    }

  # module.virtual_network.azurerm_virtual_network.this will be created
  + resource "azurerm_virtual_network" "this" {
      + name          = "myapp-dev-vnet"
      ...
    }

  # module.virtual_network.azurerm_subnet.this will be created
  + resource "azurerm_subnet" "this" {
      + name = "app-subnet"
      ...
    }

Plan: 5 to add, 0 to change, 0 to destroy.
```

**Read this plan carefully every time before applying.** You should see 5 resources to add:
1. Resource group
2. Storage account
3. Storage container
4. Virtual network
5. Subnet

Notice the resource addresses: `module.resource_group.azurerm_resource_group.this` — this is Terraform's way of saying "inside the `resource_group` module call, the resource named `azurerm_resource_group.this`."

### Command 4 — `terraform apply`

```
terraform apply -var-file="dev.tfvars"
```

Terraform shows the plan again and asks you to confirm:

```
Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value:
```

Type `yes` and press Enter.

**What you should see:**

```
module.resource_group.azurerm_resource_group.this: Creating...
module.resource_group.azurerm_resource_group.this: Creation complete after 2s [id=/subscriptions/.../resourceGroups/myapp-dev-rg]
module.storage_account.azurerm_storage_account.this: Creating...
module.virtual_network.azurerm_virtual_network.this: Creating...
...

Apply complete! Resources: 5 added, 0 changed, 0 destroyed.

Outputs:

resource_group_name   = "myapp-dev-rg"
storage_account_name  = "myappdevsa"
storage_blob_endpoint = "https://myappdevsa.blob.core.windows.net/"
vnet_name             = "myapp-dev-vnet"
subnet_id             = "/subscriptions/.../subnets/app-subnet"
applied_tags          = {
  "CostCenter"  = "CC-LEARN-001"
  "Environment" = "dev"
  "ManagedBy"   = "Terraform"
  "Project"     = "myapp"
}
```

**Your Azure resources are now live.**

### Verify in Azure Portal

1. Go to `portal.azure.com` in your browser
2. Click **Resource Groups** in the left menu
3. Find `myapp-dev-rg`
4. Click it — you should see the Storage Account and Virtual Network inside it

---

## 11. Understanding What Just Happened

### The data flow you just executed

```
dev.tfvars
    │
    │  (you passed these values with -var-file)
    ▼
root variables.tf
    │
    │  (terraform read your variables and computed locals)
    ▼
root locals.tf  →  name_prefix = "myapp-dev"
                   storage_name = "myappdevsa"
                   common_tags = { Environment = "dev" ... }
    │
    │  (root main.tf called the modules and passed values in)
    ▼
module "resource_group" call
    │  source = "./modules/resource-group"
    │  name   = "myapp-dev-rg"
    │  location = "eastus"
    │  tags   = { ... }
    ▼
modules/resource-group/variables.tf  (received the values)
modules/resource-group/main.tf       (created the resource in Azure)
modules/resource-group/outputs.tf    (returned .name, .id, .location)
    │
    │  (outputs returned up to root main.tf)
    ▼
module.resource_group.name     = "myapp-dev-rg"   ← used by storage and vnet modules
module.resource_group.location = "eastus"          ← used by storage and vnet modules
```

### Why the creation order was correct

You did not tell Terraform "create the resource group first, then the storage account." Terraform figured this out itself by reading the references in your root `main.tf`:

```hcl
module "storage_account" {
  resource_group_name = module.resource_group.name   # ← this reference
}
```

Because `storage_account` references `resource_group`'s output, Terraform knows `resource_group` must be created first. This is called an **implicit dependency** and it is how Terraform always determines creation order — through references, not explicit instructions.

---

## 12. Changing a Module — What Happens Next

This is a critical exercise. Understanding what happens when you change a module is what makes you confident using them.

### Exercise — Add a new tag to all resources

Right now your tags are:

```
Environment, ManagedBy, Project, CostCenter
```

Suppose your team decides every resource must also have a `CreatedBy` tag.

**You only change ONE place** — `locals.tf` in the root:

```hcl
# locals.tf  — add CreatedBy to common_tags
locals {
  name_prefix  = "${var.project}-${var.environment}"
  storage_name = lower(replace("${var.project}${var.environment}sa", "-", ""))

  common_tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.project
    CostCenter  = var.cost_center
    CreatedBy   = "TerraformLearner"   # ← new tag added here
  }
}
```

Now run plan:

```
terraform plan -var-file="dev.tfvars"
```

You should see:

```
  ~ module.resource_group.azurerm_resource_group.this will be updated in-place
      ~ tags = {
          + "CreatedBy"   = "TerraformLearner"
            "CostCenter"  = "CC-LEARN-001"
            ...
        }

  ~ module.storage_account.azurerm_storage_account.this will be updated in-place
  ~ module.virtual_network.azurerm_virtual_network.this will be updated in-place

Plan: 0 to add, 3 to change, 0 to destroy.
```

**All three resources get the new tag** — from one change in one place. This is the power of modules combined with a shared locals map. You changed `local.common_tags` once and it propagated to every module that uses `tags = local.common_tags`.

Run apply to make it real:

```
terraform apply -var-file="dev.tfvars"
```

---

## 13. Cleaning Up

When you are done practising, delete all the Azure resources to avoid charges.

```
terraform destroy -var-file="dev.tfvars"
```

Terraform shows everything it will delete:

```
Plan: 0 to add, 0 to change, 5 to destroy.

Do you really want to destroy all resources?
  Terraform will destroy all your managed infrastructure, as shown above.
  There is no undo. Only 'yes' will be accepted to confirm.

  Enter a value:
```

Type `yes` and press Enter.

```
Destroy complete! Resources: 5 destroyed.
```

Go back to the Azure portal and confirm `myapp-dev-rg` is gone.

---

## 14. Common Errors and How to Fix Them

### Error: `No configuration files`

```
Error: No configuration files
```

**Cause:** You ran `terraform init` or `terraform plan` from the wrong folder.

**Fix:** Make sure you are in the root project folder, not inside a module folder. In the VS Code terminal:

```
cd C:\Users\YourName\Documents\terraform-modules-project
```

---

### Error: `An argument named X is not expected here`

```
Error: An argument named "nam" is not expected here.
```

**Cause:** Typo in a variable name. You typed `nam` instead of `name`.

**Fix:** Check the variable name in the module's `variables.tf`. The name in the module call must match exactly.

---

### Error: `Error: The storage account named X is already taken`

```
StorageAccountAlreadyTaken: The storage account named "myappdevsa" is already taken.
```

**Cause:** Storage account names are globally unique across all of Azure. Another person or account already has that name.

**Fix:** Change the `project` variable in `dev.tfvars` to something more unique:

```hcl
project = "myapp2024abc"
```

---

### Error: `module.X.Y is not defined`

```
Error: Unsupported attribute; This object does not have an attribute named "primary_web_endpoint".
```

**Cause:** You are trying to reference an output that does not exist in the module's `outputs.tf`.

**Fix:** Open the module's `outputs.tf` and check the exact output name. Reference it exactly as it appears there.

---

### Error: `ARM_CLIENT_SECRET` authentication failure

```
Error: building AzureRM Client: ...
```

**Cause:** The environment variables from Section 3.7 are not set, or the values are wrong.

**Fix:**

```
echo %ARM_CLIENT_ID%
echo %ARM_CLIENT_SECRET%
```

If either prints a blank line, the variable is not set. Repeat Section 3.7, making sure to close and reopen Command Prompt after using `setx`.

---

### Error: `Invalid count argument` or unexpected resource changes

**Cause:** You changed a variable value that affects a resource name. Terraform must destroy the old resource and create a new one.

**Fix:** Read the plan carefully. A `-/+` symbol means destroy and recreate. If that is expected, type `yes`. If it is not expected, check what you changed.

---

## 15. Module Rules — Quick Reference

### The three files every module must have

| File | Purpose | What goes inside |
|---|---|---|
| `variables.tf` | Inputs — what the module needs | `variable` blocks with `type`, `description`, optional `default` and `validation` |
| `main.tf` | Resources — what the module creates | `resource` blocks using `var.something` |
| `outputs.tf` | Outputs — what the module gives back | `output` blocks with `value = resource_type.label.attribute` |

### Module call syntax in root `main.tf`

```hcl
module "your_label_here" {
  source = "./modules/folder-name"   # path to the module folder

  # Input variable names must match variables.tf in the module EXACTLY
  variable_name_one = value_to_pass
  variable_name_two = module.other_module.output_name
}
```

### Referencing a module's output

```hcl
module.module_label.output_name
```

Example:
```hcl
module.resource_group.name      # the "name" output from the resource_group module call
module.storage_account.id       # the "id" output from the storage_account module call
```

### Inside a module — resource label convention

```hcl
resource "azurerm_resource_group" "this" { }
#                                  ^^^^
#                           use "this" when there is
#                           only one of this resource per module
```

### The golden rule of modules

> A module must not know anything about the project that uses it.
> It only knows its own inputs and what resources it creates.
> The caller decides the values. The module decides the shape.

---

## Final Project File Checklist

Before running `terraform apply`, confirm you have all these files:

```
terraform-modules-project/
├── terraform.tf          ✓  provider + version config
├── variables.tf          ✓  project-level input declarations
├── locals.tf             ✓  name_prefix, storage_name, common_tags
├── main.tf               ✓  three module calls
├── outputs.tf            ✓  six outputs reading from modules
├── dev.tfvars            ✓  actual values for dev
│
└── modules/
    ├── resource-group/
    │   ├── main.tf       ✓  azurerm_resource_group.this
    │   ├── variables.tf  ✓  name, location, tags
    │   └── outputs.tf    ✓  name, id, location
    │
    ├── storage-account/
    │   ├── main.tf       ✓  azurerm_storage_account + container
    │   ├── variables.tf  ✓  name, resource_group_name, location, container_name...
    │   └── outputs.tf    ✓  name, id, primary_blob_endpoint, container_name
    │
    └── virtual-network/
        ├── main.tf       ✓  azurerm_virtual_network + subnet
        ├── variables.tf  ✓  name, resource_group_name, location, address_space...
        └── outputs.tf    ✓  vnet_id, vnet_name, subnet_id, subnet_name
```

**Total: 13 files. If any are missing, create them before running init.**

---

*You have now built three custom Terraform modules from scratch, called them from a root configuration, wired their outputs together, deployed real Azure infrastructure, modified a module and seen the change propagate, and destroyed everything cleanly. This is the complete module workflow used in professional DevOps teams.*
