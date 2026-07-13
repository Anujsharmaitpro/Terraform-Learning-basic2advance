# Creating Azure Resources with Terraform
## Deep-Dive Learning Guide — Day 3 / 28 Days of Easy Terraform
### Beginner-First Edition | Full Azure Demo Walkthrough

---

## Before You Start

This is Day 3. By now you know:
- Day 1: What Terraform is and why it exists
- Day 2: What providers are and how version constraints work

Today is your **first hands-on day**. You will write real Terraform code,
authenticate to Azure, and actually provision cloud resources — then
modify and destroy them. Every step the instructor took is explained here
in full, including the mistakes made and why they happened.

---

## Table of Contents

1. What You Will Build Today (The Big Picture)
2. How to Read Terraform Documentation (A Skill You Need Forever)
3. The Terraform File Structure — Every File Explained
4. Writing Your First Resource Block — Anatomy of `azurerm_resource_group`
5. Writing Your Second Resource Block — `azurerm_storage_account`
6. What Is a Dependency? (The Most Important Concept in This Video)
7. Implicit Dependency — The Recommended Approach
8. Explicit Dependency — `depends_on`
9. Azure Authentication — Why You Can't Just Run `terraform apply`
10. What Is a Service Principal? (And Why You Need One)
11. Setting Up Authentication Step by Step
12. The Full `terraform init` → `plan` → `apply` Workflow
13. Reading `terraform plan` Output — Every Symbol Explained
14. Making Changes — Destructive vs Non-Destructive Operations
15. How Terraform Knows What to Change — Desired State vs Actual State
16. Deleting Resources — The Right Way and the Wrong Way
17. `terraform destroy` — The Safe Cleanup Command
18. The Complete Code — Everything in One Place
19. Common Mistakes from This Video (and How to Fix Them)
20. Practice Exercises
21. Complete Cheat Sheet

---

## 1. What You Will Build Today

By the end of this guide, you will have:

```
Azure Infrastructure Created:
─────────────────────────────────────────────
  azurerm_resource_group    "example"
  └── name:     "example-resources"
  └── location: "West Europe"
  └── tags:     { Environment = "Staging" }

  azurerm_storage_account   "example"
  └── name:                 "techtutorials101"
  └── resource_group_name:  (from the RG above)
  └── location:             (from the RG above)
  └── account_tier:         "Standard"
  └── account_replication:  "GRS" → changed to "LRS" mid-demo
─────────────────────────────────────────────
Total resources: 2
```

You will also:
- Authenticate to Azure using a Service Principal
- Run `terraform init`, `validate`, `plan`, `apply`
- Modify a resource and re-apply
- Understand the difference between destructive and non-destructive changes
- Clean up everything with `terraform destroy`

---

## 2. How to Read Terraform Documentation (A Skill You Need Forever)

Before writing a single line of code, the instructor showed exactly how
to use the Terraform documentation. This is a critical skill — you will
use it every single day as a Terraform practitioner.

### Where to find documentation

```
https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs
```

Or simply search: `terraform azure create storage account`

### What to look for on a provider page

When you land on the Azure RM provider page, you will see:

```
Providers
└── hashicorp (namespace — this is an official provider)
    └── azurerm (provider name)
        └── Version: 4.8.0 (latest) or choose older versions
```

The small "official" badge next to the provider name means HashiCorp
maintains it — this is the sign the instructor mentioned.

### How to navigate to a specific resource

Every resource has its own documentation page. For a storage account:

```
Registry → hashicorp/azurerm → Resources → azurerm_storage_account
```

The documentation page tells you:
- **Example Usage** — working code you can copy and adapt
- **Argument Reference** — every field you can configure
- **Attributes Reference** — fields the resource generates after creation
- **Import** — how to import existing resources into Terraform

### The workflow the instructor recommended

```
1. Search for the resource you want to create
2. Find it on the Terraform Registry
3. Copy the Example Usage as a starting point
4. Paste it into your .tf file
5. Modify the values to match your needs
6. Refer back to Argument Reference for any fields you're unsure about
```

This is not cheating — it is exactly how professional Terraform engineers work.

---

## 3. The Terraform File Structure

The instructor created a single `main.tf` file for this demo. Here is the
full structure of a well-organised Terraform project and what goes in each file:

```
day-03/
│
├── main.tf          ← Your infrastructure resources (what to create)
├── providers.tf     ← Provider configuration (which cloud + version)
├── variables.tf     ← Variable definitions (inputs)
├── outputs.tf       ← Output definitions (what to print after apply)
│
├── .terraform/      ← Created by terraform init (DO NOT edit manually)
│   └── providers/   ← Downloaded provider binaries live here
│
└── .terraform.lock.hcl  ← Version lock file (commit this to Git)
```

### Why does Terraform read all `.tf` files automatically?

Terraform reads every file in the current folder that ends in `.tf` and
treats them as one single configuration. The order of files doesn't matter.
The order of blocks within files doesn't matter either — Terraform figures
out what to create first based on dependencies, not file order.

This is why the instructor could put everything in one `main.tf` and it
still worked.

---

## 4. Writing Your First Resource Block — `azurerm_resource_group`

### What is an Azure Resource Group?

Think of a Resource Group as a **folder on your computer**. Every resource
you create in Azure (VMs, storage accounts, databases, networks) must live
inside a folder. That folder is the Resource Group.

Benefits:
- Delete the Resource Group and everything inside it is deleted too
- Apply permissions (RBAC) to the whole group at once
- See all resources for a project in one place
- Track costs by Resource Group

### The resource block

```hcl
resource "azurerm_resource_group" "example" {
  name     = "example-resources"
  location = "West Europe"

  tags = {
    Environment = "Staging"
  }
}
```

### Dissecting every part

**`resource`** — This is a Terraform keyword. It tells Terraform: "I am
declaring a piece of infrastructure to manage."

**`"azurerm_resource_group"`** — This is the **resource type**. It comes
directly from the Azure RM provider. The format is always:
`provideralias_resourcename`
- `azurerm` = the provider alias (from your `required_providers` block)
- `resource_group` = the type of Azure resource

**`"example"`** — This is the **local name** (also called a label or
reference name). It is NOT the name of the Azure resource — it is how
you refer to this resource INSIDE your Terraform code.

Think of it as a nickname. If you have two Resource Groups, you might call
them `"rg_web"` and `"rg_database"`. Terraform uses these nicknames to
understand your references.

**`name = "example-resources"`** — This IS the actual name that appears
in Azure. This is what you see in the Azure Portal.

**`location = "West Europe"`** — The Azure region where the Resource Group
lives. Valid Azure regions include:
```
"East US", "West US 2", "West Europe", "North Europe",
"Southeast Asia", "Australia East", "UK South", etc.
```

**`tags = { ... }`** — Tags are key-value labels you attach to Azure
resources. Used for cost tracking, environment identification, filtering.
Not required, but strongly recommended in real projects.

### What the full block looks like in context

```hcl
# This is in main.tf

resource "azurerm_resource_group" "example" {
#  ↑ keyword  ↑ resource type          ↑ local name (your nickname)

  name     = "example-resources"    # ← What appears in Azure Portal
  location = "West Europe"          # ← Azure region
  tags = {
    Environment = "Staging"         # ← Optional label
  }
}
```

---

## 5. Writing Your Second Resource Block — `azurerm_storage_account`

### What is an Azure Storage Account?

A Storage Account is Azure's fundamental storage service. It can store:
- **Blobs** — files, images, videos (like S3 in AWS)
- **Tables** — NoSQL data
- **Queues** — messages between services
- **Files** — file shares accessible via SMB protocol

Every Storage Account must live inside a Resource Group.

### The resource block

```hcl
resource "azurerm_storage_account" "example" {
  name                     = "techtutorials101"
  resource_group_name      = azurerm_resource_group.example.name
  location                 = azurerm_resource_group.example.location
  account_tier             = "Standard"
  account_replication_type = "GRS"
}
```

### The naming rules for Storage Accounts (this caused an error in the video!)

Azure Storage Account names have strict rules:
```
✓ 3 to 24 characters long
✓ Lowercase letters and numbers ONLY
✓ No hyphens (-), underscores (_), or spaces
✓ Must be GLOBALLY UNIQUE across all Azure (worldwide)
```

The instructor's first attempt used "tech-tutorials-101" with hyphens.
Terraform caught this with a validation error. The fix was to use
"techtutorials101" (no hyphens).

**Important:** This error came from Azure's API validation, not Terraform.
Terraform sent the request, Azure rejected it with the naming rules.

### `account_tier` — What does this mean?

The tier determines performance and cost:

| Tier | Use Case |
|---|---|
| `Standard` | General purpose — most common, lower cost |
| `Premium` | High-performance SSD storage — databases, I/O-intensive apps |

### `account_replication_type` — What does this mean?

Azure automatically replicates (copies) your data to protect against data loss:

| Code | Full Name | What It Does |
|---|---|---|
| `LRS` | Locally Redundant Storage | 3 copies in same data centre |
| `ZRS` | Zone Redundant Storage | 3 copies across 3 zones in same region |
| `GRS` | Geo-Redundant Storage | 6 copies — 3 in primary region, 3 in secondary region |
| `GZRS` | Geo-Zone Redundant Storage | Combines ZRS + GRS — most resilient |

The instructor started with `"GRS"` and later changed it to `"LRS"` to
demonstrate a non-destructive update.

---

## 6. What Is a Dependency? (The Most Important Concept in This Video)

### The problem Terraform needs to solve

Your `main.tf` has two resources:
1. A Resource Group
2. A Storage Account that lives INSIDE that Resource Group

The Storage Account CANNOT be created before the Resource Group exists.
The Resource Group must come first.

But here is the critical thing the instructor explained:

> **Terraform does NOT create resources in the order you write them in the file.**

Terraform reads your entire configuration, builds a dependency graph, and
decides the optimal creation order — often running multiple resources in
parallel if they don't depend on each other.

So you must explicitly tell Terraform: "This resource must be created before
that one." You do this through dependencies.

### Two types of dependencies in Terraform

```
1. Implicit Dependency  → Terraform figures it out from your code references
2. Explicit Dependency  → You manually declare it with depends_on
```

---

## 7. Implicit Dependency — The Recommended Approach

Implicit dependency happens when you **reference one resource's output
inside another resource's configuration**. Terraform sees the reference,
understands the relationship, and automatically creates in the correct order.

### How it works

```hcl
resource "azurerm_resource_group" "example" {
  name     = "example-resources"
  location = "West Europe"
}

resource "azurerm_storage_account" "example" {
  name                     = "techtutorials101"

  # This line creates an implicit dependency:
  resource_group_name = azurerm_resource_group.example.name
  #                     ↑ Resource type    ↑ local name ↑ attribute

  # This line also creates an implicit dependency:
  location            = azurerm_resource_group.example.location

  account_tier             = "Standard"
  account_replication_type = "GRS"
}
```

When Terraform reads `azurerm_resource_group.example.name`, it understands:
- "The storage account needs the name from the resource group"
- "The resource group must therefore exist first"
- "I will create the resource group before the storage account"

### How to read a resource reference

```
azurerm_resource_group  .  example  .  name
│                           │           │
│                           │           └── The attribute you want
│                           │               (name, location, id, etc.)
│                           │
│                           └── The local name (the nickname you gave it)
│
└── The resource type (from the resource block declaration)
```

### What attributes are available?

The Terraform documentation's **Attributes Reference** section lists
everything you can reference from a resource after it's created:

For `azurerm_resource_group`:
```
id       → The unique Azure Resource ID (generated after creation)
name     → The name you provided
location → The location you provided
tags     → The tags you provided
```

You can reference any of these inside other resources.

### Why is implicit dependency preferred?

- Less code to write
- Self-documenting — the reference makes the relationship obvious
- Terraform validates that the referenced resource actually exists

---

## 8. Explicit Dependency — `depends_on`

Sometimes Terraform cannot infer the dependency from code references alone.
For example, if Resource B needs Resource A to be ready, but B's config
doesn't directly reference any of A's attributes — Terraform won't know
about the dependency.

### The syntax

```hcl
resource "azurerm_storage_account" "example" {
  name                     = "techtutorials101"
  resource_group_name      = "example-resources"   # hardcoded, no reference
  location                 = "West Europe"          # hardcoded, no reference
  account_tier             = "Standard"
  account_replication_type = "GRS"

  # Explicitly declare: "wait for this resource before creating me"
  depends_on = [
    azurerm_resource_group.example    # Note: no quotes, no attribute
  ]
}
```

### `depends_on` vs implicit — side by side

```hcl
# IMPLICIT — recommended
resource_group_name = azurerm_resource_group.example.name
# Terraform sees the reference → knows to create RG first
# Also gets the actual value dynamically

# EXPLICIT — use when implicit isn't possible
resource_group_name = "example-resources"   # hardcoded
depends_on = [azurerm_resource_group.example]
# You tell Terraform manually
# But value is hardcoded — can get out of sync
```

### When to use `depends_on`

Use it when:
- A resource needs another resource to finish setting up (running a script,
  configuring a firewall) before it can be created
- The dependency isn't expressed through a direct attribute reference
- Working with `null_resource` or `local-exec` provisioners

In most normal scenarios, implicit dependency handles everything. The
instructor showed `depends_on` briefly for awareness but confirmed that
implicit dependency is the recommended approach for standard usage.

---

## 9. Azure Authentication — Why You Can't Just Run `terraform apply`

When you run `terraform apply`, Terraform needs to tell Azure: "Create
these resources in MY account, not someone else's."

Azure needs to know:
- WHO you are (authentication)
- WHAT you're allowed to do (authorization)

Without authentication, Azure rejects every request. You'll see errors like:
```
Error: building AzureRM Client: please ensure you have installed
Azure CLI and have logged in with `az login`
```

### Authentication methods for Azure + Terraform

| Method | Best For |
|---|---|
| `az login` (Azure CLI) | Local development on your own machine |
| Service Principal | CI/CD pipelines, automation, teams |
| Managed Identity | Resources running inside Azure (VMs, Container Apps) |
| OpenID Connect | GitHub Actions and other OIDC-compatible CI systems |

The instructor used **Service Principal** because it is the industry
standard for automation — not because it is the simplest.

For learning locally, `az login` alone works fine. The instructor chose to
demonstrate the professional approach.

---

## 10. What Is a Service Principal?

### The analogy

Your personal Azure account is like YOUR personal ID card. You use it to
log in to the Azure Portal as a human.

A **Service Principal** is like an **ID card for an application or script**.
It is a non-human identity that programs can use to authenticate to Azure.

```
Human uses:        Azure Active Directory Account (your login)
Script/automation: Service Principal (application identity)
```

### Why not use your personal account for automation?

- Personal accounts have MFA (multi-factor authentication) — scripts can't
  complete MFA prompts
- If you leave the company, your automation breaks
- You'd be giving your personal credentials to a pipeline — security risk
- Service Principals have scoped permissions — they only get what they need

### What a Service Principal consists of

When created, a Service Principal gives you four values:

```
ARM_CLIENT_ID       = "the service principal's app ID"
ARM_CLIENT_SECRET   = "the password for the service principal"
ARM_SUBSCRIPTION_ID = "your Azure subscription ID"
ARM_TENANT_ID       = "your Azure Active Directory tenant ID"
```

These four values are what Terraform uses to authenticate with Azure.

---

## 11. Setting Up Authentication — Step by Step

### Step 1 — Log into Azure CLI

```bash
az login
```

This opens a browser window. Log in with your personal Azure account.
The terminal will show your subscription details when done:

```json
[
  {
    "cloudName": "AzureCloud",
    "id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
    "isDefault": true,
    "name": "My Azure Subscription",
    "tenantId": "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy"
  }
]
```

### Step 2 — Create a Service Principal

```bash
az ad sp create-for-rbac \
  --name "az-terraform-demo" \
  --role "Contributor" \
  --scope "/subscriptions/YOUR_SUBSCRIPTION_ID"
```

Breaking this down:
- `az ad sp create-for-rbac` — create a service principal with RBAC role
- `--name "az-terraform-demo"` — a readable name for the service principal
- `--role "Contributor"` — gives it permission to create/modify/delete
  resources (but NOT manage permissions)
- `--scope "/subscriptions/..."` — limits it to your specific subscription

The output looks like:

```json
{
  "appId":      "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
  "displayName":"az-terraform-demo",
  "password":   "bbbbbbbbbbbb~BBBBBBBBB~bbbbbbbbbbbbbb",
  "tenant":     "cccccccc-cccc-cccc-cccc-cccccccccccc"
}
```

**IMPORTANT:** Copy and save these values immediately. The `password`
(client secret) is shown ONLY ONCE. You cannot retrieve it later.

### Step 3 — Set Environment Variables

Terraform's Azure provider automatically reads these four environment
variables for authentication:

```bash
export ARM_CLIENT_ID="aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
export ARM_CLIENT_SECRET="bbbbbbbbbbbb~BBBBBBBBB~bbbbbbbbbbbbbb"
export ARM_TENANT_ID="cccccccc-cccc-cccc-cccc-cccccccccccc"
export ARM_SUBSCRIPTION_ID="dddddddd-dddd-dddd-dddd-dddddddddddd"
```

On Windows (PowerShell):
```powershell
$env:ARM_CLIENT_ID="aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
$env:ARM_CLIENT_SECRET="bbbbbbbbbbbb~BBBBBBBBB~bbbbbbbbbbbbbb"
$env:ARM_TENANT_ID="cccccccc-cccc-cccc-cccc-cccccccccccc"
$env:ARM_SUBSCRIPTION_ID="dddddddd-dddd-dddd-dddd-dddddddddddd"
```

### Where the provider picks these up

When you have `provider "azurerm" { features {} }` in your code, the
Azure RM provider automatically reads the `ARM_*` environment variables.
You don't need to put credentials in your `.tf` files — and you should
NEVER put credentials in `.tf` files (they'd end up in Git).

### The instructor's debugging moment

The instructor had a shell variable `TF_VAR_environment` still set from
a previous session that interfered with the demo. His debugging method:

```bash
env | grep -i env    # list all environment variables matching "env"
```

This is a useful debugging command whenever something behaves unexpectedly.

---

## 12. The Full Workflow — Step by Step

### A helpful alias first

The instructor set a shell alias to save typing:

```bash
alias tf=terraform
```

Now `tf plan` works the same as `terraform plan`. This is a common
convention — you'll see it in many Terraform tutorials.

---

### Step 1 — `terraform init`

```bash
terraform init
# or: tf init
```

What it does:
1. Reads your `required_providers` block
2. Downloads the Azure RM provider binary to `.terraform/providers/`
3. Creates `.terraform.lock.hcl` with the exact version

Expected output:
```
Initializing the backend...
Initializing provider plugins...
- Finding hashicorp/azurerm versions matching "~> 4.0"...
- Installing hashicorp/azurerm v4.8.0...
- Installed hashicorp/azurerm v4.8.0 (signed by HashiCorp)

Terraform has been successfully initialized!
```

The instructor noted that on Mac, the downloaded file is a Unix binary.
On Windows it would be a `.exe` file. On Linux, a Linux binary. Terraform
automatically downloads the correct one for your operating system.

**What happens if you skip init?**

The instructor demonstrated this — running `terraform plan` before `init`:
```
Error: Inconsistent dependency lock file
...
To update the locked dependency selections to match a changed configuration,
run: terraform init
```

Always run `init` first. Run it again whenever you add a new provider.

---

### Step 2 — `terraform validate`

```bash
terraform validate
# or: tf validate
```

What it does:
- Checks your `.tf` files for syntax errors
- Checks for invalid argument names
- Does NOT connect to Azure — it is a local-only check
- Does NOT verify that your values are valid in Azure (that happens during plan)

Success:
```
Success! The configuration is valid.
```

The instructor used this after getting an error from `terraform plan` about
the storage account name containing hyphens. After fixing the name and
running validate:
```
Success! The configuration is valid.
```

---

### Step 3 — `terraform plan`

```bash
terraform plan
# or: tf plan
```

What it does:
1. Connects to Azure and checks what currently exists
2. Compares that to what your `.tf` files describe
3. Calculates the exact changes needed
4. Displays the plan — WITHOUT making any changes

**The error the instructor hit during plan:**
```
Error: "name" may only contain lowercase letters and numbers,
and must be between 3 and 24 characters long
```

This was NOT a Terraform error — it was Azure's API validation. Terraform
sent the plan to Azure's API, Azure rejected it with the naming rules,
Terraform surfaced the message to you. This is actually helpful — you
catch the error before anything is built.

**After fixing the name, the plan output looked like:**

```
Terraform will perform the following actions:

  # azurerm_resource_group.example will be created
  + resource "azurerm_resource_group" "example" {
      + id       = (known after apply)
      + location = "westeurope"
      + name     = "example-resources"
      + tags     = {
          + "Environment" = "Staging"
        }
    }

  # azurerm_storage_account.example will be created
  + resource "azurerm_storage_account" "example" {
      + id                       = (known after apply)
      + name                     = "techtutorials101"
      + resource_group_name      = "example-resources"
      + location                 = "westeurope"
      + account_tier             = "Standard"
      + account_replication_type = "GRS"
    }

Plan: 2 to add, 0 to change, 0 to destroy.
```

**Reading the plan output:**

```
+  (green)   → will be CREATED        ← both resources are new
~  (yellow)  → will be UPDATED in place
-  (red)     → will be DESTROYED
-/+(red)     → DESTROYED then RECREATED (more disruptive)
```

**The `(known after apply)` values:**

Some values like `id` don't exist yet — Azure generates them when the
resource is actually created. Terraform shows `(known after apply)` as a
placeholder. After `terraform apply`, these will have real values.

**Quick check trick the instructor showed:**

```bash
terraform plan | grep "will be created"
```

Filters output to show only the lines confirming new resources:
```
  # azurerm_resource_group.example will be created
  # azurerm_storage_account.example will be created
```

---

### Step 4 — `terraform apply`

```bash
terraform apply
# or: tf apply
```

Default behaviour — shows the plan again and prompts for confirmation:
```
Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value:
```

Type `yes` and press Enter. Terraform begins creating resources.

**To skip the prompt (for automation):**
```bash
terraform apply --auto-approve
# or: tf apply --auto-approve
```

After completion:
```
Apply complete! Resources: 2 added, 0 changed, 0 destroyed.
```

The resources now exist in Azure. You can verify them in the Azure Portal.

---

## 13. Reading `terraform plan` Output — Every Symbol Explained

Here is a comprehensive guide to every symbol you will encounter:

```
Symbol   Colour    Meaning
──────   ──────    ───────────────────────────────────────────────────────
  +      green     CREATED — this resource does not exist and will be made
  ~      yellow    UPDATED — resource exists; some attributes will change
  -      red       DESTROYED — this resource will be deleted
  -/+    red       REPLACED — destroyed then recreated (breaking change)
  <=     cyan      READ — data source will be read (not created)
```

### The summary line

At the end of every plan, Terraform gives you a summary:

```
Plan: 2 to add, 1 to change, 0 to destroy.
       ↑          ↑            ↑
       New        Updates      Deletions
```

Always read this line carefully before running `terraform apply`.

---

## 14. Making Changes — Destructive vs Non-Destructive Operations

After creating the resources, the instructor changed `account_replication_type`
from `"GRS"` to `"LRS"`. This demonstrates an important concept.

### Non-Destructive (update in place)

Some attribute changes can be applied WITHOUT destroying and recreating
the resource. Azure's API supports updating these values on a live resource.

```hcl
# Change this:
account_replication_type = "GRS"

# To this:
account_replication_type = "LRS"
```

Running `terraform plan` after this change shows:

```
  # azurerm_storage_account.example will be updated in-place
  ~ resource "azurerm_storage_account" "example" {
      ~ account_replication_type = "GRS" -> "LRS"
        # (other unchanged attributes hidden)
    }

Plan: 0 to add, 1 to change, 0 to destroy.
```

The `~` symbol means "update in place." The resource stays running.
The `0 to destroy` confirms nothing will be deleted.

### Destructive (replace)

Some attribute changes CANNOT be updated on a live resource. Azure requires
the resource to be deleted and recreated with the new value.

Examples of destructive changes:
- Changing a Storage Account's `name`
- Changing a VM's `os_disk` configuration
- Changing a Virtual Network's `address_space`

When Terraform detects this, the plan shows `-/+`:

```
  # azurerm_storage_account.example must be replaced
  -/+ resource "azurerm_storage_account" "example" {
      ~ name = "techtutorials101" -> "newtutorials101" # forces replacement
    }

Plan: 1 to add, 0 to change, 1 to destroy.
```

**DANGER:** In production, a destructive change to a storage account means
temporary data unavailability (or data loss if not backed up). Always read
the plan carefully before applying.

---

## 15. How Terraform Knows What to Change — Desired State vs Actual State

This is the fundamental mental model for understanding how Terraform works.

### Desired State

Your `.tf` files describe the **desired state** — what you WANT your
infrastructure to look like.

```hcl
# Your .tf file = desired state
resource "azurerm_storage_account" "example" {
  account_replication_type = "LRS"   # You want LRS
}
```

### Actual State

What currently exists in Azure (and what Terraform knows about from its
state file) = the **actual state**.

```
Currently in Azure: Storage Account with GRS replication
```

### The reconciliation

When you run `terraform plan`, Terraform:
1. Reads your `.tf` files (desired state)
2. Reads what it previously created (state file)
3. Queries Azure for the current real state (actual state)
4. Calculates the diff: actual → desired
5. Shows you the changes needed

```
Actual state:   account_replication_type = "GRS"
Desired state:  account_replication_type = "LRS"
Diff:           Change GRS → LRS
Plan shows:   ~ account_replication_type = "GRS" -> "LRS"
```

### The instructor's demonstration of desired state

He deleted the storage account resource block from `main.tf`, leaving only
the resource group. Then ran `terraform plan`:

```
Plan: 0 to add, 0 to change, 1 to destroy.
```

Terraform said: "Your desired state only has a Resource Group.
But actual state has a Resource Group AND a Storage Account.
I need to destroy the Storage Account to match your desired state."

This is powerful — and dangerous if you accidentally delete a resource
block from your `.tf` files. Terraform will try to delete the real resource.

---

## 16. Deleting Resources — The Right Way and the Wrong Way

### The WRONG way — removing from `.tf` file

The instructor demonstrated this as a learning exercise, but explicitly said:
**do not do this in real projects.**

```bash
# Rename the file to a non-.tf extension
mv main.tf main.txt

# Terraform can't find it
terraform plan
# Error: No configuration files
```

```bash
# Or delete specific resource blocks from the file
# → Terraform sees the missing resources as "needs to be destroyed"
```

**Why this is dangerous:**
- You lose the configuration code — how do you recreate it?
- Easy to accidentally delete the wrong block
- Creates confusion about what Terraform is supposed to manage
- No clear record of why the resource was removed

### The RIGHT way — `terraform destroy`

```bash
terraform destroy

# With auto-approval:
terraform destroy --auto-approve
```

What it does:
- Reads your current state file
- Destroys ALL resources Terraform has created
- In the correct order (dependent resources first)
- Updates the state file to reflect everything is gone

Output:
```
azurerm_storage_account.example: Destroying...
azurerm_storage_account.example: Destruction complete after 5s
azurerm_resource_group.example: Destroying...
azurerm_resource_group.example: Destruction complete after 12s

Destroy complete! Resources: 2 destroyed.
```

Notice the order: storage account is destroyed FIRST (because it depends
on the Resource Group), THEN the Resource Group. Terraform handles this
automatically.

### To destroy a SINGLE resource (not everything)

```bash
terraform destroy -target=azurerm_storage_account.example
```

This destroys only that specific resource, leaving others intact.

---

## 17. `terraform destroy` — The Safe Cleanup Command

### Why destroying resources matters

Azure (and every cloud) charges by the hour. Resources left running when
not needed cost real money.

**The instructor's pattern for every video:**
1. Build the infrastructure (for learning/testing)
2. Do the demo
3. `terraform destroy --auto-approve`
4. Confirm in Azure Portal that resources are gone

### Verifying resources are deleted

After `terraform destroy`, the instructor went to the Azure Portal,
navigated to Resource Groups, and the `example-resources` group was gone.
Terraform had cleaned up everything.

---

## 18. The Complete Code — Everything in One Place

Here is the full working code from this video, cleaned up and organised:

**`providers.tf`**
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
  # Authentication via ARM_* environment variables:
  # ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_TENANT_ID, ARM_SUBSCRIPTION_ID
}
```

**`main.tf`**
```hcl
# ─────────────────────────────────────────────────────────────────
# RESOURCE 1: Azure Resource Group
# A container for all our Azure resources
# ─────────────────────────────────────────────────────────────────
resource "azurerm_resource_group" "example" {
  name     = "example-resources"
  location = "West Europe"

  tags = {
    Environment = "Staging"
    ManagedBy   = "Terraform"
  }
}

# ─────────────────────────────────────────────────────────────────
# RESOURCE 2: Azure Storage Account
# Must be created AFTER the Resource Group (implicit dependency)
# ─────────────────────────────────────────────────────────────────
resource "azurerm_storage_account" "example" {
  name = "techtutorials101"
  # Rules: 3-24 chars, lowercase letters and numbers only, globally unique

  # Implicit dependency — Terraform will create the RG before this
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location

  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    Environment = "Staging"
    ManagedBy   = "Terraform"
  }
}
```

**`outputs.tf`**
```hcl
output "resource_group_name" {
  description = "Name of the created Resource Group"
  value       = azurerm_resource_group.example.name
}

output "storage_account_name" {
  description = "Name of the created Storage Account"
  value       = azurerm_storage_account.example.name
}

output "storage_account_primary_endpoint" {
  description = "Primary blob endpoint of the Storage Account"
  value       = azurerm_storage_account.example.primary_blob_endpoint
}
```

**Authentication setup (run in terminal before terraform commands):**

```bash
# Step 1: Login with Azure CLI
az login

# Step 2: Create Service Principal
az ad sp create-for-rbac \
  --name "az-terraform-demo" \
  --role "Contributor" \
  --scope "/subscriptions/YOUR_SUBSCRIPTION_ID"

# Step 3: Export credentials as environment variables
export ARM_CLIENT_ID="<appId from above>"
export ARM_CLIENT_SECRET="<password from above>"
export ARM_TENANT_ID="<tenant from above>"
export ARM_SUBSCRIPTION_ID="<your subscription ID>"

# Optional: set a handy alias
alias tf=terraform
```

**Run commands in order:**
```bash
terraform init
terraform validate
terraform plan
terraform apply
# ... make changes, re-run plan and apply ...
terraform destroy --auto-approve
```

---

## 19. Common Mistakes from This Video (and How to Fix Them)

### Mistake 1 — Running `terraform plan` before `terraform init`

```
Error: Inconsistent dependency lock file
...
Run: terraform init
```

**Fix:** Always run `terraform init` first. If you add a new provider,
run `terraform init` again.

---

### Mistake 2 — Storage account name with invalid characters

```
Error: "name" may only contain lowercase letters and numbers,
and must be between 3 and 24 characters long
```

**Fix:** Remove hyphens, underscores, capitals, and spaces from the name.

```hcl
name = "tech-tutorials-101"    # ❌ has hyphens
name = "TechTutorials101"      # ❌ has capitals
name = "techtutorials101"      # ✅ lowercase letters and numbers only
```

---

### Mistake 3 — Not being in the correct directory

```
Error: No configuration files
```

**Fix:** Make sure your terminal is in the folder containing your `.tf` files.

```bash
pwd                  # show current directory
ls *.tf              # check if .tf files are visible
cd path/to/your/tf   # navigate to the correct folder
```

---

### Mistake 4 — Hardcoding the Resource Group name in the Storage Account

```hcl
# FRAGILE — if you rename the RG, you must update this too
resource_group_name = "example-resources"    # ❌ hardcoded

# BETTER — gets the name dynamically, creates implicit dependency
resource_group_name = azurerm_resource_group.example.name  # ✅
```

---

### Mistake 5 — Putting credentials in `.tf` files

```hcl
# NEVER DO THIS — will end up in Git and get exposed
provider "azurerm" {
  features        {}
  client_id       = "aaaa-..."   # ❌
  client_secret   = "bbbb-..."   # ❌
  tenant_id       = "cccc-..."   # ❌
  subscription_id = "dddd-..."   # ❌
}
```

```hcl
# CORRECT — use environment variables instead
provider "azurerm" {
  features {}
  # ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_TENANT_ID,
  # ARM_SUBSCRIPTION_ID are read from environment automatically
}
```

---

### Mistake 6 — Deleting resource blocks instead of using `terraform destroy`

Removing a resource block from your `.tf` file tells Terraform to destroy
that resource. This can cause accidental data loss and loss of your config.

**Fix:** Use `terraform destroy` or `terraform destroy -target=<resource>`
to explicitly clean up. Keep your `.tf` files complete and accurate.

---

## 20. Practice Exercises

### Exercise 1 — Write a Resource Reference

Given this Resource Group:
```hcl
resource "azurerm_resource_group" "prod" {
  name     = "rg-production"
  location = "East US"
}
```

Write the two references needed for a Storage Account inside it:
```hcl
resource "azurerm_storage_account" "prodstore" {
  name                     = "mystorageacc2024"
  resource_group_name      = ???   # ← fill this in
  location                 = ???   # ← fill this in
  account_tier             = "Standard"
  account_replication_type = "LRS"
}
```

**Answer:**
```hcl
resource_group_name = azurerm_resource_group.prod.name
location            = azurerm_resource_group.prod.location
```

---

### Exercise 2 — Spot the Errors

Find all problems in this code:

```hcl
resource "azurerm_storage_account" "my-storage" {
  name                     = "My-Storage-Account-2024"
  resource_group_name      = "my-resource-group"
  location                 = "East US"
  account_tier             = "premium"
  account_replication_type = "GRS"
}
```

**Answer:**
```
1. Local name "my-storage" contains a hyphen — use underscore: "my_storage"
2. Storage account name has capitals and hyphens → "mystorageaccount2024"
3. "my-resource-group" is hardcoded — use a reference for implicit dependency
4. account_tier = "premium" — values are case-sensitive, must be "Premium"
```

---

### Exercise 3 — Predict the Plan

You have this in Azure (actual state):
```
Resource Group: rg-dev (East US)
Storage Account: devstore001 (LRS, Standard)
```

You change your `main.tf` to:
```hcl
resource "azurerm_resource_group" "dev" {
  name     = "rg-dev"
  location = "East US"
}

resource "azurerm_storage_account" "dev" {
  name                     = "devstore001"
  resource_group_name      = azurerm_resource_group.dev.name
  location                 = azurerm_resource_group.dev.location
  account_tier             = "Standard"
  account_replication_type = "GRS"   # Changed from LRS to GRS
}
```

What does `terraform plan` show?

**Answer:**
```
~ azurerm_storage_account.dev will be updated in-place
  ~ account_replication_type = "LRS" -> "GRS"

Plan: 0 to add, 1 to change, 0 to destroy.
```

Non-destructive update — the Storage Account stays running, replication
type changes.

---

### Exercise 4 — Full Workflow Practice

Without looking at notes, write the five commands in order for:
- Starting a fresh Terraform project
- Creating resources
- Cleaning up

**Answer:**
```bash
terraform init       # 1. Download providers
terraform validate   # 2. Check syntax
terraform plan       # 3. Preview changes
terraform apply      # 4. Create resources
terraform destroy    # 5. Clean up when done
```

---

## 21. Complete Cheat Sheet

```
╔═══════════════════════════════════════════════════════════════════════════╗
║         TERRAFORM + AZURE — DAY 3 QUICK REFERENCE                        ║
╠═══════════════════════════════════════════════════════════════════════════╣
║  RESOURCE BLOCK ANATOMY                                                   ║
║                                                                           ║
║  resource "azurerm_resource_group" "example" {                            ║
║           │                        │                                      ║
║           └── resource type        └── local name (nickname)             ║
║                                                                           ║
║    name     = "example-resources"  ← actual Azure name                   ║
║    location = "West Europe"        ← Azure region                        ║
║  }                                                                        ║
╠═══════════════════════════════════════════════════════════════════════════╣
║  REFERENCE SYNTAX                                                         ║
║                                                                           ║
║  azurerm_resource_group . example . name                                  ║
║  │                        │         │                                     ║
║  resource type             local     attribute                            ║
║                            name                                           ║
╠═══════════════════════════════════════════════════════════════════════════╣
║  DEPENDENCY TYPES                                                         ║
║                                                                           ║
║  Implicit (preferred):                                                    ║
║    resource_group_name = azurerm_resource_group.example.name             ║
║    (Terraform infers order from the reference)                            ║
║                                                                           ║
║  Explicit (when needed):                                                  ║
║    depends_on = [azurerm_resource_group.example]                          ║
╠═══════════════════════════════════════════════════════════════════════════╣
║  PLAN OUTPUT SYMBOLS                                                      ║
║  +    green    CREATED                                                    ║
║  ~    yellow   UPDATED in place (non-destructive)                        ║
║  -    red      DESTROYED                                                  ║
║  -/+  red      REPLACED (destroyed + recreated)                          ║
╠═══════════════════════════════════════════════════════════════════════════╣
║  STORAGE ACCOUNT NAMING RULES                                             ║
║  ✓ 3–24 characters                                                        ║
║  ✓ Lowercase letters and numbers ONLY                                    ║
║  ✗ No hyphens, underscores, capitals, spaces                             ║
║  ✗ Must be globally unique across all Azure                              ║
╠═══════════════════════════════════════════════════════════════════════════╣
║  REPLICATION TYPES                                                        ║
║  LRS  → 3 copies, same data centre (cheapest)                            ║
║  ZRS  → 3 copies across 3 zones                                          ║
║  GRS  → 6 copies, 2 regions (more resilient)                             ║
║  GZRS → Most resilient, highest cost                                     ║
╠═══════════════════════════════════════════════════════════════════════════╣
║  AZURE AUTHENTICATION (environment variables)                             ║
║                                                                           ║
║  export ARM_CLIENT_ID="..."       ← Service Principal App ID             ║
║  export ARM_CLIENT_SECRET="..."   ← Service Principal Password           ║
║  export ARM_TENANT_ID="..."       ← Azure AD Tenant ID                   ║
║  export ARM_SUBSCRIPTION_ID="..." ← Azure Subscription ID               ║
╠═══════════════════════════════════════════════════════════════════════════╣
║  COMMANDS IN ORDER                                                        ║
║                                                                           ║
║  terraform init              Download providers (run once)                ║
║  terraform validate          Check syntax (local only)                   ║
║  terraform plan              Preview changes (no Azure changes)          ║
║  terraform apply             Create/update resources in Azure            ║
║  terraform apply --auto-approve   Skip the yes/no prompt                 ║
║  terraform destroy           Delete all managed resources                ║
║  terraform destroy -target=X Delete one specific resource                ║
╠═══════════════════════════════════════════════════════════════════════════╣
║  DESIRED STATE vs ACTUAL STATE                                            ║
║                                                                           ║
║  Desired state = what your .tf files describe                            ║
║  Actual state  = what currently exists in Azure                          ║
║  terraform plan = shows the diff to get from actual → desired            ║
║  terraform apply = applies those changes                                 ║
╚═══════════════════════════════════════════════════════════════════════════╝
```

---

## The Core Mental Model for This Video

```
Your .tf file = a recipe describing what you want

terraform plan  = a chef reading the recipe and saying
                  "Here is exactly what I will cook and how"

terraform apply = the chef actually cooking it

terraform destroy = cleaning the kitchen afterwards

Implicit dependency = "I need the bowl before I can put cake mix in it"
                      Terraform sees this from your references

Desired state = the finished recipe diagram
Actual state  = what's currently on the plate
terraform plan = the diff between the two
```

---

*Guide covers: Terraform documentation navigation, azurerm_resource_group,
azurerm_storage_account, resource block anatomy, resource type vs local name,
attribute references, implicit dependency, explicit dependency, depends_on,
Azure Storage Account naming rules, account_tier, account_replication_type
(LRS/GRS/ZRS/GZRS), Azure CLI login, Service Principal, RBAC Contributor role,
ARM environment variables, terraform init, validate, plan, apply, destroy,
plan output symbols, destructive vs non-destructive changes, desired state vs
actual state, terraform destroy -target, --auto-approve flag.*
