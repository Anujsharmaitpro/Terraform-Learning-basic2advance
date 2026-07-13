# Terraform + Azure App Service — Blue-Green Deployment
## Deep-Dive Learning Guide — Day 17 / 28 Days of Easy Terraform
### Beginner-First Edition | Real Provider Troubleshooting Story | PowerShell Throughout

---

## Before You Start

This is Day 17. By now you've covered:
- **Days 1-9:** Fundamentals, providers, resources, state, variables, file
  structure, type constraints, count/for_each, lifecycle rules
- **Days 10-12:** Dynamic blocks, expressions, built-in functions
- **Day 13:** Data sources
- **Days 14-15:** Mini projects (VMSS + Load Balancer, VNet Peering)
- **Day 16:** Azure Entra ID identity automation

Today's mini project deploys a web application to **Azure App Service**
using a **Blue-Green Deployment** strategy. This guide also includes a
full breakdown of a REAL debugging saga the instructor went through —
where a newer Terraform resource type turned out to be broken for
certain application types, forcing a rollback to an older (deprecated
but working) resource. This is one of the most valuable real-world
lessons in the entire series: sometimes the "correct," newest way
doesn't actually work, and knowing how to diagnose and pragmatically
recover is a core DevOps skill.

---

## Table of Contents

1. What Is Blue-Green Deployment? (Plain English First)
2. The Full Architecture — Every Component Explained
3. What Is Azure App Service? (And App Service Plan)
4. Building the Resource Group and App Service Plan
5. The First Deprecation Warning — Reading Terraform's Guidance
6. Building the Web App (Azure App Service)
7. Building the Deployment Slot
8. The Second Deprecation Trap — When "Newer" Doesn't Mean "Working"
9. The Instructor's Debugging Journey — A Real DevOps War Story
10. The Pragmatic Fix — Rolling Back to a Working Resource Type
11. Forking the Sample Application (GitHub Setup)
12. Deploying Code with `azurerm_app_service_source_control`
13. Deploying to the Staging Slot
14. The Swap — Blue Becomes Green, Green Becomes Blue
15. Why the Swap Should Be a Separate Terraform Step
16. The Complete Working Code — All Files (Working Version)
17. Running the Deployment
18. Common Mistakes Beginners Make
19. Practice Exercises
20. Complete Cheat Sheet

---

## 1. What Is Blue-Green Deployment? (Plain English First)

### The two-identical-stages analogy

Imagine a theatre with two identical stages side by side — Stage Blue
and Stage Green. Right now, the audience is watching Stage Blue, where
Act 1 of the play is running. Backstage, on Stage Green, the crew is
quietly setting up Act 2 — completely invisible to the audience.

When Act 2 is fully ready and tested, the theatre instantly swaps which
stage the audience's seats are facing. One moment they're watching Blue,
the next moment (with zero gap) they're watching Green. If something
goes wrong with Act 2, the crew can instantly swap back to Blue.

**This is exactly Blue-Green Deployment**: you have TWO identical
environments (Blue = production, Green = staging). You deploy a new
version to the INACTIVE one, test it thoroughly, then swap traffic
to it instantly. If anything is wrong, you swap back instantly too.

### Why this matters — connecting to Day 9 (Lifecycle rules)

Recall **Day 9**'s `create_before_destroy` lifecycle rule — the idea
of creating the replacement BEFORE removing the original to minimize
downtime. Blue-Green deployment is that exact same principle, applied
at the APPLICATION level instead of the infrastructure level:

```
Day 9's create_before_destroy:
  New INFRASTRUCTURE resource exists alongside old one -> swap -> destroy old

Day 17's Blue-Green deployment:
  New APPLICATION VERSION exists alongside old one -> swap -> (old becomes standby)
```

### Why "zero downtime" matters

```
WITHOUT blue-green (traditional deployment):
  1. Stop the running application
  2. Deploy the new version
  3. Start the new version
  → Users experience an outage during steps 1-3

WITH blue-green:
  1. Deploy the new version to the INACTIVE slot (production keeps running)
  2. Test the new version thoroughly on the inactive slot
  3. Swap — traffic instantly redirects to the tested version
  → Users experience ZERO outage; the swap itself is instantaneous
```

---

## 2. The Full Architecture — Every Component Explained

```
Resource Group (day17-rg)
    |
    v
App Service Plan (day17-asp)
    - Defines: machine size, performance tier, cost
    - Multiple App Services can share ONE plan
    |
    v
Azure Web App / App Service (day17-web-app)
    |
    +-- Production Slot (default)  <- "Blue" -> v1.0 of the app
    |
    +-- Staging Slot (day17-slot1) <- "Green" -> v2.0 of the app
    |
    v
SWAP OPERATION
    Production Slot now serves v2.0 (was Green, now the active "Blue")
    Staging Slot now serves v1.0 (was Blue, now the inactive "Green")
```

### What gets created (full resource list)

```
1. azurerm_resource_group           "rg"
2. azurerm_app_service_plan         "asp"      (or azurerm_service_plan, newer)
3. azurerm_app_service              "web_app"  (or azurerm_linux_web_app, newer)
4. azurerm_app_service_slot         "slot1"    (or azurerm_linux_web_app_slot, newer)
5. azurerm_app_service_source_control       (deploy code to production slot)
6. azurerm_app_service_slot_source_control  (deploy code to staging slot)
7. azurerm_web_app_active_slot      (the swap operation)
```

---

## 3. What Is Azure App Service? (And App Service Plan)

### App Service — the plain English definition

**Azure App Service** is a Platform-as-a-Service (PaaS) offering for
hosting web applications, REST APIs, and mobile backends. Unlike a
Virtual Machine (which you fully manage — OS patches, web server config,
scaling), App Service handles the underlying server management for you.
You just deploy your code.

### Connecting to what you already know

```
Day 3 (Virtual Machines):    You manage the OS, install a web server,
                              configure everything yourself.

Day 17 (App Service):        Azure manages the OS and web server.
                              You just provide your application code.
```

### App Service Plan — the "sizing and billing" layer

Before creating an App Service, you must create an **App Service Plan**.
Think of it as choosing a hotel room tier before booking your stay:

```
App Service Plan defines:
  - Which OS (Linux or Windows)
  - How much CPU/memory (the "size" — e.g., S1, P1V2)
  - Which pricing tier (Free, Basic, Standard, Premium)
  - How many App Services can share this plan (usually many)
```

### Why deployment slots require Standard tier or higher

```
Free / Basic tier   -> NO deployment slots available
Standard tier        -> deployment slots AVAILABLE (this project uses this)
Premium tier          -> deployment slots available + more slots + more power
```

This is a hard Azure platform limitation — if you try to add a
deployment slot on a Free or Basic plan, Azure will reject it.

---

## 4. Building the Resource Group and App Service Plan

### Reusing your provider setup (connecting to Day 6 and Day 15)

The instructor reused `provider.tf` and `backend.tf` from Day 15's
project — exactly the file-structure best practice from **Day 6**
(separate files for concerns that rarely change).

```hcl
# variables.tf
variable "prefix" {
  type        = string
  description = "Prefix used for all resource names"
  default     = "day17"
}
```

```hcl
# resource_group.tf
resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-rg"
  location = "Canada Central"
}
```

### The App Service Plan

```hcl
# app_service_plan.tf
resource "azurerm_app_service_plan" "asp" {
  name                = "${var.prefix}-asp"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  sku {
    tier = "Standard"   # required for deployment slots
    size = "S1"
  }
}
```

### The instructor's exact error and fix

```
Error: argument "sku_name" is required
```

The instructor initially copied an example that used `sku_name` (a
single string field, from the NEWER `azurerm_service_plan` resource)
but was actually using the OLDER `azurerm_app_service_plan` resource,
which expects a nested `sku { }` BLOCK with separate `tier` and `size`
fields instead. Mixing syntax between the old and new resource types
is exactly the kind of subtle error you'll see throughout this video.

```hcl
# WRONG (this is the NEWER resource's syntax, doesn't work on the OLD resource)
resource "azurerm_app_service_plan" "asp" {
  sku_name = "S1"   # Error: not a valid argument for this resource type
}

# CORRECT for azurerm_app_service_plan (the older, deprecated-but-working type)
resource "azurerm_app_service_plan" "asp" {
  sku {
    tier = "Standard"
    size = "S1"
  }
}
```

---

## 5. The First Deprecation Warning — Reading Terraform's Guidance

### What a deprecation warning looks like

```
Warning: Argument is deprecated

  with azurerm_app_service_plan.asp,
  on app_service_plan.tf line 1:
   1: resource "azurerm_app_service_plan" "asp" {

`azurerm_app_service_plan` has been deprecated in favour of
`azurerm_service_plan` and will be removed in version 4.0 of the
AzureRM Provider.
```

### How to interpret a deprecation warning — connecting to Day 2

Recall **Day 2**'s lesson on provider versioning: a deprecation warning
means "this still works today, but the maintainers plan to remove it
in a future major version." It is NOT an error — your `terraform apply`
will still succeed. It's advance notice to migrate before a future
version breaks your code.

```
Warning  -> "This works now, but plan to change it eventually"
Error    -> "This does NOT work, you must fix it now"
```

### The instructor's initial (correct) instinct

Following good practice, the instructor first tried migrating to the
NEWER, recommended resource: `azurerm_service_plan` — the "right" way
to do it according to the deprecation warning. This is generally the
correct instinct. Section 8 explains why this choice caused problems
later, and why reverting was the pragmatic decision.

---

## 6. Building the Web App (Azure App Service)

### The resource (using the version that ultimately worked)

```hcl
# web_app.tf
resource "azurerm_app_service" "web_app" {
  name                = "${var.prefix}-web-app"
  location            = azurerm_app_service_plan.asp.location
  resource_group_name = azurerm_resource_group.rg.name
  app_service_plan_id = azurerm_app_service_plan.asp.id
}
```

### Why the app name must be globally unique

Connecting to **Day 3**'s lesson on Azure Storage Account naming (also
globally unique) — App Service names work the same way, because Azure
automatically generates a public URL from the name:

```
App Service name: "day17-web-app"
Auto-generated URL: https://day17-web-app.azurewebsites.net
```

If someone else already has an App Service named `day17-web-app`
anywhere in Azure worldwide, your deployment will fail with a naming
conflict — just like the storage account naming issue from **Day 3**.

### Implicit dependencies (connecting to Day 3)

```hcl
location             = azurerm_app_service_plan.asp.location   # implicit dependency
app_service_plan_id  = azurerm_app_service_plan.asp.id           # implicit dependency
resource_group_name  = azurerm_resource_group.rg.name             # implicit dependency
```

This is the exact **Day 3** implicit dependency pattern — by referencing
attributes of other resources, Terraform automatically determines the
correct creation order without needing `depends_on`.

---

## 7. Building the Deployment Slot

### The staging slot resource

```hcl
# slot.tf
resource "azurerm_app_service_slot" "slot1" {
  name                = "${var.prefix}-slot1"
  app_service_name    = azurerm_app_service.web_app.name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  app_service_plan_id = azurerm_app_service_plan.asp.id
}
```

### Understanding what "slot" means

Every App Service automatically comes with ONE built-in slot — the
"production" slot (sometimes just displayed as the app's default
endpoint). When you create an `azurerm_app_service_slot` resource,
you're adding an ADDITIONAL slot — in this case, one to use for staging.

```
day17-web-app                       <- production slot (built-in, always exists)
day17-web-app-day17-slot1           <- staging slot (created by this resource)
```

Both slots run the SAME App Service Plan (same underlying compute
resources) but can run DIFFERENT versions of your application code
independently.

---

## 8. The Second Deprecation Trap — When "Newer" Doesn't Mean "Working"

### The chain of deprecations the instructor navigated

```
azurerm_app_service            -> deprecated -> azurerm_linux_web_app / azurerm_windows_web_app
azurerm_app_service_slot       -> deprecated -> azurerm_linux_web_app_slot / azurerm_windows_web_app_slot
```

The instructor followed the recommended migration path and switched
his entire configuration to the newer `azurerm_linux_web_app` and
`azurerm_linux_web_app_slot` resources — exactly the "right" thing to
do according to Terraform's own guidance.

### What happened next — the deployment failure

After deploying application code (a legacy .NET application) to the
NEW resource type, the application failed to start with this error
in the deployment logs:

```
Error: Platform .NET version 2.0 is unsupported.
Supported versions are 3.0 and above.
```

### Why this happened — a version detection mismatch

The instructor's application needed .NET version 8, but the newly
created App Service kept defaulting to (or reverting to) .NET version
2.0 — regardless of explicit configuration attempts through:
- The `site_config` block in Terraform
- The Azure Portal's Configuration blade
- Restarting the application

### The investigation

Following good debugging practice (similar to **Day 15**'s systematic
diagnosis of the VNet peering bug), the instructor:

```
1. Tried setting the .NET version explicitly in site_config -> still failed
2. Tried changing it from the Azure Portal directly -> still failed
3. Restarted the app service -> still failed
4. Searched for the error message online
5. Found multiple OPEN GitHub issues on the AzureRM provider repository
   reporting the exact same problem with the newer resource types
```

### The conclusion

**The newer resource types (`azurerm_linux_web_app` /
`azurerm_linux_web_app_slot`) had a genuine compatibility bug** with
certain application runtime configurations at the time of this recording
— confirmed by other users hitting the identical issue in the provider's
public issue tracker. This was not a mistake in the instructor's code;
it was a real bug in the Terraform provider itself.

---

## 9. The Instructor's Debugging Journey — A Real DevOps War Story

This deserves its own section because the METHODOLOGY matters more
than the specific bug (which may well be fixed by the time you read
this — always check current provider changelogs).

### The debugging principles demonstrated

```
Principle 1: Try the officially recommended fix first
             (migrate to the non-deprecated resource — the "correct" move)

Principle 2: When something doesn't work as documented, isolate variables
             (tried Terraform config, then Portal UI, then a restart —
              each attempt ruling out one possible cause)

Principle 3: Search for whether others have hit the same issue
             (checking GitHub issues is often faster than deep individual
              debugging — you might be looking at a known platform bug)

Principle 4: Know when to stop debugging and pragmatically work around it
             (after ~2 days of investigation, the instructor made the
              call to revert to older resource types rather than
              continuing to fight a provider-level bug)

Principle 5: Document your workaround transparently
             (the instructor explicitly explained WHY he reverted, so
              viewers facing the same issue immediately understand
              both the problem AND the solution)
```

### Why this matters for your career, not just this video

This is one of the most realistic and valuable lessons in the whole
series. Documentation, tutorials, and even a tool's own deprecation
warnings represent the IDEAL path — but production reality sometimes
diverges from the ideal. Recognising when to escalate, search for known
issues, or pragmatically use an older-but-working approach is a genuine
professional skill, not a failure.

---

## 10. The Pragmatic Fix — Rolling Back to a Working Resource Type

### The final, working resource types used

```hcl
azurerm_app_service_plan    (deprecated warning, but functionally correct)
azurerm_app_service          (deprecated warning, but functionally correct)
azurerm_app_service_slot     (deprecated warning, but functionally correct)
```

### Living with a deprecation warning

```powershell
terraform plan
```

```
Warning: Argument is deprecated
  ... (repeated for each resource type)

Plan: 4 to add, 0 to change, 0 to destroy.
```

The plan still succeeds. The warnings are noise you accept for now,
with a mental note to re-attempt migration once the underlying provider
bug is fixed in a future release. This connects to **Day 2**'s lesson
on version locking (`~>` operator) — you can deliberately choose to
stay on a provider version where your resources work correctly, rather
than blindly upgrading.

### How to check if this bug affects you today

**PowerShell — check the current provider version and changelog:**
```powershell
# Check your currently locked provider version
Get-Content .terraform.lock.hcl | Select-String "azurerm"

# Check the latest available version and recent changes
# (open in browser)
Start-Process "https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/4.0-upgrade-guide"
```

If you're following this guide significantly after January 2025, the
underlying bug the instructor hit may already be resolved — always
test the newer resource types (`azurerm_linux_web_app`) yourself first,
and only fall back to the deprecated types if you hit the same issue.

---

## 11. Forking the Sample Application (GitHub Setup)

### Why a fork instead of using the original repo directly

Connecting to general Git best practices: forking creates YOUR OWN copy
of a repository, which you can connect App Service's deployment source
to, without needing write access to someone else's original repository.

### The sample application structure

The instructor used a Microsoft sample "blue-green" demo application
with TWO branches:
```
master                        -> Blue version (v1.0) — blue background
app-service-working-do-not-merge -> Green version (v2.0) — green background
```

Each branch represents a different "release" of the same application,
making it easy to visually confirm which version is running on which slot.

### PowerShell — forking via GitHub CLI (alternative to the web UI)

```powershell
# If you have GitHub CLI installed
gh repo fork Azure-Samples/terraform-blue-green-deploy --clone=false

# Verify the fork exists
gh repo view "your-username/terraform-blue-green-deploy"
```

**Important setting from the video:** when forking, UNCHECK "Copy the
main branch only" — you need BOTH branches (master and the working
branch) copied into your fork, since the demo relies on deploying from
two different branches.

---

## 12. Deploying Code with `azurerm_app_service_source_control`

### Connecting Terraform to your forked GitHub repo

```hcl
# source_control.tf
resource "azurerm_app_service_source_control" "production_deploy" {
  app_id             = azurerm_app_service.web_app.id
  repo_url           = "https://github.com/your-username/terraform-blue-green-deploy"
  branch             = "master"
  use_manual_integration = true
  use_mercurial          = false
}
```

### The instructor's discovery — different resource, different field names

The instructor initially tried using `app_id` when working with a SLOT
(rather than the production app), and discovered Azure/Terraform
requires a DIFFERENT resource type entirely for slot-level source
control, with a `slot_id` field instead of `app_id`:

```hcl
# For the PRODUCTION slot -> azurerm_app_service_source_control
resource "azurerm_app_service_source_control" "production_deploy" {
  app_id   = azurerm_app_service.web_app.id   # <- app_id
  repo_url = "https://github.com/your-username/terraform-blue-green-deploy"
  branch   = "master"
}

# For the STAGING slot -> azurerm_app_service_slot_source_control
resource "azurerm_app_service_slot_source_control" "staging_deploy" {
  slot_id  = azurerm_app_service_slot.slot1.id   # <- slot_id, NOT app_id
  repo_url = "https://github.com/your-username/terraform-blue-green-deploy"
  branch   = "app-service-working-do-not-merge"
}
```

This is a subtle but important pattern: **resources that look similar
often have different argument names for conceptually similar fields**
depending on which "level" (app vs slot) they operate at. Always check
the documentation for the SPECIFIC resource type rather than assuming
argument names carry over.

---

## 13. Deploying to the Staging Slot

### The complete staging deployment

```hcl
resource "azurerm_app_service_slot_source_control" "staging_deploy" {
  slot_id  = azurerm_app_service_slot.slot1.id
  repo_url = "https://github.com/your-username/terraform-blue-green-deploy"
  branch   = "app-service-working-do-not-merge"
  use_manual_integration = true
}
```

### What happens after `terraform apply`

```
Production Slot (day17-web-app)
  Source: master branch
  Result: Blue-coloured application (v1.0)

Staging Slot (day17-web-app-day17-slot1)
  Source: app-service-working-do-not-merge branch
  Result: Green-coloured application (v2.0)
```

Each slot independently builds and deploys from its assigned branch —
this is Azure App Service's native GitHub integration doing the build
and deployment work, triggered by the Terraform-configured connection.

---

## 14. The Swap — Blue Becomes Green, Green Becomes Blue

### The swap resource

```hcl
resource "azurerm_web_app_active_slot" "swap" {
  slot_id = azurerm_app_service_slot.slot1.id
}
```

### What this single resource does

This is deceptively simple — just ONE field (`slot_id`) — but it triggers
Azure to perform the entire swap operation:

```
BEFORE the swap:
  Production slot  -> Blue  (v1.0, master branch)
  Staging slot      -> Green (v2.0, working branch)

AFTER the swap:
  Production slot  -> Green (v2.0) — now serving live traffic
  Staging slot      -> Blue  (v1.0) — now the standby/rollback option
```

### How the swap actually works under the hood

Azure App Service doesn't literally "move" files between slots. Instead,
it swaps the ROUTING — which slot receives production traffic — while
also swapping certain configuration settings (unless marked as
"slot-specific"). This is why the swap is fast: it's a routing change,
not a redeployment.

### The manual equivalent (for context)

```
Azure Portal manual swap:
  1. Go to your App Service -> Deployment Slots
  2. Click "Swap"
  3. Select Source slot and Target slot
  4. Click "Start Swap"
```

The `azurerm_web_app_active_slot` resource automates exactly this
manual Portal action.

---

## 15. Why the Swap Should Be a Separate Terraform Step

### The instructor's explicit recommendation

> "You usually keep it separate from the main configuration... it is
> usually governed by a manual approval or there is a trigger that
> this step should be triggered only when the deployed version is
> working fine in the staging environment."

### Connecting to CI/CD pipeline best practices

```
Typical pipeline stages:
  Stage 1: terraform apply (create infra + deploy to staging slot)
  Stage 2: Automated tests run against the staging slot
  Stage 3: MANUAL APPROVAL gate (a human confirms staging looks correct)
  Stage 4: terraform apply (this time including the swap resource)
```

Bundling the swap into the SAME `apply` as the initial deployment
removes your safety net — you lose the chance to verify the staging
slot is actually healthy BEFORE it becomes production traffic.

### A practical implementation pattern

```hcl
# swap.tf — kept as a SEPARATE file, sometimes even a separate
# Terraform workspace or state, applied only after manual sign-off

resource "azurerm_web_app_active_slot" "swap" {
  slot_id = azurerm_app_service_slot.slot1.id

  # Optional: add a lifecycle precondition (Day 9 concept!) as an
  # extra safety check before allowing the swap
  lifecycle {
    precondition {
      condition     = azurerm_app_service_slot_source_control.staging_deploy.branch != ""
      error_message = "Staging slot must have a deployment configured before swapping."
    }
  }
}
```

This connects directly back to **Day 9**'s `precondition` lifecycle
block — using it here as a safety gate before a production-impacting swap.

---

## 16. The Complete Working Code — All Files (Working Version)

**`provider.tf`** (reused pattern from Day 15/16)
```hcl
terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"   # NOTE: pinned to v3.x where azurerm_app_service works reliably
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
  default     = "day17"
}

variable "location" {
  type    = string
  default = "Canada Central"
}

variable "repo_url" {
  type        = string
  description = "Your forked GitHub repository URL"
  default     = "https://github.com/your-username/terraform-blue-green-deploy"
}
```

---

**`main.tf`**
```hcl
resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-rg"
  location = var.location
}

resource "azurerm_app_service_plan" "asp" {
  name                = "${var.prefix}-asp"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  sku {
    tier = "Standard"
    size = "S1"
  }
}

resource "azurerm_app_service" "web_app" {
  name                = "${var.prefix}-web-app"
  location            = azurerm_app_service_plan.asp.location
  resource_group_name = azurerm_resource_group.rg.name
  app_service_plan_id = azurerm_app_service_plan.asp.id
}

resource "azurerm_app_service_slot" "slot1" {
  name                = "${var.prefix}-slot1"
  app_service_name    = azurerm_app_service.web_app.name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  app_service_plan_id = azurerm_app_service_plan.asp.id
}
```

---

**`deploy.tf`**
```hcl
# Deploy the "Blue" version (master branch) to the production slot
resource "azurerm_app_service_source_control" "production_deploy" {
  app_id                  = azurerm_app_service.web_app.id
  repo_url                = var.repo_url
  branch                  = "master"
  use_manual_integration  = true
}

# Deploy the "Green" version (working branch) to the staging slot
resource "azurerm_app_service_slot_source_control" "staging_deploy" {
  slot_id                 = azurerm_app_service_slot.slot1.id
  repo_url                = var.repo_url
  branch                  = "app-service-working-do-not-merge"
  use_manual_integration  = true
}
```

---

**`swap.tf`** (kept separate — connecting to Section 15's best practice)
```hcl
# WARNING: Only apply this after confirming the staging slot works correctly!
# Recommended: run this as a separate terraform apply, gated by manual approval.

resource "azurerm_web_app_active_slot" "swap" {
  slot_id = azurerm_app_service_slot.slot1.id
}
```

---

**`outputs.tf`**
```hcl
output "production_url" {
  description = "The production (default) App Service URL"
  value       = "https://${azurerm_app_service.web_app.default_site_hostname}"
}

output "staging_url" {
  description = "The staging slot URL"
  value       = "https://${azurerm_app_service_slot.slot1.default_site_hostname}"
}
```

---

## 17. Running the Deployment

**PowerShell — full workflow:**

```powershell
Set-Location "C:\projects\day17"

$env:ARM_CLIENT_ID       = "your-client-id"
$env:ARM_CLIENT_SECRET   = "your-client-secret"
$env:ARM_TENANT_ID       = "your-tenant-id"
$env:ARM_SUBSCRIPTION_ID = "your-subscription-id"

terraform init
terraform validate
terraform plan
# Expect deprecation WARNINGS (not errors) for app_service_plan, app_service,
# and app_service_slot — this is expected and safe to proceed with

# STAGE 1: Create infrastructure + deploy to both slots (WITHOUT the swap)
# Temporarily comment out the content of swap.tf for this first apply
terraform apply --auto-approve

# Get the URLs and manually verify both slots look correct
terraform output production_url
terraform output staging_url

Start-Process (terraform output -raw production_url)   # should show Blue
Start-Process (terraform output -raw staging_url)      # should show Green

# STAGE 2: After manual verification, uncomment swap.tf and apply again
terraform apply --auto-approve

# Verify the swap happened — production URL should now show Green
Start-Process (terraform output -raw production_url)   # should now show Green

# Clean up — always destroy App Service resources when done (billed hourly)
terraform destroy --auto-approve

Remove-Item Env:ARM_CLIENT_ID
Remove-Item Env:ARM_CLIENT_SECRET
Remove-Item Env:ARM_TENANT_ID
Remove-Item Env:ARM_SUBSCRIPTION_ID
```

---

## 18. Common Mistakes Beginners Make

### Mistake 1 — Using `sku_name` syntax on the older `azurerm_app_service_plan`

```hcl
# WRONG (mixing newer resource's field into the older resource)
resource "azurerm_app_service_plan" "asp" {
  sku_name = "S1"
}

# CORRECT (older resource needs a nested sku block)
resource "azurerm_app_service_plan" "asp" {
  sku {
    tier = "Standard"
    size = "S1"
  }
}
```

### Mistake 2 — Trying Free or Basic tier with deployment slots

```
Error: deployment slots require Standard tier or above
```

Connecting to Section 3: always use `tier = "Standard"` (or Premium)
if your project needs deployment slots.

### Mistake 3 — Assuming "deprecated" means "broken"

A deprecation warning (Section 5) does NOT mean the resource is
non-functional today. Read the warning text carefully — it tells you
WHEN it will actually be removed, giving you time to plan a migration
rather than panicking immediately.

### Mistake 4 — Assuming "newer" always means "more reliable"

Section 8-10's central lesson: newer resource types can have their own
bugs, especially soon after release. Always test thoroughly, especially
for less-common application runtime configurations, before committing
to a migration in a production-critical project.

### Mistake 5 — Using `app_id` on a slot-level source control resource

```hcl
# WRONG — app_id is for the production-level resource
resource "azurerm_app_service_slot_source_control" "staging_deploy" {
  app_id = azurerm_app_service_slot.slot1.id   # wrong field name
}

# CORRECT — slots use slot_id
resource "azurerm_app_service_slot_source_control" "staging_deploy" {
  slot_id = azurerm_app_service_slot.slot1.id
}
```

### Mistake 6 — Bundling the swap into the same apply as the initial deployment

Connecting to Section 15: always treat the swap as a distinct,
independently-triggered step so you retain the ability to verify
staging before it becomes production.

### Mistake 7 — Forgetting to destroy App Service resources

App Service Plans (especially Standard/Premium tier) are billed
continuously by the hour, similar to VMs. Unlike some free-tier
resources, leaving this running unattended has a real, ongoing cost.

---

## 19. Practice Exercises

### Exercise 1 — Identify the Resource Type Mismatch

```hcl
resource "azurerm_service_plan" "asp" {
  sku {
    tier = "Standard"
    size = "S1"
  }
}
```

What's wrong, and how do you fix it?

**Answer:**
```
azurerm_service_plan (the NEWER resource) uses sku_name (a single string),
NOT a nested sku block. The code above is mixing the newer resource type
name with the older resource's argument syntax.

Fix (staying on newer type):
resource "azurerm_service_plan" "asp" {
  sku_name = "S1"
}

OR fix (staying on older type):
resource "azurerm_app_service_plan" "asp" {
  sku {
    tier = "Standard"
    size = "S1"
  }
}
```

### Exercise 2 — Trace the Blue-Green Swap

Before a swap: Production = v1.0, Staging = v2.1
After the swap: Production = ?, Staging = ?

**Answer:**
```
After swap:
  Production = v2.1  (was staging, now live)
  Staging     = v1.0  (was production, now standby/rollback option)
```

### Exercise 3 — Write a Precondition for the Swap

Using the **Day 9** lifecycle pattern, write a precondition that
prevents the swap resource from applying unless a variable
`var.staging_verified` is explicitly set to `true`.

**Answer:**
```hcl
variable "staging_verified" {
  type        = bool
  description = "Set to true only after manually verifying the staging slot"
  default     = false
}

resource "azurerm_web_app_active_slot" "swap" {
  slot_id = azurerm_app_service_slot.slot1.id

  lifecycle {
    precondition {
      condition     = var.staging_verified == true
      error_message = "Set staging_verified = true only after confirming the staging slot works correctly."
    }
  }
}
```

### Exercise 4 — Debugging Methodology

List, in order, the five debugging steps the instructor took when the
.NET version error appeared (Section 9), and explain why searching
GitHub issues came before giving up.

**Answer:**
```
1. Tried setting the version explicitly in Terraform's site_config
2. Tried changing it manually in the Azure Portal
3. Restarted the App Service
4. Searched online / GitHub issues for the exact error message
5. Found confirmation from other users -> concluded it's a provider bug
   -> made the pragmatic decision to revert to older resource types

Searching GitHub issues comes before giving up because it can save
massive amounts of time — if 50 other people already diagnosed the
same root cause, you don't need to independently re-discover it.
```

---

## 20. Complete Cheat Sheet

```
================================================================================
      TERRAFORM + AZURE APP SERVICE BLUE-GREEN — DAY 17 QUICK REFERENCE
================================================================================
  RESOURCE TYPE MAP (deprecated -> newer replacement)

  azurerm_app_service_plan   -> azurerm_service_plan
  azurerm_app_service         -> azurerm_linux_web_app / azurerm_windows_web_app
  azurerm_app_service_slot    -> azurerm_linux_web_app_slot / azurerm_windows_web_app_slot

  NOTE: This video found the newer types had a real bug with certain
  .NET runtime configs at time of recording. Test both before committing.
--------------------------------------------------------------------------------
  SKU SYNTAX DIFFERENCE

  OLDER (azurerm_app_service_plan):        NEWER (azurerm_service_plan):
    sku {                                    sku_name = "S1"
      tier = "Standard"
      size = "S1"
    }
--------------------------------------------------------------------------------
  DEPLOYMENT SLOTS REQUIRE STANDARD TIER OR ABOVE
  Free / Basic tier  -> NO slots available
  Standard / Premium -> slots available
--------------------------------------------------------------------------------
  SOURCE CONTROL RESOURCES (different field names!)

  Production:  azurerm_app_service_source_control
               app_id = azurerm_app_service.web_app.id

  Staging:     azurerm_app_service_slot_source_control
               slot_id = azurerm_app_service_slot.slot1.id
--------------------------------------------------------------------------------
  THE SWAP RESOURCE (one field triggers the entire operation)

  resource "azurerm_web_app_active_slot" "swap" {
    slot_id = azurerm_app_service_slot.slot1.id
  }

  BEFORE: Production=Blue,  Staging=Green
  AFTER:  Production=Green, Staging=Blue
--------------------------------------------------------------------------------
  BEST PRACTICE: KEEP THE SWAP AS A SEPARATE APPLY
  Stage 1: terraform apply (deploy to slots, DO NOT swap yet)
  Stage 2: Manual/automated verification of staging slot
  Stage 3: terraform apply (NOW including the swap resource)
--------------------------------------------------------------------------------
  DEBUGGING METHODOLOGY (when the "correct" approach doesn't work)
  1. Try the officially recommended fix
  2. Isolate variables (config file vs Portal vs restart)
  3. Search for the exact error message + GitHub issues
  4. Recognise a known platform/provider bug when confirmed by others
  5. Pragmatically use an older-but-working approach
  6. Document WHY you deviated from the "ideal" path
--------------------------------------------------------------------------------
  POWERSHELL

  terraform init / plan / apply --auto-approve / destroy --auto-approve
  terraform output production_url
  terraform output staging_url
  Start-Process (terraform output -raw production_url)
  Get-Content .terraform.lock.hcl | Select-String "azurerm"
================================================================================
```

---

## How This Connects to the Whole Series So Far

```
Day 1  (IaC fundamentals)     -> automating deployments instead of manual Portal clicks
Day 2  (Providers, versions)  -> deprecation warnings, version pinning with ~>
Day 3  (Resources, naming)    -> globally unique App Service names (like storage accounts)
Day 6  (File structure)       -> reusing provider.tf/backend.tf across projects
Day 9  (Lifecycle rules)      -> create_before_destroy parallels blue-green's zero-downtime goal
                                  precondition used as a swap safety gate
Day 15 (Debugging methodology)-> the systematic diagnosis approach reused here
Day 16 (Real-world automation)-> continuing the "automate what used to be manual" theme
```

---

*Guide covers: Azure App Service, App Service Plan, blue-green deployment
strategy, deployment slots, azurerm_app_service_plan vs azurerm_service_plan,
sku block vs sku_name argument, Standard tier requirement for slots,
azurerm_app_service vs azurerm_linux_web_app, azurerm_app_service_slot vs
azurerm_linux_web_app_slot, provider deprecation warnings vs errors,
real-world Terraform provider bug diagnosis, GitHub issue research
methodology, azurerm_app_service_source_control, azurerm_app_service_slot_source_control,
app_id vs slot_id field naming, GitHub repository forking for App Service
deployment, azurerm_web_app_active_slot swap resource, separating swap
operations from initial deployment, CI/CD manual approval gate patterns,
precondition lifecycle block as a swap safety check, globally unique
App Service naming, implicit dependencies in multi-tier App Service
configurations, PowerShell Azure credential management, cross-referencing
prior days (create_before_destroy, precondition, provider versioning,
file structure, implicit dependencies).*
