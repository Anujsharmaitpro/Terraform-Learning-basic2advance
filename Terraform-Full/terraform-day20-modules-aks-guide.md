# Terraform Modules — Building an AKS Cluster with Reusable Code
## Deep-Dive Learning Guide — Day 20 / 28 Days of Easy Terraform
### Beginner-First Edition | PowerShell Throughout

---

## Before You Start

This is Day 20. You've now covered fundamentals, expressions/functions,
data sources, and several mini projects, most recently provisioners
(Day 19), where the running theme was "know when a feature is a good
default versus a last resort."

Today introduces **modules** — the single most important Terraform
concept for anyone planning to use it beyond a solo learning project.
The demo builds an AKS (Azure Kubernetes Service) cluster using
custom local modules for a Service Principal, a Key Vault, and the
cluster itself.

I want to be upfront about something before diving in, in the spirit
of giving you a complete picture rather than just following the video
uncritically: the identity pattern used in this project — a **Service
Principal with a client secret, stored in Key Vault** — is a legitimate
and historically common approach, but it is not what Microsoft
currently recommends for new AKS clusters. Section 5 explains why, and
what the modern alternative looks like. I'm not rewriting the project
to avoid it (the video's approach is still functional and worth
understanding, since you'll encounter it in real codebases), but you
should know the tradeoff before you copy this pattern into your own
infrastructure.

---

## Table of Contents

1. What Is a Terraform Module? (Plain-English Definition)
2. Root Module, Calling Module, Child Module — The Three Terms You'll Hear
3. Why Modules Exist — The Reusability Argument
4. Local Modules vs Registry Modules (Public and Private)
5. A Necessary Correction: Service Principal vs Managed Identity for AKS
6. The Project Architecture
7. The Module Block — Syntax Breakdown
8. Passing Values Into a Module (Input Variables)
9. Getting Values Out of a Module (Output Variables)
10. Building the Service Principal Module
11. Sensitive Values Crossing Module Boundaries
12. The Role Assignment — And a Note on Scope
13. The Key Vault Module
14. Storing the Service Principal's Secret in Key Vault
15. The AKS Module — Full Breakdown
16. The Kubernetes Version Data Source (With a Naming Correction)
17. The Instructor's Two To-Do Items, Explained and Implemented
18. Writing the Kubeconfig File — And Its Sensitivity Problem
19. Running the Deployment
20. Verifying the Cluster
21. The Bank of Anthos Extension
22. Complete Code Skeleton
23. Common Mistakes
24. Practice Exercises
25. Summary Reference

---

## 1. What Is a Terraform Module? (Plain-English Definition)

A **module** is a self-contained, reusable collection of `.tf` files —
essentially a Terraform "function." You define a set of resources
once, expose some inputs and outputs, and then call that definition
as many times as you need, with different input values each time,
without duplicating the underlying resource code.

If you've written functions in any programming language, this is the
exact same idea applied to infrastructure: write the logic once,
parameterize it, call it repeatedly.

---

## 2. Root Module, Calling Module, Child Module — The Three Terms You'll Hear

This terminology trips people up, so it's worth being precise:

- **Root module** — the `.tf` files in the directory where you run
  `terraform init`/`plan`/`apply`. Every Terraform project has exactly
  one root module, whether or not you're consciously using any other
  modules. If you've completed Days 1-19 of this series, every project
  you built was, technically, a root module — you just weren't calling
  additional modules from it yet.

- **Calling module** — any module (including the root module) that
  contains a `module` block referencing another module.

- **Child module** — the module being referenced and invoked by a
  `module` block. A child module can itself call further child
  modules, though deeply nested module chains are best avoided for
  readability.

In this project: the root module (your `main.tf`, at the top level)
is also the calling module — it contains `module` blocks that invoke
three child modules: `service_principal`, `keyvault`, and `aks`.

---

## 3. Why Modules Exist — The Reusability Argument

Without modules, provisioning five AKS clusters means writing (or
copy-pasting) the full cluster resource block five times, each with
slightly different values. Every future change to that resource
definition — a new tag, an updated node pool setting — has to be
manually repeated across all five copies, and it's easy for them to
drift out of sync with each other.

With a module, you write the AKS resource definition once, expose the
handful of values that actually differ between clusters (name,
location, node count) as input variables, and call the module five
times with five different sets of values. One definition, five
instances, one place to make future changes.

This is the same DRY (Don't Repeat Yourself) principle behind
`for_each` (Day 8) and `dynamic` blocks (Day 10) — modules solve the
same category of problem at a larger, cross-resource scale.

---

## 4. Local Modules vs Registry Modules (Public and Private)

**Local modules** — stored in a subdirectory of your own project
(this project's `./modules/` folder), referenced with a relative path.
This is what Day 20 demonstrates, and the simplest way to start.

**Public registry modules** — published to the public Terraform
Registry (`registry.terraform.io`), maintained by HashiCorp partners
or the community, usable by anyone. You'd reference these by a
registry address rather than a file path.

**Private registry modules** — published to an internal,
organization-restricted registry (Terraform Cloud/Enterprise private
registries, or self-hosted alternatives), so only your team or company
can use them. This is the standard approach once an organization has
multiple teams that need to share standardized, vetted infrastructure
patterns without exposing them publicly.

For a first module-based project, local modules are the right starting
point — you get the reusability benefit without the overhead of
publishing and versioning a registry module.

---

## 5. A Necessary Correction: Service Principal vs Managed Identity for AKS

This section exists because presenting the video's approach without
comment would leave out something that matters if you're building
real infrastructure, not just following along for the learning exercise.

**What this project does:** creates an Azure AD Service Principal with
a client secret, grants it Contributor access, stores the secret in
Key Vault, and uses that Service Principal's credentials to provision
the AKS cluster.

**Why this pattern exists and was common historically:** before Azure
AD Managed Identities matured, a Service Principal with a stored
secret was effectively the only way to grant a non-human identity
(like an AKS cluster or a CI/CD pipeline) programmatic access to Azure
resources.

**What's actually recommended now:** Microsoft's current AKS
documentation recommends **Managed Identity** (system-assigned or
user-assigned) for the cluster's own identity, rather than a Service
Principal with a manually managed secret. The reasons are concrete,
not stylistic:

- A Service Principal's client secret has an expiration date and must
  be manually rotated — if it lapses, the cluster loses the ability to
  manage its own resources (load balancers, disks, etc.) until someone
  notices and rotates it.
- The secret has to be stored *somewhere* (as this project does, in
  Key Vault) — that's an additional credential-handling surface that
  managed identities eliminate entirely, since Azure manages the
  credential lifecycle for you with no secret ever existing in a
  retrievable form.
- Managed Identity is Azure-platform-managed and doesn't require the
  `azuread_application` / `azuread_service_principal` /
  `azuread_service_principal_password` resource chain this project
  builds at all.

**Does this mean the video's approach is "wrong"?** No — it's
functional, it's still supported, and understanding it is genuinely
useful, because you'll encounter this exact pattern in older
production codebases and need to know how to read and maintain it.
But if you're starting a *new* AKS project today, the simpler and
more current approach is:

```hcl
resource "azurerm_kubernetes_cluster" "aks" {
  # ... other configuration ...

  identity {
    type = "SystemAssigned"
  }
}
```

This single `identity` block replaces the entire Service Principal
module, the role assignment, and the Key Vault secret storage for the
cluster's own identity — Azure handles credential issuance and
rotation automatically. This guide still walks through the Service
Principal approach in full below, since that's what the source video
builds and it's valuable to understand both patterns, but treat
Managed Identity as the default choice for your own new projects.

---

## 6. The Project Architecture

The resources created, in dependency order:

1. **Resource Group** — the container for everything (root module,
   not wrapped in its own child module in this project)
2. **Service Principal module** — creates an Azure AD Application, a
   Service Principal for that application, and a password/secret for it
3. **Role Assignment** (root module, not its own child module) — grants
   the Service Principal Contributor access at a defined scope
4. **Key Vault module** — creates the Key Vault itself, using the
   Service Principal's identity for its access policy
5. **Key Vault Secret** (root module) — uploads the Service Principal's
   client ID and client secret into the Key Vault as secrets
6. **AKS module** — provisions the cluster, authenticating as the
   Service Principal
7. **local_file** (root module) — writes the cluster's kubeconfig to
   disk locally, so you can run `kubectl` commands against it

---

## 7. The Module Block — Syntax Breakdown

```hcl
module "rg1" {
  source = "./modules/resource_group"

  name     = "day20-rg"
  location = "Canada Central"
}
```

- `module` — the keyword
- `"rg1"` — the local name you're giving this specific call to the
  module (you choose this; it's how you reference this instance later)
- `source` — **mandatory**. Tells Terraform where to find the module's
  code. `"./modules/resource_group"` is a relative filesystem path to
  a local module
- Every other argument inside the block (`name`, `location`, etc.)
  corresponds to an input variable declared inside that child module

---

## 8. Passing Values Into a Module (Input Variables)

Exactly like a root module, a child module declares its own
`variables.tf`. The values you set in the calling `module` block are
what actually populate those variables at apply time.

**`modules/service_principal/variables.tf`**
```hcl
variable "service_principal_name" {
  type        = string
  description = "Display name for the Azure AD application/service principal"
}
```

**In the root module, calling it:**
```hcl
module "service_principal" {
  source = "./modules/service_principal"

  service_principal_name = var.service_principal_name

  depends_on = [azurerm_resource_group.rg]
}
```

Note the `depends_on` here — Section 12 explains why an explicit
dependency was added even though (as the video itself acknowledges)
the Service Principal doesn't actually reference any Resource Group
attribute, so strictly speaking this dependency isn't required by data
flow. It's a defensive ordering choice, not a strictly necessary one.

---

## 9. Getting Values Out of a Module (Output Variables)

A child module's `outputs.tf` defines what values are visible to
whatever called it. Without an output, a value calculated *inside* a
child module is invisible outside it — even if it's something you
desperately need in the root module, like a generated Service
Principal's object ID.

**`modules/service_principal/outputs.tf`**
```hcl
output "service_principal_object_id" {
  value = azuread_service_principal.sp.object_id
}

output "client_id" {
  value = azuread_application.app.client_id
}

output "client_secret" {
  value     = azuread_service_principal_password.sp_password.value
  sensitive = true
}

output "tenant_id" {
  value = data.azurerm_client_config.current.tenant_id
}
```

**Referencing these from the root module:**
```hcl
module.service_principal.service_principal_object_id
module.service_principal.client_id
module.service_principal.client_secret
module.service_principal.tenant_id
```

The pattern is always `module.<local_name>.<output_name>` — this
mirrors the `data.<type>.<name>.<attribute>` pattern from Day 13's
data sources, and the resource-reference pattern from Day 3. Same
underlying idea: dot-path down to the value you need.

---

## 10. Building the Service Principal Module

**`modules/service_principal/main.tf`**
```hcl
data "azurerm_client_config" "current" {}

resource "azuread_application" "app" {
  display_name = var.service_principal_name
}

resource "azuread_service_principal" "sp" {
  client_id = azuread_application.app.client_id
}

resource "azuread_service_principal_password" "sp_password" {
  service_principal_id = azuread_service_principal.sp.id
}
```

This connects directly to **Day 16**'s Entra ID work — `azuread_application`
and `azuread_service_principal` are from the same `azuread` provider
covered there. If Day 16 is unfamiliar, it's worth reviewing before
this project, since this module assumes that background.

---

## 11. Sensitive Values Crossing Module Boundaries

The video explains this reasonably well, but it's worth restating
precisely: `client_secret` is marked `sensitive = true` on the *child
module's* output. When the root module then also outputs or displays
that value (directly, or indirectly by writing it into a resource
argument that itself gets displayed), Terraform propagates the
sensitivity marking automatically in most cases — but if you
explicitly re-output it at the root level, you still need to mark
that root-level output `sensitive = true` as well, exactly as covered
in Day 12's `sensitive()`/`nonsensitive()` discussion. Sensitivity
doesn't just "happen" — it has to be marked at each output boundary
where a value is deliberately exposed.

And, worth repeating from Day 12: marking something `sensitive` hides
it from your terminal/log output. It does **not** encrypt it in the
state file. The client secret is still sitting in plaintext inside
`terraform.tfstate` regardless of this marking — which is exactly why
Day 4's remote-backend-with-access-control guidance matters here more
than almost anywhere else in this series.

---

## 12. The Role Assignment — And a Note on Scope

```hcl
resource "azurerm_role_assignment" "sp_contributor" {
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  role_definition_name = "Contributor"
  principal_id          = module.service_principal.service_principal_object_id

  depends_on = [module.service_principal]
}
```

**The correction worth making here:** this grants the Service
Principal Contributor access across the **entire Azure subscription**
— meaning it can create, modify, or delete essentially any resource
in every resource group under that subscription, not just the ones
relevant to this AKS project.

This is a real violation of the principle of least privilege, and it's
worth being direct about that rather than passing over it silently.
For a learning project, the blast radius of this is limited (you
presumably control the whole subscription anyway). For anything
resembling production infrastructure, this scope should be narrowed
to the specific resource group the AKS cluster and its dependencies
live in:

```hcl
resource "azurerm_role_assignment" "sp_contributor" {
  scope                = azurerm_resource_group.rg.id
  role_definition_name = "Contributor"
  principal_id          = module.service_principal.service_principal_object_id

  depends_on = [module.service_principal]
}
```

Scoping to `azurerm_resource_group.rg.id` instead of the subscription
root means this Service Principal's Contributor rights are confined to
resources inside that one resource group — a meaningfully smaller
attack surface if the credential were ever compromised.

---

## 13. The Key Vault Module

**`modules/keyvault/main.tf`**
```hcl
data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "kv" {
  name                = var.key_vault_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id
  sku_name            = "standard"

  access_policy {
    tenant_id = var.tenant_id
    object_id = var.service_principal_object_id

    secret_permissions = [
      "Get", "List", "Set", "Delete"
    ]
  }
}
```

**`modules/keyvault/variables.tf`**
```hcl
variable "key_vault_name"              { type = string }
variable "location"                     { type = string }
variable "resource_group_name"          { type = string }
variable "tenant_id"                    { type = string }
variable "service_principal_object_id"  { type = string }
```

**`modules/keyvault/outputs.tf`**
```hcl
output "key_vault_id" {
  value = azurerm_key_vault.kv.id
}
```

Note this module receives `service_principal_object_id` and
`tenant_id` as inputs — these are outputs from the *other* module
(`service_principal`), passed through the root module. This is the
core reusability payoff modules provide: modules can compose with
each other, with the root module acting as the coordinator wiring
outputs from one module into the inputs of another.

**Calling it from the root module:**
```hcl
module "keyvault" {
  source = "./modules/keyvault"

  key_vault_name              = var.key_vault_name
  location                     = azurerm_resource_group.rg.location
  resource_group_name          = azurerm_resource_group.rg.name
  service_principal_name       = var.service_principal_name
  service_principal_object_id  = module.service_principal.service_principal_object_id
  tenant_id                     = module.service_principal.tenant_id
}
```

---

## 14. Storing the Service Principal's Secret in Key Vault

Back in the root module, after both the `service_principal` and
`keyvault` modules exist:

```hcl
resource "azurerm_key_vault_secret" "client_id" {
  name         = "client-id"
  value        = module.service_principal.client_id
  key_vault_id = module.keyvault.key_vault_id
}

resource "azurerm_key_vault_secret" "client_secret" {
  name         = "client-secret"
  value        = module.service_principal.client_secret
  key_vault_id = module.keyvault.key_vault_id
}
```

This is a plain `resource` block, not wrapped in a module — matching
the video's own reasoning: not every resource needs to be a module,
particularly single-use ones that don't benefit from repetition
across multiple instances. Overusing modules for trivial, one-off
resources adds indirection without a real reusability payoff.

---

## 15. The AKS Module — Full Breakdown

**`modules/aks/main.tf`** (core structure; version handling covered
separately in Section 16-17)

```hcl
resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.dns_prefix
  kubernetes_version  = local.kubernetes_version
  node_resource_group = "${var.resource_group_name}-nodes"

  default_node_pool {
    name       = "default"
    vm_size    = var.vm_size
    min_count  = var.min_count
    max_count  = var.max_count
    node_labels = var.node_labels

    tags = var.tags
  }

  service_principal {
    client_id     = var.client_id
    client_secret = var.client_secret
  }

  linux_profile {
    admin_username = "ubuntu"

    ssh_key {
      key_data = file("~/.ssh/id_rsa.pub")
    }
  }

  network_profile {
    network_plugin = "azure"
  }
}
```

`node_resource_group` explains something the video mentions but
doesn't fully define: AKS automatically creates a **second** resource
group, separate from the one you specify, to hold the actual VM scale
set, load balancer, and networking resources backing your node pool.
This is normal AKS behaviour, not something this Terraform code
invents — Azure does this regardless of whether you provision via
Terraform, the CLI, or the Portal.

---

## 16. The Kubernetes Version Data Source (With a Naming Correction)

The video refers to a data source for the "current" Kubernetes
version. Worth being precise about the actual resource name, since
getting this wrong causes a straightforward "no such data source"
error: it is **`azurerm_kubernetes_service_versions`** (plural
"versions"), not a singular "version."

```hcl
data "azurerm_kubernetes_service_versions" "current" {
  location        = var.location
  include_preview = false
}
```

This data source returns a list of valid versions for the given
region; `latest_version` is the attribute exposing the newest
non-preview version available.

---

## 17. The Instructor's Two To-Do Items, Explained and Implemented

The video explicitly leaves two items as an exercise. Both are worth
implementing fully rather than leaving as "homework," since they
address real gaps in the initial design.

### To-do 1: use a specified version if provided, otherwise fall back to latest

```hcl
variable "kubernetes_version" {
  type        = string
  description = "Specific Kubernetes version to use; leave null to use the latest available"
  default     = null

  validation {
    condition     = var.kubernetes_version == null || can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.kubernetes_version))
    error_message = "kubernetes_version must be in the form MAJOR.MINOR.PATCH (e.g. 1.29.2), or left null."
  }
}

locals {
  kubernetes_version = var.kubernetes_version != null ? var.kubernetes_version : data.azurerm_kubernetes_service_versions.current.latest_version
}
```

This is the exact conditional-expression pattern from **Day 10** —
`condition ? true_value : false_value` — applied here to choose
between a user-supplied version and a data-source-derived default.

The `validation` block uses `can(regex(...))`, combining Day 12's
`validation` block pattern with a regular expression check for the
`MAJOR.MINOR.PATCH` format the instructor asks for. `can()` wraps an
expression that might error, and returns `true`/`false` instead of
letting the error propagate — the standard way to build a
validation condition around something that could otherwise fail
outright.

**A pragmatic note the video doesn't raise:** always pinning to
"latest" in a production cluster is itself a risk — an unattended
`terraform apply` after a new AKS version is released could trigger an
unplanned, potentially disruptive cluster upgrade. The `null`-defaults-
to-latest pattern above is fine for a learning environment; for
anything you actually run workloads on, explicitly pinning
`kubernetes_version` to a tested value and upgrading deliberately is
the safer operational choice.

### To-do 2: generate SSH keys with the `tls_private_key` resource

Instead of relying on a pre-existing local `~/.ssh/id_rsa.pub`:

```hcl
resource "tls_private_key" "aks_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
```

Then reference `tls_private_key.aks_ssh.public_key_openssh` in the
`linux_profile.ssh_key.key_data` argument instead of `file(...)`, and
`tls_private_key.aks_ssh.private_key_pem` if you need to store the
private key (for example, uploading it to Key Vault, exactly as the
video suggests for symmetry with the Service Principal secret
handling in Section 14).

This requires declaring the `tls` provider:
```hcl
terraform {
  required_providers {
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}
```

The advantage over `file("~/.ssh/id_rsa.pub")`: the configuration
becomes fully self-contained and portable — it no longer depends on a
specific file existing on whichever machine happens to run
`terraform apply`, which is a real fragility in the video's original
approach (it would fail on a fresh CI/CD runner, for instance, with no
`~/.ssh/id_rsa.pub` present at all).

---

## 18. Writing the Kubeconfig File — And Its Sensitivity Problem

```hcl
resource "local_file" "kubeconfig" {
  filename = "${path.module}/kubeconfig"
  content  = module.aks.kube_config_raw
}
```

Worth flagging directly: `kube_config_raw` (the underlying
`azurerm_kubernetes_cluster` attribute this ultimately exposes) is
marked `sensitive` by the AzureRM provider, because it contains
full cluster-admin credentials. Depending on your Terraform/provider
version, directly assigning a sensitive value to a non-sensitive
resource argument like `local_file.content` may produce an error or a
warning requiring you to explicitly acknowledge the sensitivity. If
you hit this, the pattern from Day 12 applies:

```hcl
resource "local_file" "kubeconfig" {
  filename = "${path.module}/kubeconfig"
  content  = nonsensitive(module.aks.kube_config_raw)
}
```

Using `nonsensitive()` here is a deliberate choice to write a
genuinely sensitive credential to a plaintext file on local disk — do
this with your eyes open. Set restrictive file permissions immediately
afterward, and never commit this file to version control (add
`kubeconfig` to `.gitignore` before your first `terraform apply`, not
after).

**PowerShell — restricting file permissions after creation:**
```powershell
$acl = Get-Acl ".\kubeconfig"
$acl.SetAccessRuleProtection($true, $false)
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule($env:USERNAME, "FullControl", "Allow")
$acl.SetAccessRule($rule)
Set-Acl ".\kubeconfig" $acl
```

---

## 19. Running the Deployment

```powershell
Set-Location "C:\projects\day20"

$env:ARM_CLIENT_ID       = "your-client-id"
$env:ARM_CLIENT_SECRET   = "your-client-secret"
$env:ARM_TENANT_ID       = "your-tenant-id"
$env:ARM_SUBSCRIPTION_ID = "your-subscription-id"

terraform init
terraform validate
terraform plan
```

Expect roughly nine resources in the plan, matching the video's count:
resource group, service principal application, service principal,
service principal password, role assignment, key vault, two key vault
secrets, and the AKS cluster (the underlying node pool resources are
created automatically by Azure as part of the cluster resource, not
as separate top-level Terraform resources you manage directly).

```powershell
terraform apply --auto-approve
```

---

## 20. Verifying the Cluster

```powershell
# Point kubectl at the generated kubeconfig
$env:KUBECONFIG = ".\kubeconfig"

kubectl get nodes
kubectl get namespaces
kubectl get pods -n kube-system
```

**Checking node pool VM scale set instances directly via Azure CLI:**
```powershell
az vmss list --resource-group "day20-rg-nodes" --output table
az vmss list-instances --resource-group "day20-rg-nodes" --name "<vmss-name>" --output table
```

---

## 21. The Bank of Anthos Extension

The video points to Google Cloud's **Bank of Anthos** — an open-source
microservices demo application (frontend, backend services, multiple
databases, a load-generation component) — as an optional follow-up
exercise for deploying a realistic multi-service application onto the
cluster you just built.

Important context worth adding rather than skipping: Bank of Anthos
was originally built and documented for deployment on Google
Kubernetes Engine (GKE), not AKS. The instructor mentions maintaining
a modified fork with GKE-specific flags disabled so it runs on any
standard Kubernetes cluster, including AKS. If you attempt this
extension using the *original* upstream Google repository rather than
a modified version, expect to hit GKE-specific assumptions (certain
annotations, node selectors, or GCP-specific service accounts) that
won't resolve cleanly on AKS without similar adjustments.

**PowerShell — the general workflow, once you have working manifests:**
```powershell
git clone <the-repository-you-are-using>
Set-Location ".\bank-of-anthos"

kubectl apply -f ./kubernetes-manifests

kubectl get pods
kubectl get service frontend
```

The `frontend` service, once its external IP is assigned by the Azure
Load Balancer, gives you a browser-accessible login page for the demo
banking application.

---

## 22. Complete Code Skeleton

**Root module — `provider.tf`**
```hcl
terraform {
  required_version = ">= 1.9.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "azuread" {}
```

**Root module — `main.tf`**
```hcl
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

module "service_principal" {
  source                  = "./modules/service_principal"
  service_principal_name  = var.service_principal_name

  depends_on = [azurerm_resource_group.rg]
}

resource "azurerm_role_assignment" "sp_contributor" {
  scope                = azurerm_resource_group.rg.id   # scoped to RG, not subscription — see Section 12
  role_definition_name = "Contributor"
  principal_id          = module.service_principal.service_principal_object_id

  depends_on = [module.service_principal]
}

module "keyvault" {
  source                        = "./modules/keyvault"
  key_vault_name                = var.key_vault_name
  location                       = azurerm_resource_group.rg.location
  resource_group_name            = azurerm_resource_group.rg.name
  service_principal_object_id    = module.service_principal.service_principal_object_id
  tenant_id                       = module.service_principal.tenant_id
}

resource "azurerm_key_vault_secret" "client_id" {
  name         = "client-id"
  value        = module.service_principal.client_id
  key_vault_id = module.keyvault.key_vault_id
}

resource "azurerm_key_vault_secret" "client_secret" {
  name         = "client-secret"
  value        = module.service_principal.client_secret
  key_vault_id = module.keyvault.key_vault_id
}

module "aks" {
  source               = "./modules/aks"
  cluster_name         = var.cluster_name
  location             = azurerm_resource_group.rg.location
  resource_group_name  = azurerm_resource_group.rg.name
  dns_prefix           = var.dns_prefix
  client_id            = module.service_principal.client_id
  client_secret        = module.service_principal.client_secret
  vm_size              = var.vm_size
  min_count            = var.min_count
  max_count            = var.max_count

  depends_on = [azurerm_role_assignment.sp_contributor]
}

resource "local_file" "kubeconfig" {
  filename = "${path.module}/kubeconfig"
  content  = nonsensitive(module.aks.kube_config_raw)
}
```

**Root module — `variables.tf`**
```hcl
variable "resource_group_name"    { type = string, default = "day20-rg" }
variable "location"               { type = string, default = "Canada Central" }
variable "service_principal_name" { type = string, default = "day20-aks-sp" }
variable "key_vault_name"         { type = string, default = "day20-aks-kv" }
variable "cluster_name"           { type = string, default = "day20-aks" }
variable "dns_prefix"             { type = string, default = "day20aks" }
variable "vm_size"                { type = string, default = "Standard_D2s_v3" }
variable "min_count"              { type = number, default = 1 }
variable "max_count"              { type = number, default = 3 }
```

(Directory layout for the child modules follows Sections 10, 13, and 15.)

---

## 23. Common Mistakes

**Mistake 1 — Forgetting `source` on a module block.** It's the one
mandatory argument every `module` block needs; without it Terraform
has no idea what code to invoke.

**Mistake 2 — Referencing a module output that was never declared.**
If a value is calculated inside a child module but not explicitly
listed in that module's `outputs.tf`, it is completely invisible to
the calling module — there's no implicit exposure of internal
resource attributes across a module boundary.

**Mistake 3 — Granting subscription-wide Contributor access by
default.** Covered in full in Section 12 — always ask whether a
narrower scope (resource group, or even a specific resource) would
satisfy the actual requirement.

**Mistake 4 — Assuming `sensitive = true` protects the state file.**
It only suppresses terminal/log output. The value is still in
`terraform.tfstate` in plaintext — secure the backend (Day 4), don't
rely on output markings alone.

**Mistake 5 — Hardcoding `file("~/.ssh/id_rsa.pub")` in a module meant
to be reusable or run in CI/CD.** This assumes a specific file exists
on whatever machine happens to run `terraform apply`. Section 17's
`tls_private_key` alternative removes this fragility entirely.

**Mistake 6 — Using the wrong AKS Kubernetes-version data source
name.** It's `azurerm_kubernetes_service_versions` (plural), not a
singular "version" — a small naming slip that produces an immediate,
unambiguous "no such data source" error, so at least it fails loudly
rather than silently.

---

## 24. Practice Exercises

**Exercise 1** — Explain, in your own words, the difference between a
root module, a calling module, and a child module, using this
project's own `service_principal` module as a concrete example of each
role it plays (or doesn't play) at different points.

*Answer:* The top-level `main.tf` is the root module. That same
`main.tf` is also the calling module with respect to
`module "service_principal" { ... }`, because it contains the block
invoking that module. The code inside `modules/service_principal/`
is the child module — it never calls anything else in this project,
so it never plays the "calling module" role itself.

**Exercise 2** — The `azurerm_role_assignment` resource in this
project's original form scopes Contributor access to the entire
subscription. Rewrite it to scope access to just the resource group,
and explain the practical security benefit.

*Answer:* Shown in Section 12 — replace the subscription-ID-built
scope string with `azurerm_resource_group.rg.id`. Benefit: if this
Service Principal's credentials were ever leaked or misused, the
damage is contained to resources inside that one resource group,
rather than every resource group in the entire subscription.

**Exercise 3** — Why does Microsoft's current guidance favor Managed
Identity over a Service Principal with a stored client secret for a
resource like an AKS cluster?

*Answer:* Managed Identity credentials are issued, rotated, and
retired automatically by the Azure platform, with no retrievable
secret ever existing for an attacker to steal or for you to
accidentally leak. A Service Principal's client secret, by contrast,
has a fixed expiration, must be manually rotated, and has to be
stored somewhere (as this project stores it in Key Vault) — an extra
credential-handling responsibility that Managed Identity removes
entirely.

---

## 25. Summary Reference

A module is source-referenced with a mandatory `source` argument;
inputs are passed as arguments in the `module` block matching the
child module's declared variables; outputs are retrieved with
`module.<name>.<output>`.

Root module: your top-level `.tf` files, always exactly one per
project. Calling module: whichever module (root or otherwise)
contains a `module` block. Child module: the module being invoked.

This project's identity approach (Service Principal + Key Vault
secret) is functional and worth understanding, but Managed Identity is
Microsoft's current recommendation for new AKS clusters — fewer moving
parts, no manually rotated secret, no credential stored anywhere
retrievable.

Sensitivity markings (`sensitive = true`, `nonsensitive()`) control
terminal/log output only — they do not encrypt the Terraform state
file, which still requires the remote-backend-with-access-control
approach from Day 4 regardless of how carefully outputs are marked.

Role assignment scope should generally match the actual operational
need — default to the narrowest scope (a specific resource group)
rather than the subscription root, unless there's a genuine
requirement for broader access.

---

*Guide covers: Terraform modules, root/calling/child module
terminology, local vs public vs private registry modules, module
reusability rationale, module block syntax and the mandatory source
argument, passing input variables into modules, retrieving output
variables from modules, sensitive value propagation across module
boundaries, azuread_application/azuread_service_principal/
azuread_service_principal_password resource chain (connecting to Day
16), Azure RBAC role assignment scope and least-privilege
considerations, azurerm_key_vault and access policies, storing
secrets with azurerm_key_vault_secret, azurerm_kubernetes_cluster
core configuration, node_resource_group behaviour, the
azurerm_kubernetes_service_versions data source (with a naming
correction from the source video), conditional kubernetes_version
selection with validation and regex, tls_private_key as an alternative
to local SSH key files, local_file for kubeconfig generation and its
sensitivity handling, PowerShell file-permission restriction for
credential files, kubectl verification commands, and a direct
correction regarding Service Principal versus Managed Identity as the
current recommended AKS identity pattern.*
