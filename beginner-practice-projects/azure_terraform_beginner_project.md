# Terraform Beginner Practice Project — Azure Edition

---

## 1. Project Overview

### What You're Building

**A Static Website Hosting Infrastructure on Azure using Terraform**

You will provision a complete Azure infrastructure that hosts a static website (HTML/CSS) using **Azure Storage Account** with the static website feature enabled — all defined as code using Terraform.

Think of it as your first real piece of cloud infrastructure, written in a language that can manage any cloud resource at any scale.

### Why This Matters

Azure Storage static website hosting is widely used in production for landing pages, documentation portals, and front-end SPAs. More importantly, this project teaches you the **core Terraform workflow** that applies to every cloud resource you'll ever provision:

```
Write → Init → Plan → Apply → Destroy
```

You will touch the **Azure Provider**, **Resource Groups**, **Storage Accounts**, **Storage Containers**, and **Terraform outputs** — the foundational building blocks that appear in every real Azure Terraform project.

### Scope Boundaries (Beginner Guard Rails)

- Azure only — no multi-cloud complexity
- No Virtual Machines, no VNets, no DNS zones
- No Terraform modules (yet)
- No remote backend — local `terraform.tfstate` only for now
- No CI/CD pipeline — manual `terraform apply` only
- Single environment: `dev` only

---

## 2. Naming Conventions

### Terraform Variable Names → `snake_case`

```
resource_group_name
storage_account_name
azure_location
environment_name
project_name
owner_name
```

### Azure Resource Names → `kebab-case` with a strict prefix pattern

Follow this exact pattern: `{project}-{env}-{resource-type}`

```
mysite-dev-rg               ← Resource Group
mysitedevsa                 ← Storage Account (no hyphens allowed by Azure!)
mysite-dev-container        ← Storage Container
```

> **Azure Storage Account names are the exception:** they must be **3–24 characters**, **lowercase letters and numbers only** — no hyphens, no underscores. Plan your naming accordingly.

### Terraform Resource Block Labels → `snake_case`

```hcl
resource "azurerm_resource_group"       "main_rg"          { }
resource "azurerm_storage_account"      "static_site_sa"   { }
resource "azurerm_storage_container"    "web_container"    { }
```

### File Naming → `snake_case`, strictly separated by concern

```
main.tf            ← resource definitions only
variables.tf       ← all input variable declarations
outputs.tf         ← all output value declarations
providers.tf       ← provider and terraform block configuration
terraform.tfvars   ← actual values (never commit secrets here)
```

> Separating `providers.tf` from `main.tf` is an Azure community best practice and scales cleanly as projects grow.

### Tag Conventions (apply to every resource)

| Tag Key       | Example Value   |
|---------------|-----------------|
| `Project`     | `mysite`        |
| `Environment` | `dev`           |
| `Owner`       | `your-name`     |
| `ManagedBy`   | `terraform`     |
| `CostCenter`  | `learning`      |

### Sample Data to Use

```hcl
# terraform.tfvars

project_name          = "mysite"
environment_name      = "dev"
azure_location        = "East US"
resource_group_name   = "mysite-dev-rg"
storage_account_name  = "mysitedevsa20240101"   # globally unique, no hyphens
owner_name            = "jane-doe"
```

> Append a date or initials to make the Storage Account name globally unique across all of Azure.

---

## 3. Core Components to Build

### Component 1 — Azure Provider and Terraform Block

**File:** `providers.tf`

Configure the `azurerm` provider and define the Terraform version constraints. This is the handshake between Terraform and Azure. You will also define the `features {}` block, which is required by the Azure provider even when left empty — a notorious beginner trip wire.

**You must define:**

- `terraform` block with `required_version` and `required_providers`
- `provider "azurerm"` block with a `features {}` block
- Provider version pinned to `~> 3.0` (do not leave it unpinned)
- Azure location sourced from a variable — never hardcoded

---

### Component 2 — Resource Group

**File:** `main.tf`

Every Azure resource must live inside a **Resource Group**. This is Azure's fundamental organizational boundary and is always the first resource you create. It is also the first dependency that every other resource in this project will reference.

**You must define:**

- `azurerm_resource_group` resource
- Name and location pulled from variables
- All five required tags applied

---

### Component 3 — Storage Account with Static Website Enabled

**File:** `main.tf`

Create the Storage Account and enable the static website feature on it. In Azure, static website hosting is a **property of the Storage Account itself**, toggled via a dedicated Terraform resource — not via a separate service.

**You must define:**

- `azurerm_storage_account` resource
  - `account_tier` = `"Standard"`
  - `account_replication_type` = `"LRS"` (cheapest, fine for dev)
  - Reference the Resource Group using its Terraform attribute — not a hardcoded string
- `azurerm_storage_account_static_website` resource (separate from the account itself)
  - `index_document` = `"index.html"`
  - `error_404_document` = `"error.html"`
- All five required tags on the Storage Account

---

### Component 4 — Variables and Outputs

**Files:** `variables.tf` and `outputs.tf`

Declare every input as a proper variable with a `type` and `description`. Expose the information you need after `apply` via outputs — this is how you confirm your infrastructure was created correctly.

**Variables to declare** (with `type` and `description` for each):

```
project_name
environment_name
azure_location
resource_group_name
storage_account_name
owner_name
```

**Outputs to expose:**

```
website_url             ← the public endpoint of your static site
storage_account_name    ← the actual provisioned name
resource_group_name     ← confirms which RG was created
primary_blob_endpoint   ← the raw blob service endpoint
```

---

## 4. Hints & Pitfalls

### Hint 1 — `features {}` Is Not Optional, Even If It Is Empty

The Azure provider (`azurerm`) **requires** a `features {}` block inside your provider configuration. If you omit it, Terraform will throw an error before it even connects to Azure. This is one of the most common first-run failures for Azure beginners.

The block can be completely empty at this stage, but it must be present:

```hcl
# This is the pattern — do not skip this block
provider "azurerm" {
  features {}
}
```

As you advance, this block is where you configure resource-specific behaviours like "what happens to a Key Vault when it's destroyed" — but for now, leave it empty.

---

### Hint 2 — Resource Dependencies Must Use Attribute References, Not Strings

When your Storage Account needs to reference the Resource Group, you might be tempted to just write the name as a plain string — after all, you already know what the name will be. **Do not do this.**

Always reference resources through their Terraform attributes:

```
# Wrong approach (string literal — Terraform doesn't know about the dependency)
resource_group_name = "mysite-dev-rg"

# Correct approach (attribute reference — Terraform builds the dependency graph)
resource_group_name = azurerm_resource_group.main_rg.name
```

When you use attribute references, Terraform automatically knows it must create the Resource Group **before** the Storage Account. With a plain string, it might try to create them simultaneously and fail.

---

### Hint 3 — Storage Account Name Restrictions Will Break Your Plan

Azure Storage Account names have strict rules that Terraform cannot warn you about at the `plan` stage — the error only surfaces during `apply` when Azure rejects the name:

- Maximum **24 characters**
- **Lowercase letters and numbers only** — no hyphens, no underscores, no uppercase
- Must be **globally unique** across all Azure accounts worldwide

If your `terraform apply` fails with a `StorageAccountAlreadyTaken` or `AccountNameInvalid` error, this is why. Validate your chosen name at [portal.azure.com](https://portal.azure.com) Storage Account creation screen before you even write your `.tfvars` — it has a live name-availability checker.

---

## 5. Real Environment Requirements

### Tools to Install Before Starting

```
Tool                  Version       Purpose
─────────────────────────────────────────────────────────
Terraform CLI         v1.6+         Core tool
Azure CLI             v2.50+        Authentication to Azure
VS Code               Any           Recommended editor
HashiCorp Terraform   Extension     Syntax highlighting + validation
  (VS Code Extension)
```

### Azure Authentication Setup

```bash
# Step 1 — Log in to Azure
az login

# Step 2 — Confirm your active subscription
az account show

# Step 3 — If you have multiple subscriptions, set the correct one
az account set --subscription "your-subscription-id"

# Step 4 — Verify Terraform can see your credentials
terraform init   # inside your project folder
```

> Terraform picks up Azure credentials automatically from the Azure CLI session. You do **not** need to put credentials inside your `.tf` files.

### Azure Account Requirements

```
Azure Subscription     Free tier (Azure Free Account) is sufficient
                       $200 credit for 30 days + always-free services
                       Storage Account LRS is always free up to 5 GB
```

### Your Static Files (Create These Manually)

Create these two plain HTML files in your project folder. They do not need to be complex — even 5 lines of HTML is enough for this exercise.

```
index.html    ← your homepage (a basic "Hello from Azure" page is fine)
error.html    ← a simple "404 – Page Not Found" page
```

**Upload them manually after `terraform apply` completes**, either via the Azure Portal (Storage Browser) or the Azure CLI:

```bash
az storage blob upload \
  --account-name mysitedevsa20240101 \
  --container-name '$web' \
  --name index.html \
  --file ./index.html \
  --content-type 'text/html'
```

> The container for static website files in Azure is always named `$web` — this is created automatically by Azure when you enable static website hosting. You do not create this container in Terraform.

### Recommended Project Folder Structure

```
azure-static-site/
├── providers.tf
├── main.tf
├── variables.tf
├── outputs.tf
├── terraform.tfvars
├── index.html
└── error.html
```

---

## 6. Workflow Cheat Sheet

```bash
# One-time setup — downloads the Azure provider plugin
terraform init

# Preview what Terraform will create — read this carefully before applying
terraform plan

# Create the actual Azure resources
terraform apply

# When you are done learning — destroy everything to avoid charges
terraform destroy
```

> Always run `terraform destroy` when you finish a practice session. Azure Storage costs are minimal, but building the habit of cleaning up resources is a professional discipline worth starting on day one.

---

*Built for learning. No modules. No remote state. No magic — just the fundamentals.*
