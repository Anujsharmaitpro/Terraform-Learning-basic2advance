# Terraform Workspaces — Managing Multiple Environments from One Codebase
## Deep-Dive Learning Guide | Beginner-First Edition | Azure Examples | PowerShell Throughout

---

## Before You Start

This guide is built from a live, unedited tutorial on Terraform
Workspaces — . That's actually the most realistic learning format there is. Every error that appeared
in the session is documented here with an explanation of *why* it
happened, not just the fix.

The original transcript uses AWS (EC2, S3) for its examples. Every
example in this guide has been rebuilt using Azure equivalents — Azure
Virtual Machines instead of EC2, Azure Storage Accounts instead of S3,
AKS instead of EKS — so the concepts map directly to what you've been
building throughout this series.

---

## Table of Contents

1. The Real Problem Workspaces Solve — A Story
2. Why Multiple `.tfvars` Files Alone Don't Fix It
3. What a Terraform Workspace Actually Is
4. The Default Workspace
5. Core Workspace Commands
6. How Workspaces Separate State Files
7. The `terraform.workspace` Variable
8. The `lookup()` Function + `terraform.workspace` Pattern
9. Best Practices — Per-Environment `.tfvars` Files
10. The Most Dangerous Mistake With Workspaces
11. Workspaces vs Separate Folders/Projects — When to Use Which
12. Full Working Azure Example
13. Common Mistakes and Fixes
14. Practice Exercises
15. Practice Project 1 — DevStream Media (Beginner)
16. Practice Project 2 — FinCore Banking Platform (Intermediate)
17. Summary Reference

---

## 1. The Real Problem Workspaces Solve — A Story

Picture this situation, directly from the transcript:

You are a DevOps engineer. A team called XYZ submits a Jira ticket
asking for an Azure VM and a Storage Account for their development
environment. You're good at Terraform, so instead of doing it manually
and then repeating yourself for every future team that asks the same
thing, you build a reusable **module** — a parameterized template that
any team can consume without rewriting the resource blocks.

XYZ tests it in `dev`. It works. They're happy. Then they come back:

> "Abhishek, this is great. But we also need a `staging` environment
> where the VM should be `Standard_D2s_v3` instead of `Standard_B1s`,
> and a `prod` environment using `Standard_D4s_v3`. Do we have to
> copy all the files again for each environment?"

If you have **3 environments**, that's 3 copies of `main.tf`,
3 copies of `variables.tf`, and 3 copies of your module to keep in
sync forever. If you have **10 environments**, that's 10 copies.
This scales terribly.

**Terraform Workspaces solve exactly this problem** — write one
codebase, create separate workspaces for each environment, and let
each workspace maintain its own completely independent state file.

---

## 2. Why Multiple `.tfvars` Files Alone Don't Fix It

Your first instinct might be: "Just write one `main.tf` and create
`dev.tfvars`, `staging.tfvars`, `prod.tfvars` for the different
values." That feels clean. Here's why it breaks:

```
my-project/
  main.tf
  variables.tf
  dev.tfvars         <- instance_type = Standard_B1s
  staging.tfvars     <- instance_type = Standard_D2s_v3
  prod.tfvars        <- instance_type = Standard_D4s_v3
  terraform.tfstate  <- ONE state file for ALL three environments
```

The state file problem: Terraform has ONE state file in this folder by
default. When you run `terraform apply -var-file="dev.tfvars"` it
records that a `Standard_B1s` VM exists. When you then run
`terraform apply -var-file="staging.tfvars"`, Terraform does not
create a *second* VM — it looks at the existing state, sees a
`Standard_B1s` VM, and asks: "Should I *modify* this existing VM to
become `Standard_D2s_v3`?" or worse: "Should I *destroy* this and
create a new one?"

The resources are meant to be **separate and independent**.
The state file confusion means they aren't treated that way.

Workspaces fix this by giving each environment its own isolated state
file — so `dev`, `staging`, and `prod` never interfere with each other.

---

## 3. What a Terraform Workspace Actually Is

A **Terraform Workspace** is a named, isolated state file within the
same backend configuration. Think of it as a drawer in a filing
cabinet — the cabinet (your Terraform project files) is the same for
all drawers, but each drawer (workspace) holds completely separate
records (state files) for the infrastructure it manages.

```
my-project/
  main.tf              <- ONE shared codebase
  variables.tf
  modules/
  terraform.tfstate.d/
    dev/
      terraform.tfstate  <- dev environment's own state
    staging/
      terraform.tfstate  <- staging environment's own state
    prod/
      terraform.tfstate  <- prod environment's own state
```

This separation means you can:
- Destroy the `dev` environment without touching `staging` or `prod`
- Apply changes to `staging` first to test them before touching `prod`
- Give different teams access to different workspaces
- Use exactly the same `.tf` files for all of them

---

## 4. The Default Workspace

Every Terraform project already has one workspace, even if you've
never typed the word "workspace" in your life: it's called `default`.
When you run `terraform init` on a fresh project and start applying,
you're working in the `default` workspace.

```powershell
# Confirm which workspace you're currently in
terraform workspace show
# Output: default
```

The `default` workspace is special in one way: it cannot be deleted.
Every other workspace you create can be deleted; `default` is permanent.

For real multi-environment projects you'll almost never work in
`default` directly — you'll create named workspaces for each
environment and work from those instead.

---

## 5. Core Workspace Commands

These are the five commands you'll use constantly. Learn them in
this order — they build on each other naturally.

**PowerShell:**

```powershell
# 1. List all workspaces that exist in this project
#    An asterisk (*) marks which one you're currently in
terraform workspace list

# 2. Show just the current workspace name (useful in scripts)
terraform workspace show

# 3. Create a new workspace AND immediately switch into it
terraform workspace new dev
terraform workspace new staging
terraform workspace new prod

# 4. Switch to an existing workspace (does NOT create it if missing)
terraform workspace select staging

# 5. Delete a workspace (only works when NOT currently in it,
#    and only when the workspace has no resources in its state —
#    i.e., you've already destroyed everything in it)
terraform workspace delete dev
```

### Seeing them in action

```powershell
# Start in default
terraform workspace show     # default

# Create all three environment workspaces
terraform workspace new dev
terraform workspace new staging
terraform workspace new prod

# See all four now exist
terraform workspace list
# Output:
#   default
# * prod        <- asterisk shows you're currently in prod
#   dev
#   staging

# Switch back to dev
terraform workspace select dev
terraform workspace show     # dev
```

---

## 6. How Workspaces Separate State Files

When you are in the `default` workspace, Terraform stores state in
`terraform.tfstate` in your project root — exactly as you've seen
throughout this series.

When you create and use a **named workspace**, Terraform automatically
creates a folder structure inside `terraform.tfstate.d/`:

```
terraform.tfstate.d/
  dev/
    terraform.tfstate    <- only records dev resources
  staging/
    terraform.tfstate    <- only records staging resources
  prod/
    terraform.tfstate    <- only records prod resources
```

This means: when you are in the `dev` workspace and run
`terraform apply`, Terraform reads and writes ONLY the dev state file.
It has absolutely no knowledge of what resources exist in staging or
prod, and cannot accidentally modify them.

**PowerShell — confirming this after creating workspaces:**

```powershell
terraform workspace new dev
terraform workspace new staging

# Check what folders now exist
Get-ChildItem -Path "terraform.tfstate.d" -Recurse
```

---

## 7. The `terraform.workspace` Variable

Terraform provides one built-in variable you can use *anywhere* in
your configuration — without declaring it yourself, without adding it
to `variables.tf`. It always holds the name of the workspace you're
currently in:

```hcl
terraform.workspace
# "dev"     when you're in the dev workspace
# "staging" when you're in the staging workspace
# "prod"    when you're in the prod workspace
```

This single variable is what makes one codebase intelligent across
environments. You can use it to:
- Name resources differently per environment
- Pick a different VM size per environment
- Add a tag showing which workspace created the resource
- Conditionally create resources that only exist in prod

```hcl
resource "azurerm_resource_group" "rg" {
  # Resource group name now automatically includes the environment name
  name     = "myapp-${terraform.workspace}-rg"
  location = "East US"

  tags = {
    Environment = terraform.workspace    # "dev", "staging", or "prod"
    ManagedBy   = "Terraform"
  }
}
```

When in `dev` workspace: creates `myapp-dev-rg`
When in `staging` workspace: creates `myapp-staging-rg`
When in `prod` workspace: creates `myapp-prod-rg`

One resource block. Three different, correctly-named resource groups.
No code duplication.

---

## 8. The `lookup()` Function + `terraform.workspace` Pattern

This is the most powerful pattern in the transcript and the one the
instructor shows as a live demo. It lets you define a map of
environment-specific values and automatically select the right one
based on the current workspace.

### The pattern in full

```hcl
variable "vm_size" {
  description = "VM size per environment — selected automatically by workspace"
  type        = map(string)
  default = {
    dev     = "Standard_B1s"
    staging = "Standard_D2s_v3"
    prod    = "Standard_D4s_v3"
  }
}
```

Then, inside the resource that needs this value:

```hcl
resource "azurerm_linux_virtual_machine" "vm" {
  name                = "myapp-${terraform.workspace}-vm"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  # lookup(map, key, default_if_key_missing)
  # terraform.workspace is "dev", "staging", or "prod" automatically
  size = lookup(var.vm_size, terraform.workspace, "Standard_B1s")
  # ...
}
```

### Tracing through what happens in each workspace

```
In "dev" workspace:
  terraform.workspace = "dev"
  lookup(var.vm_size, "dev", "Standard_B1s")
  -> looks in var.vm_size for the key "dev"
  -> finds "Standard_B1s"
  -> VM is created as Standard_B1s

In "staging" workspace:
  terraform.workspace = "staging"
  lookup(var.vm_size, "staging", "Standard_B1s")
  -> finds "Standard_D2s_v3"
  -> VM is created as Standard_D2s_v3

In "prod" workspace:
  terraform.workspace = "prod"
  lookup(var.vm_size, "prod", "Standard_B1s")
  -> finds "Standard_D4s_v3"
  -> VM is created as Standard_D4s_v3

In an unknown workspace (e.g., "hotfix"):
  lookup(var.vm_size, "hotfix", "Standard_B1s")
  -> "hotfix" not found in the map
  -> falls back to the default: "Standard_B1s"
```

The third argument to `lookup()` is the fallback — always provide one,
so an unknown workspace doesn't crash your apply; it gets a sensible
default instead.

### Why this is better than environment-specific files

You've now replaced three separately-maintained `dev.tf`, `staging.tf`,
`prod.tf` configuration sets with one variable map and one `lookup()`
call. Adding a fourth environment (`preproduction`, `testing`, whatever
it might be) means adding exactly one line to the map — nothing else
changes anywhere in the codebase.

---

## 9. Best Practices — Per-Environment `.tfvars` Files

The instructor recommends combining workspaces with per-environment
`.tfvars` files for values that change between environments but don't
fit neatly into a single `lookup()` map. The correct workflow:

```powershell
# Switch to the environment you want to apply for
terraform workspace select dev
terraform apply -var-file="dev.tfvars"

terraform workspace select staging
terraform apply -var-file="staging.tfvars"

terraform workspace select prod
terraform apply -var-file="prod.tfvars"
```

**Example `.tfvars` structure:**

`dev.tfvars`:
```hcl
location     = "East US"
cost_center  = "CC-DEV-100"
instance_count = 1
```

`staging.tfvars`:
```hcl
location     = "East US"
cost_center  = "CC-STG-200"
instance_count = 2
```

`prod.tfvars`:
```hcl
location     = "West US 2"
cost_center  = "CC-PRD-300"
instance_count = 3
```

The `vm_size` is handled automatically by the `lookup()` pattern
(Section 8); other values that need explicit per-environment overrides
go here in the `.tfvars` file.

---

## 10. The Most Dangerous Mistake With Workspaces

The instructor flags this explicitly, and it's the single most
important operational warning in the entire video: always verify which
workspace you are in before running `terraform destroy` or
`terraform apply`.

```powershell
# ALWAYS run this before any destructive operation
terraform workspace show
```

If you intend to destroy the `staging` environment but you are
actually in the `prod` workspace, `terraform destroy` will destroy
production. The confirmation message will show "prod" — but if you
type "yes" without reading it carefully, the damage is done.

**PowerShell — a safe destroy pattern:**

```powershell
# Confirm workspace before every destructive action
$current = terraform workspace show
Write-Host "Currently in workspace: $current"
Write-Host "Do you really want to destroy $current? (yes/no)"
$confirm = Read-Host

if ($confirm -eq "yes") {
  terraform destroy -var-file="$current.tfvars"
} else {
  Write-Host "Aborted. No changes made."
}
```

This forces a conscious acknowledgment of the workspace before
proceeding — exactly the kind of safeguard you'd add in a real team
environment.

---

## 11. Workspaces vs Separate Folders/Projects — When to Use Which

Workspaces are not always the right answer. Worth knowing precisely
when they fit and when something else is better:

**Use workspaces when:**
- The infrastructure is structurally identical across environments
  (same resources, same topology, just different sizes/counts)
- You want one codebase for all environments
- The differences can be expressed through `lookup()` maps or
  per-environment `.tfvars` files

**Use separate folders (or separate Terraform projects) when:**
- Different environments have genuinely different resources (prod has
  a CDN, dev doesn't; prod has multiple availability zones, dev is
  single-zone)
- Environments are managed by different teams with different access
  controls
- You want a hard physical separation where it's structurally
  impossible for a `dev` apply to touch `prod` anything — not just
  logically separated by workspace selection

The HCP Terraform (Day 25 material) approach — separate workspaces per
environment, each with their own variables and trigger rules —
combines the best of both: a shared module library with environment-
specific execution contexts, each with independently scoped credentials.

---

## 12. Full Working Azure Example

Everything from the transcript, rebuilt for Azure. This is the
complete working pattern — not a snippet.

**`main.tf`**
```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "${var.project_name}-${terraform.workspace}-rg"
  location = var.location

  tags = {
    Environment = terraform.workspace
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

resource "azurerm_virtual_network" "vnet" {
  name                = "${var.project_name}-${terraform.workspace}-vnet"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = [lookup(var.vnet_cidr, terraform.workspace, "10.0.0.0/16")]
}

resource "azurerm_subnet" "subnet" {
  name                 = "${var.project_name}-${terraform.workspace}-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [lookup(var.subnet_cidr, terraform.workspace, "10.0.1.0/24")]
}

resource "azurerm_storage_account" "storage" {
  name                     = "${var.project_name}${terraform.workspace}sa"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = lookup(var.storage_tier, terraform.workspace, "Standard")
  account_replication_type = lookup(var.storage_replication, terraform.workspace, "LRS")
}
```

**`variables.tf`**
```hcl
variable "project_name" {
  type        = string
  description = "Short project name used as a prefix in all resource names"
  default     = "myapp"
}

variable "location" {
  type        = string
  description = "Azure region for all resources in this workspace"
}

variable "vnet_cidr" {
  type        = map(string)
  description = "VNet CIDR block per environment"
  default = {
    dev     = "10.0.0.0/16"
    staging = "10.1.0.0/16"
    prod    = "10.2.0.0/16"
  }
}

variable "subnet_cidr" {
  type        = map(string)
  description = "Subnet CIDR block per environment"
  default = {
    dev     = "10.0.1.0/24"
    staging = "10.1.1.0/24"
    prod    = "10.2.1.0/24"
  }
}

variable "storage_tier" {
  type        = map(string)
  description = "Storage account performance tier per environment"
  default = {
    dev     = "Standard"
    staging = "Standard"
    prod    = "Premium"
  }
}

variable "storage_replication" {
  type        = map(string)
  description = "Storage replication type per environment"
  default = {
    dev     = "LRS"
    staging = "GRS"
    prod    = "GZRS"
  }
}
```

**`dev.tfvars`**
```hcl
location = "East US"
```

**`prod.tfvars`**
```hcl
location = "West US 2"
```

**PowerShell — full workflow:**

```powershell
# Set credentials
$env:ARM_CLIENT_ID       = "your-client-id"
$env:ARM_CLIENT_SECRET   = "your-client-secret"
$env:ARM_TENANT_ID       = "your-tenant-id"
$env:ARM_SUBSCRIPTION_ID = "your-subscription-id"

# Initialise once (same project, all workspaces share this)
terraform init

# Create and deploy dev
terraform workspace new dev
terraform apply -var-file="dev.tfvars" --auto-approve

# Create and deploy staging
terraform workspace new staging
terraform apply -var-file="dev.tfvars" --auto-approve

# Create and deploy prod
terraform workspace new prod
terraform apply -var-file="prod.tfvars" --auto-approve

# Verify each workspace's resources are separate
terraform workspace select dev
terraform state list

terraform workspace select prod
terraform state list

# Tear down only dev — prod untouched
terraform workspace select dev
terraform workspace show                    # confirm: dev
terraform destroy -var-file="dev.tfvars" --auto-approve

# Verify prod still exists
terraform workspace select prod
terraform state list                        # prod resources still here
```

---

## 13. Common Mistakes and Fixes

**Mistake 1 — Running apply in the wrong workspace**

```powershell
# Wrong: you think you're in dev but you're in prod
terraform workspace show     # ALWAYS check before apply/destroy
```

**Mistake 2 — Forgetting `toset()` after workspace creation**

Not a workspace-specific mistake, but commonly hit here: if you
switch workspaces and init complains, run `terraform init` again —
workspaces don't reinitialise the backend, but if you've changed the
backend config since last init, a fresh init is needed.

**Mistake 3 — Using `terraform.workspace` directly in a resource name
that has a character limit**

Azure Storage Account names must be 3-24 characters, lowercase,
no hyphens. If `terraform.workspace` is `"staging"` and your prefix is
`"mycompanyapp"`, the combined `"mycompanyappstagingsa"` is 20 chars —
fine. But a longer prefix might exceed 24 characters.

```hcl
# Safe: derive and truncate
locals {
  sa_name = substr(lower("${var.project_name}${terraform.workspace}sa"), 0, 24)
}
```

**Mistake 4 — Expecting `workspace list` to show a number**

`terraform workspace list` shows workspace *names*, not counts of
resources. Check the actual state with `terraform state list` for that.

**Mistake 5 — Deleting a workspace that still has state**

```powershell
terraform workspace delete dev
# Error: Workspace "dev" is not empty. Destroy resources first with:
# terraform destroy, then retry.
```

You must `terraform destroy` the environment *before* you can delete
the workspace. The workspace holds a state file, and Terraform refuses
to delete a workspace that still records managed resources.

---

## 14. Practice Exercises

**Exercise 1** — Create three workspaces (`dev`, `staging`, `prod`)
and verify that applying a simple Storage Account to each one
creates three separate Storage Accounts, each with its own name, and
that destroying one does not affect the others.

**Exercise 2** — Add a `lookup()` pattern for `instance_count` —
dev gets `1`, staging gets `2`, prod gets `3` — to the full example
from Section 12.

**Exercise 3** — In PowerShell, write a script that:
1. Shows the current workspace
2. Asks for confirmation before running `terraform destroy`
3. Runs the destroy only if the user types the *exact* workspace name
   back (not just "yes" — they must type "dev" to destroy dev)

This simulates the kind of safety guard a real team would implement.

---

## 15. Practice Project 1 — DevStream Media (Beginner)

### Project Overview

DevStream Media is a video-streaming startup. They are moving their
infrastructure to Azure and need a DevOps engineer (you) to build a
reusable, environment-aware Terraform project that provisions their
core media-serving infrastructure. The project must run cleanly in
three environments — `dev`, `staging`, and `prod` — from a single
codebase using workspaces, with no resource collision or state
confusion between environments.

This is a beginner scope: no AKS, no databases, no complex networking.
Just the foundation every environment needs — a resource group, a
storage account for media files, a virtual network, and a single
subnet — built in a way that demonstrates workspace isolation cleanly.

### Naming Conventions

Follow these rules throughout. No exceptions — a real team's CI/CD
pipeline would fail on violations of these.

```
Terraform files:      snake_case (main.tf, variables.tf, outputs.tf)
Variable names:       snake_case (project_name, media_tier)
Local value names:    snake_case (storage_name, workspace_tags)
Resource labels:      snake_case (resource_group, media_storage)
Azure resource names: kebab-case with workspace embedded
                      {project}-{workspace}-{resource_type_abbreviation}
                      e.g. devstream-dev-rg, devstream-prod-sa
Storage account name: all lowercase, no hyphens, max 24 chars
                      e.g. devstreamprodsa (derived, not hardcoded)
Workspace names:      lowercase, no spaces (dev, staging, prod)
Variable files:       {workspace}.tfvars (dev.tfvars, prod.tfvars)
```

### Core Components to Build

**Component 1 — Resource Group, one per workspace**
The resource group name must embed the workspace name automatically —
no hardcoding. All resources in this project live inside it. Apply the
same tag set to every resource, including the workspace name and a
`CreatedOn` timestamp.

Functions to explore: `terraform.workspace`, `timestamp()`,
`formatdate()`, `merge()`

**Component 2 — Storage Account for media files**
The storage account name must be derived from the project name and
workspace, then sanitized to meet Azure's naming rules (lowercase,
no hyphens, 3-24 characters). The storage tier and replication type
must differ per environment — dev gets cheap/fast settings, prod gets
durable ones. Use the `lookup()` pattern, not hardcoded conditionals.

Functions to explore: `lookup()`, `lower()`, `replace()`, `substr()`

**Component 3 — Virtual Network and Subnet**
Each workspace gets its own non-overlapping CIDR range (they might
peer later, and overlapping CIDRs would block that). Drive the CIDR
blocks from a map variable, selected by workspace via `lookup()`.

Sample CIDR data to use:
```hcl
vnet_cidr = {
  dev     = "10.10.0.0/16"
  staging = "10.20.0.0/16"
  prod    = "10.30.0.0/16"
}
subnet_cidr = {
  dev     = "10.10.1.0/24"
  staging = "10.20.1.0/24"
  prod    = "10.30.1.0/24"
}
```

**Component 4 — Outputs**
After applying each workspace, outputs should clearly show: the
resource group name, the storage account name, the VNet address space,
and which workspace was used — so someone reading the output can
immediately verify the correct environment was targeted.

### Sample Variable Data (fill into your .tfvars files)

`dev.tfvars`:
```hcl
location    = "eastus"
cost_center = "DS-DEV-001"
```

`staging.tfvars`:
```hcl
location    = "eastus"
cost_center = "DS-STG-002"
```

`prod.tfvars`:
```hcl
location    = "westus2"
cost_center = "DS-PRD-003"
```

Per-environment storage tiers (put in `variables.tf` as a map default):
```hcl
storage_tier = {
  dev     = "Standard"
  staging = "Standard"
  prod    = "Premium"
}
storage_replication = {
  dev     = "LRS"
  staging = "GRS"
  prod    = "GZRS"
}
```

### Architect's Hints and Pitfalls

**Hint 1 — The timestamp tag will cause drift on every apply.**
If you put `timestamp()` directly in a tag, Terraform will show every
resource as "changed" on every subsequent apply because the timestamp
is always a fresh value. Research how `ignore_changes` inside a
`lifecycle` block specifically handles this, and apply it to only the
`CreatedOn` tag rather than all tags.

**Hint 2 — Your storage account name derivation can silently truncate
in a way that causes collisions.** If two differently-named projects
produce the same 24-character storage account name after truncation,
they'll conflict. Before you finalize the naming logic, work through
the full derived name for all three workspaces on paper, verify each
one is unique, and verify all three are under 24 characters.

**Hint 3 — `terraform workspace delete` will refuse if there is still
active state.** You must `terraform destroy` the environment first,
then delete the workspace. Trying to delete a workspace with active
resources in it is a safe no-op (Terraform refuses, nothing is
damaged), but it's easy to misread the error message and think
something went wrong with the destroy. Check `terraform state list`
after a destroy to confirm there are actually zero resources before
attempting the workspace deletion.

---

## 16. Practice Project 2 — FinCore Banking Platform (Intermediate)

### Project Overview

FinCore is a financial services company building a new cloud-native
platform on Azure. You're the infrastructure architect. They have four
environments: `dev`, `uat`, `staging`, and `prod`. The requirements
are significantly stricter than DevStream's — prod must have
zone-redundant storage and a larger VM SKU, UAT and staging need
moderate resources, and dev is minimal. The platform needs a private
DNS zone per environment, a Key Vault, and an AKS node pool definition
ready for their application team to deploy into.

This project introduces you to combining workspaces with modules
(the Day 20 pattern) — each major component is a module, and the root
`main.tf` uses workspace to wire the right values into each module call.

### Naming Conventions

```
Module names:         noun_noun (key_vault, private_dns, aks_config)
Variable names:       snake_case, descriptive (aks_node_count, dns_zone_name)
Local value names:    prefixed by purpose (env_tags, env_aks_size)
Azure resource names: {company}-{env}-{component}-{type}
                      e.g. fincore-prod-auth-kv, fincore-uat-cluster-aks
DNS zone name:        {workspace}.fincore.internal
                      e.g. dev.fincore.internal, prod.fincore.internal
Workspace names:      lowercase (dev, uat, staging, prod)
Module folder names:  snake_case in modules/ directory
```

### Core Components to Build

**Component 1 — Environment-aware Resource Group + Tag Module**
Build a module that accepts the workspace name, cost center, and
compliance tier as inputs and produces a consistently-tagged resource
group. The compliance tier should differ: dev is `"non-compliant"`,
all others are `"pci-compliant"` — derive this with a conditional
expression using `terraform.workspace`, not with a passed variable.

Functions to explore: `terraform.workspace` in conditional expressions,
module input/output pattern from Day 20

**Component 2 — Key Vault per Environment**
Each workspace gets its own Key Vault. The soft-delete retention days
should differ: dev=7, uat=30, staging=60, prod=90. The Key Vault
name must be globally unique — combine the workspace name with a
`random_string` resource (or a project prefix) to guarantee that.
The purge protection setting should be `false` for dev and `true` for
all other environments — a genuine financial compliance requirement.

Sample data for the module:
```hcl
kv_retention_days = {
  dev     = 7
  uat     = 30
  staging = 60
  prod    = 90
}
```

Functions to explore: `lookup()`, `random_string`, conditional
expression for purge protection, `azurerm_key_vault`

**Component 3 — Private DNS Zone**
Provision a private Azure DNS Zone named `{workspace}.fincore.internal`
linked to the environment's VNet. This gives each environment's
services a clean internal naming scheme without manual DNS record
management. The zone name must be fully automatic — derived from
`terraform.workspace`, not user-typed.

Sample zone names to verify your logic produces:
```
dev workspace     -> dev.fincore.internal
uat workspace     -> uat.fincore.internal
staging workspace -> staging.fincore.internal
prod workspace    -> prod.fincore.internal
```

Resources to research: `azurerm_private_dns_zone`,
`azurerm_private_dns_zone_virtual_network_link`

**Component 4 — AKS Cluster Definition (Node Pool Only)**
Provision an AKS cluster with a single system node pool. Node count
and VM size must differ by workspace. Also: prod must have
availability zones enabled on the node pool; dev should not (to save
cost). Use the `lookup()` pattern for size and count, and a
conditional expression for the zones argument.

Sample node pool data:
```hcl
aks_node_count = {
  dev     = 1
  uat     = 2
  staging = 2
  prod    = 3
}
aks_vm_size = {
  dev     = "Standard_B2s"
  uat     = "Standard_D2s_v3"
  staging = "Standard_D2s_v3"
  prod    = "Standard_D4s_v3"
}
```

Zones: `["1", "2", "3"]` for prod, `null` for everything else.
Derive this with a conditional expression — do not use a map for it.

### Sample Variable Data

`dev.tfvars`:
```hcl
location     = "eastus"
cost_center  = "FC-DEV-001"
project_name = "fincore"
```

`uat.tfvars`:
```hcl
location     = "eastus"
cost_center  = "FC-UAT-002"
project_name = "fincore"
```

`staging.tfvars`:
```hcl
location     = "eastus"
cost_center  = "FC-STG-003"
project_name = "fincore"
```

`prod.tfvars`:
```hcl
location     = "westus2"
cost_center  = "FC-PRD-004"
project_name = "fincore"
```

### Architect's Hints and Pitfalls

**Hint 1 — You have four workspaces, not three.**
`dev`, `uat`, `staging`, and `prod`. Every `lookup()` map in your
`variables.tf` must include all four keys. Missing a key in the map
for one workspace doesn't cause an error — `lookup()` silently falls
back to the default value, which may not be appropriate for that
environment. After writing each map, check every key is there, and
that the fallback default is genuinely safe for an unknown workspace.

**Hint 2 — AKS with `null` zones versus `[]` empty list are not the
same thing.** If the zones argument on a node pool is set to `null`,
Azure creates VMs without zone pinning (fine for dev). If it's set to
`["1", "2", "3"]`, Azure distributes VMs across three zones (required
for prod HA). Setting it to an empty list `[]` might produce an error
or unexpected behavior depending on the provider version — use
`null` deliberately for non-zone environments, not an empty list.

**Hint 3 — Key Vault names are globally unique within Azure,
short (3-24 chars), and must start with a letter.** Your `{env}` prefix
is at most 7 characters (`staging`). Your project prefix is 7
characters (`fincore`). Combined with a separator, that's already 15
characters before any random suffix — check your derived name for all
four workspaces fits within 24 characters, and verify the first
character is always a letter, not a number or symbol that a randomly
generated string suffix might produce.

---

## 17. Summary Reference

```
terraform workspace list    -> see all workspaces (* = current)
terraform workspace show    -> print just the current workspace name
terraform workspace new X   -> create workspace "X" and switch to it
terraform workspace select X -> switch to existing workspace "X"
terraform workspace delete X -> delete empty workspace "X" (must destroy first)

terraform.workspace          -> built-in variable, always = current workspace name

lookup(var.my_map, terraform.workspace, "default_value")
  -> picks the right value for the current environment from a map
  -> falls back safely to the default if the workspace name isn't a key

Key rules:
  - One codebase, many workspaces
  - Each workspace has its own isolated state file
  - terraform.workspace is always available without declaring it
  - Always run "terraform workspace show" before destroy/apply
  - Destroy resources before deleting a workspace
  - Workspace names: lowercase, no spaces, memorable env names
```

---

*This guide covers: the real-world multi-environment problem Terraform
Workspaces solve, why multiple .tfvars files without workspaces still
cause state file conflicts, the definition of a workspace as an
isolated named state file within one backend, the default workspace
and its special non-deletable status, all five workspace commands (list,
show, new, select, delete) with PowerShell examples, the filesystem
structure of per-workspace state files under terraform.tfstate.d, the
built-in terraform.workspace variable and how to use it in resource
names and tag values, the lookup() + terraform.workspace pattern for
per-environment value selection with fallback defaults, best practices
for combining workspaces with per-environment .tfvars files, the
workspace destroy safety risk and a PowerShell safety script, when
workspaces are the right tool versus separate projects, a full
working Azure example (resource group, VNet, subnet, storage account),
all common mistakes with exact error messages, and two structured
practice project briefs (DevStream Media beginner, FinCore Banking
intermediate) with naming conventions, sample data, components, and
architect hints — no solution code provided.*
