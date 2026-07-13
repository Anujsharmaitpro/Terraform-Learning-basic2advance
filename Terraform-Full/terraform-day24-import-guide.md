# Terraform Import — Bringing Existing Azure Resources Under Management
## Deep-Dive Learning Guide — Day 24 / 28 Days of Easy Terraform
### Beginner-First Edition | PowerShell Throughout

---

## Before You Start

This is Day 24. Every prior project in this series started from
nothing — Terraform created every resource from scratch. Today's
topic is the opposite, and arguably more common in real organizations:
resources that already exist, created manually or by another tool,
that you now need to bring under Terraform's management without
destroying and recreating them.

The video covers three approaches: the native `terraform import` CLI
command, Microsoft's `aztfexport` tool, and Google's open-source
`terraformer`. I'll walk through all three as demonstrated, but with
a few corrections and additions worth knowing: the exact current tool
name (it's changed), a newer Terraform-native alternative the video
doesn't mention, and a clearer explanation of what actually happens
when you remove a resource from Terraform's state — a step used
several times in this demo that's worth understanding precisely rather
than treating as "the resources are gone now."

---

## Table of Contents

1. What Problem Does Import Actually Solve?
2. Three Ways to Import — Honest Tradeoffs
3. Why Order Matters — The Top-Down Approach
4. Method 1: Native `terraform import` — Step by Step
5. A Modern Alternative: The Declarative `import` Block
6. Verifying an Import: `state list`, `state show`, and `plan`
7. "Zero Changes" as the Success Signal — And When Small Diffs Are Still Fine
8. Deprecated Resource Names You'll Hit Along the Way
9. A Critical Clarification: `terraform state rm` Does Not Delete Anything in Azure
10. The Real Risk of Removing Resources From State
11. Method 2: `aztfexport` — Correcting the Tool's Name
12. Installing and Running `aztfexport`
13. The Real Limitations of Auto-Generated Code
14. Method 3: Terraformer
15. Choosing Between the Three Methods
16. The Custom Hostname Binding Issue — Explained Properly
17. Recreating the Demo Environment — PowerShell Version
18. Complete Working Example — Native Import Walkthrough
19. Common Mistakes
20. Practice Exercises
21. Summary Reference

---

## 1. What Problem Does Import Actually Solve?

Every Terraform command in this series so far has assumed Terraform
created the resource in the first place, so it already has an entry
in the state file (Day 4) tracking that relationship. **Import solves
the opposite scenario:** a resource exists in Azure — created manually
through the Portal, via Azure CLI, by a colleague, or by a legacy tool
— and you want Terraform to manage it going forward, without deleting
and recreating it (which would likely cause downtime, data loss, or
both, depending on the resource).

Import connects an *existing* real-world resource to a corresponding
entry in Terraform's state file, so that from that point onward,
`terraform plan` and `terraform apply` treat it exactly like any
resource Terraform originally created.

---

## 2. Three Ways to Import — Honest Tradeoffs

**Native `terraform import`** — you write the `.tf` configuration
yourself first, matching the real resource's actual settings exactly,
then run an import command per resource to link it to state. This is
the most manual approach, requiring the most upfront work, but it's
also the most predictable and the one HashiCorp itself maintains and
recommends as the primary supported path.

**`aztfexport`** (Microsoft's tool) — scans an existing Resource Group
and *generates* both the `.tf` configuration files and imports them
into state automatically, in one step. Far less manual work, but the
generated code has real limitations worth understanding before relying
on it (Section 13).

**Terraformer** (Google's open-source, multi-cloud tool) — works
similarly to `aztfexport` conceptually, but supports multiple cloud
providers with one consistent tool, at the cost of narrower Azure
resource-type coverage and being a community-maintained project rather
than an official Microsoft or HashiCorp offering.

The video's own conclusion is worth stating plainly rather than
softening: native `terraform import` is the recommended approach for
production use; the two auto-generation tools are better suited to
learning, prototyping, and quick one-off migrations where you'll
thoroughly review and refactor the generated code before trusting it
long-term.

---

## 3. Why Order Matters — The Top-Down Approach

When writing the `.tf` configuration to match existing resources by
hand (required for native import), the order you define resources in
your files should follow the same dependency order Terraform would use
if creating them from scratch: Resource Group first, then Virtual
Network, then Subnet, then anything depending on the subnet, and so
on. This isn't strictly a syntax requirement — Terraform doesn't
literally process a file top-to-bottom — but writing configuration
that references resources before they're defined makes the code
significantly harder for a human to read and reason about, and
increases the odds of a typo'd reference. It's the same top-down logic
Day 3's implicit dependency material established, applied here as a
writing discipline rather than a strict technical requirement.

---

## 4. Method 1: Native `terraform import` — Step by Step

### Writing the matching configuration first

Every field in your `.tf` file needs to match the real resource
exactly — same name, same location, same address space, same SKU.
Get any of these wrong and the import can still technically succeed
(the state file just records what's *actually* there), but your
subsequent `terraform plan` will then show unexpected changes, because
your configuration doesn't match reality.

```hcl
variable "prefix" {
  type    = string
  default = "day24"
}

variable "location" {
  type    = string
  default = "East US"
}

resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-rg"
  location = var.location
}
```

### Running the import command

**PowerShell:**
```powershell
Set-Location "C:\projects\day24"

terraform init
terraform plan   # confirm it currently shows "1 to add" — proving state has no record of this resource yet

terraform import azurerm_resource_group.rg "/subscriptions/<sub-id>/resourceGroups/day24-rg"
```

The resource ID (the long `/subscriptions/.../resourceGroups/...`
path) is retrievable from the Azure Portal on most resources' Overview
or Properties pane, or directly via CLI — which is generally faster
and less error-prone than clicking through the Portal:

**PowerShell — retrieving the resource ID directly, instead of hunting
through Portal pages:**
```powershell
az group show --name "day24-rg" --query "id" -o tsv
```

For other resource types, the equivalent lookup pattern is
`az <service> show ... --query "id" -o tsv` — for example:
```powershell
az network vnet show --resource-group "day24-rg" --name "day24-vnet" --query "id" -o tsv
az network vnet subnet show --resource-group "day24-rg" --vnet-name "day24-vnet" --name "default" --query "id" -o tsv
az appservice plan show --resource-group "day24-rg" --name "day24-plan" --query "id" -o tsv
```

This avoids the video's manual copy-paste-from-the-Portal workflow
entirely, and is worth adopting as your default habit — it's faster
and eliminates the risk of copying a stale or truncated ID.

Repeat this write-config-then-import cycle once per resource, in the
top-down order from Section 3.

---

## 5. A Modern Alternative: The Declarative `import` Block

The video only demonstrates the CLI-based `terraform import` command.
Worth knowing about, since it changes the recommended workflow for
anyone using a reasonably current Terraform version: since Terraform
1.5, HashiCorp added a **declarative `import` block**, written
directly inside your `.tf` files, as an alternative to the imperative
CLI command.

```hcl
import {
  to = azurerm_resource_group.rg
  id = "/subscriptions/<sub-id>/resourceGroups/day24-rg"
}

resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-rg"
  location = var.location
}
```

With this block present, running `terraform plan` shows you exactly
what the import will do — and, critically, whether your written
configuration actually matches the real resource — *before* you
commit to running `terraform apply`. The CLI-based `terraform import`
command performs the import immediately with no preview step; the
block-based approach lets you review the plan first, exactly like any
other Terraform change, and can be committed to version control and
reviewed via pull request like any other configuration change — fitting
the same "policy as code" review discipline Day 21 established.

```powershell
terraform plan   # preview the import
terraform apply  # perform it
```

Once the import completes successfully, the `import` block is no
longer needed and is typically removed from the configuration (it's a
one-time instruction, not an ongoing declaration like a `resource`
block). I'd recommend this approach over the raw CLI command for new
work on Terraform 1.5+, precisely because of that preview step — it
directly addresses the "did I get the configuration exactly right"
uncertainty the video spends real time manually verifying after each
CLI import.

---

## 6. Verifying an Import: `state list`, `state show`, and `plan`

```powershell
terraform state list
```
Confirms the resource address now appears in state — proof the import
registered correctly.

```powershell
terraform state show azurerm_resource_group.rg
```
Shows every attribute Terraform now has recorded for this resource,
useful for spotting anything your hand-written configuration missed
(like a tag that exists on the real resource but isn't yet reflected
in your `.tf` file).

```powershell
terraform plan
```
The real test — if your configuration exactly matches the imported
resource's actual state, this reports no changes needed.

---

## 7. "Zero Changes" as the Success Signal — And When Small Diffs Are Still Fine

The video correctly frames "no changes to the infrastructure" as the
goal after a successful, fully-matched import. Worth adding a small
but practically important nuance the video itself runs into later:
after importing the App Service and its plan, `terraform plan` showed
one resource with two small pending changes (default `site_config`
values around IP restriction defaults that weren't explicitly written
into the hand-typed configuration).

This is a normal, expected outcome, not a failure — resources
frequently have dozens of attributes, many with platform-assigned
defaults you didn't explicitly set. A small diff limited to defaulted
fields (rather than something structurally significant, like the
wrong SKU or wrong region) is generally safe to either accept via
`terraform apply` (which will just set those fields explicitly going
forward, matching what's already effectively true) or resolve by
adding the missing fields to your configuration to make it fully
explicit. The meaningful distinction is between a small, defaults-only
diff and a diff indicating your configuration actually
misrepresents something structurally different about the real resource.

---

## 8. Deprecated Resource Names You'll Hit Along the Way

Consistent with the deprecation pattern this series has flagged
repeatedly (Day 17, Day 20, Day 21, Day 22), importing an App Service
today means using the *current* resource names, not whatever name an
older tutorial or the Azure Portal's own labeling might suggest:

- `azurerm_app_service_plan` → use `azurerm_service_plan` instead
- `azurerm_app_service` → use `azurerm_linux_web_app` (or
  `azurerm_windows_web_app`) instead

The video also hits a specific, easy-to-miss field rename between
provider versions: the App Service Plan reference field on the web app
resource is `service_plan_id` in current versions — an older
provider version used a differently-cased or differently-named
argument. When something you copied from slightly outdated
documentation produces an "argument not expected" or "required
argument missing" error, checking the exact current argument name
against the live Terraform Registry documentation for your pinned
provider version (Day 2's version-pinning discipline) is the right
first move, rather than assuming the resource type itself is wrong.

---

## 9. A Critical Clarification: `terraform state rm` Does Not Delete Anything in Azure

The video uses `terraform state rm` twice — once deliberately, to
demonstrate what happens when Terraform "forgets" about resources it
was previously tracking, and once to fix the custom-hostname-binding
issue in Section 16. This deserves a precise, standalone explanation,
because it's one of the most commonly misunderstood Terraform commands:

**`terraform state rm <resource_address>` removes an entry from
Terraform's state file only. It does not touch the actual Azure
resource in any way.** The real, running resource in Azure is
completely unaffected — it keeps existing, keeps serving traffic,
keeps costing money, exactly as before. All that changes is that
Terraform's own bookkeeping no longer has a record connecting that
`resource` block to that specific real-world resource.

This is precisely why, after the video removes all five resources from
state, `terraform plan` reports "5 to add" — not because those
resources were destroyed, but because Terraform's state file has
genuinely lost track of them and, from Terraform's perspective, they
no longer exist as far as *its own bookkeeping* is concerned, even
though they are still fully present and running in Azure.

---

## 10. The Real Risk of Removing Resources From State

Worth flagging directly rather than treating this step as a purely
neutral teaching device: intentionally desynchronizing state from
reality, even briefly and even for a demo, has a real practical risk
worth naming explicitly. If you ran `terraform apply` at that exact
moment (rather than importing again, or switching to `aztfexport`, as
the video does), Terraform would attempt to *create* all five
resources fresh — and for resources with globally or regionally
unique naming requirements (SQL Server names in Day 22, Storage
Account names in Day 3 and Day 18), that attempt would fail outright
with a naming collision, because the "new" resource Terraform is
trying to create already exists under that exact name.

For resources without a uniqueness constraint, the situation is
arguably worse: Terraform might actually succeed in creating a
*second*, genuinely duplicate resource with the same name in the same
resource group (where Azure permits that), leaving you with orphaned,
duplicate infrastructure and a state file that no longer accurately
reflects what's really running. The takeaway: `terraform state rm` is
a legitimate, sometimes-necessary command (Section 16 shows a case
where it's the correct fix), but it should always be a deliberate,
understood step — immediately followed by either re-importing the
resource properly or genuinely destroying it — never left in a
half-finished, state-doesn't-match-reality condition for longer than
necessary.

---

## 11. `aztfexport` — Correcting the Tool's Name

The video refers to this tool inconsistently across the recording
("ASF export," "az TF export"). Worth stating the actual, current name
clearly, since getting this wrong makes the tool genuinely difficult
to find or install: Microsoft's tool is called **`aztfexport`** (one
word, no spaces). It was previously named `aztfy`, and you may still
encounter that older name in some tutorials, blog posts, or Stack
Overflow answers predating the rename — both names refer to the same
Microsoft-maintained, open-source project, but `aztfexport` is the
current, correct command name to actually type.

---

## 12. Installing and Running `aztfexport`

**PowerShell — installation on Windows:**
```powershell
winget install microsoft.aztfexport
```

(macOS: `brew install aztfexport`; Linux: available via the same
package managers the video mentions — `apt`, `yum`, or direct binary
download from the GitHub releases page.)

**Verifying installation:**
```powershell
aztfexport --help
```

**Running an export for an entire resource group, generating both
configuration *and* importing into state in one step:**
```powershell
Set-Location "C:\projects\day24\export"

az login
aztfexport resource-group "day24-rg"
```

The `--non-interactive` flag (used in the video) skips the tool's
interactive review-before-import prompts — useful for scripting, but
worth using deliberately rather than by default, since the interactive
mode gives you a chance to review what's about to be imported before
committing to it, similar in spirit to the `import` block's preview
step from Section 5.

---

## 13. The Real Limitations of Auto-Generated Code

The video is appropriately honest about this, and it's worth
reinforcing with specifics: auto-generated Terraform code from either
`aztfexport` or Terraformer is functionally correct (it will
accurately reflect the resource as it currently exists) but is not
idiomatic, hand-crafted Terraform. Concretely, expect:

- **Every value hardcoded**, with no `variable` blocks — the naming
  patterns, locations, and SKUs this entire series has taught you to
  parameterize (Day 5) are absent by default, and reintroducing them
  is manual follow-up work
- **Explicit `depends_on` used everywhere**, even where an implicit
  dependency (Day 3) through a direct attribute reference would be
  cleaner and self-documenting
- **Sensitive values potentially exported in plaintext** — the video
  notes secrets can end up directly in the generated configuration;
  treat any freshly exported configuration as needing the exact same
  sensitive-value handling (Day 12, Day 20, Day 22) as anything you'd
  write by hand, before it's safe to commit to version control
- **No file structure discipline** (Day 6) — everything typically
  lands in one large generated file, needing manual splitting into
  the provider/variables/locals/resources/outputs pattern this series
  has used throughout

None of this makes the tool useless — for a one-time migration of a
sprawling, previously-unmanaged environment, generating a working
starting point and then refactoring it is often faster than writing
every resource block by hand from scratch. The important discipline is
treating the output as a **first draft requiring review**, not
production-ready code to commit as-is.

---

## 14. Method 3: Terraformer

```powershell
# Authenticate
$env:ARM_SUBSCRIPTION_ID = "your-subscription-id"

terraformer import azure --resources="*" --path-pattern="{output}/{provider}/"
```

Terraformer's practical tradeoff versus `aztfexport`, worth stating
directly rather than treating the two as interchangeable: `aztfexport`
is Microsoft's own tool, purpose-built for Azure, and generally has
broader and more current Azure resource-type coverage since it's
maintained alongside the AzureRM provider itself. Terraformer's value
proposition is consistency *across* multiple clouds with one tool and
one command syntax — genuinely useful if your organization manages
AWS, GCP, and Azure with the same import tooling and wants one learning
curve rather than three. If your work is Azure-only, `aztfexport` is
generally the better default choice; reach for Terraformer
specifically when the multi-cloud consistency benefit outweighs its
narrower per-cloud resource coverage.

---

## 15. Choosing Between the Three Methods

For a small number of resources (a handful, as in this demo), or
anything going into a production environment you intend to maintain
long-term: native `terraform import` (or its modern `import` block
equivalent from Section 5), because you end up with clean, reviewed,
idiomatic configuration you actually understand line by line.

For a large, previously-unmanaged environment with many resources, as
an initial migration starting point: `aztfexport`, accepting that
substantial manual refactoring follows before the generated code
matches this series' standards for variables, dependencies, and file
structure.

For genuine multi-cloud environments needing one consistent import
workflow: Terraformer, with the same review-and-refactor expectation.

---

## 16. The Custom Hostname Binding Issue — Explained Properly

The video's final `terraform destroy` fails partway through with an
error about a `custom_hostname_binding` resource and "the host name
for site must include the default host name." The video frames this
as "possibly a bug" — worth being more precise, since this is
documented, expected behavior rather than a genuine defect: Azure App
Service automatically creates and manages a binding for its own
platform-default hostname (the `*.azurewebsites.net` domain) as an
intrinsic part of the App Service resource itself. This default
binding is not something you're meant to independently create,
manage, or destroy as a separate Terraform resource — it exists
automatically for as long as the App Service itself exists, and
disappears automatically when the App Service is deleted.

`aztfexport`'s auto-generation process picked up this platform-managed
default binding as if it were an independently manageable resource
(a reasonable but imperfect inference, since from the Azure Resource
Manager API's perspective it does technically have its own resource
ID), which is exactly the kind of over-inclusive auto-generation
Section 13 flags as a real limitation. The video's fix —
`terraform state rm` on that specific resource, then removing it from
the generated `.tf` file — is the *correct* resolution, not a
workaround for a mystery bug: you're telling Terraform "don't manage
this platform-intrinsic resource independently," which then allows
`terraform destroy` to correctly remove the App Service (and, as a
natural consequence, its default hostname binding disappears
automatically along with it).

---

## 17. Recreating the Demo Environment — PowerShell Version

The video's original setup script is a Bash script using Azure CLI
commands. Since these are Azure CLI invocations running on your local
machine (not commands inside a remote Linux VM, unlike Day 23's
stress-test scenario), they translate directly to PowerShell without
any of the "this has to stay Bash" caveat from that earlier guide.

```powershell
# infra-setup.ps1

$rgName      = "day24-rg"
$location    = "eastus"
$vnetName    = "day24-vnet"
$subnetName  = "default"
$planName    = "day24-plan"
$webAppName  = "day24-web-app-$(Get-Random -Maximum 99999)"

# Check Azure CLI login status
$account = az account show 2>$null
if (-not $account) {
    Write-Host "Not logged in — launching az login..."
    az login
}

# Create Resource Group
az group create --name $rgName --location $location

# Create Virtual Network and Subnet
az network vnet create `
  --resource-group $rgName `
  --name $vnetName `
  --address-prefix "10.0.0.0/16" `
  --subnet-name $subnetName `
  --subnet-prefix "10.0.1.0/24"

# Create App Service Plan (Linux, Basic tier)
az appservice plan create `
  --resource-group $rgName `
  --name $planName `
  --location $location `
  --is-linux `
  --sku B1

# Create Web App
az webapp create `
  --resource-group $rgName `
  --plan $planName `
  --name $webAppName `
  --runtime "NODE:18-lts"

Write-Host "Created web app: $webAppName"
Write-Host "Default URL: https://$webAppName.azurewebsites.net"
```

```powershell
.\infra-setup.ps1
```

---

## 18. Complete Working Example — Native Import Walkthrough

**`provider.tf`**
```hcl
terraform {
  required_version = ">= 1.9.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.8"
    }
  }
}

provider "azurerm" {
  features {}
}
```

**`variables.tf`**
```hcl
variable "prefix"   { type = string, default = "day24" }
variable "location" { type = string, default = "eastus" }
```

**`main.tf`** — written to exactly match the resources created by
Section 17's script, in top-down order:

```hcl
resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-rg"
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "${var.prefix}-vnet"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "subnet" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_service_plan" "asp" {
  name                = "${var.prefix}-plan"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "B1"
}

resource "azurerm_linux_web_app" "webapp" {
  name                = "day24-web-app-XXXXX"   # match the actual generated name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_service_plan.asp.location
  service_plan_id     = azurerm_service_plan.asp.id

  site_config {
    application_stack {
      node_version = "18-lts"
    }
  }
}
```

**PowerShell — importing each resource in order:**
```powershell
$sub = az account show --query "id" -o tsv

terraform import azurerm_resource_group.rg `
  "/subscriptions/$sub/resourceGroups/day24-rg"

terraform import azurerm_virtual_network.vnet `
  (az network vnet show --resource-group "day24-rg" --name "day24-vnet" --query "id" -o tsv)

terraform import azurerm_subnet.subnet `
  (az network vnet subnet show --resource-group "day24-rg" --vnet-name "day24-vnet" --name "default" --query "id" -o tsv)

terraform import azurerm_service_plan.asp `
  (az appservice plan show --resource-group "day24-rg" --name "day24-plan" --query "id" -o tsv)

terraform import azurerm_linux_web_app.webapp `
  (az webapp show --resource-group "day24-rg" --name "day24-web-app-XXXXX" --query "id" -o tsv)

terraform plan
```

A clean `terraform plan` reporting no changes (or only minor,
defaults-only differences per Section 7) confirms the import is complete.

---

## 19. Common Mistakes

**Mistake 1 — Writing configuration that doesn't exactly match the
real resource before importing.** Import succeeds regardless (it just
records reality into state), but the follow-up `terraform plan` then
shows a misleading diff between your configuration and the truth —
always verify with `terraform state show` after each import.

**Mistake 2 — Confusing `terraform state rm` with actually deleting a
resource.** Covered fully in Section 9 — it only affects Terraform's
own bookkeeping, never the real Azure resource.

**Mistake 3 — Leaving state desynchronized from reality for longer than
necessary.** Section 10's core point — always follow a `state rm` with
either a proper re-import or a genuine `destroy`, not an indefinite gap.

**Mistake 4 — Using deprecated resource type names when writing
configuration to match an existing resource.** `azurerm_service_plan`
and `azurerm_linux_web_app`/`azurerm_windows_web_app`, not the older
`azurerm_app_service_plan`/`azurerm_app_service` names.

**Mistake 5 — Trusting auto-generated code from `aztfexport` or
Terraformer as production-ready without review.** Section 13's
checklist (variables, implicit dependencies, sensitive values, file
structure) is the minimum refactor before treating generated code as
trustworthy long-term configuration.

**Mistake 6 — Trying to independently manage an App Service's default
hostname binding as its own Terraform resource.** It's platform-managed
and tied to the App Service's own lifecycle — Section 16.

---

## 20. Practice Exercises

**Exercise 1** — After running `terraform state rm
azurerm_resource_group.rg`, a teammate asks whether the Resource Group
still exists in Azure. What's the accurate answer, and why might
someone reasonably (but incorrectly) think otherwise?

*Answer:* Yes, it still fully exists in Azure, completely unaffected —
`state rm` only removes Terraform's own tracking record. Someone might
think otherwise because the *next* `terraform plan` reports "1 to
add," which sounds like the resource is now missing — but that
message describes Terraform's own out-of-date bookkeeping, not the
actual state of the real infrastructure.

**Exercise 2** — Explain why the `import` block (Section 5) is
generally a stronger choice than the raw `terraform import` CLI
command for new work on a current Terraform version.

*Answer:* The block lets you preview the import's effect via
`terraform plan` before it actually happens, and — because it's
declarative HCL rather than an imperative one-off CLI invocation — it
can be committed to version control and reviewed via pull request like
any other configuration change, matching the code-review discipline
established in Day 21 for policy changes.

**Exercise 3** — A resource successfully imports with `terraform
import`, but the subsequent `terraform plan` shows several unexpected
changes beyond simple platform defaults. What's the most likely cause,
and what command helps diagnose it?

*Answer:* The hand-written `.tf` configuration most likely doesn't
accurately match the real resource's actual settings (wrong SKU,
missing a field, wrong region format, etc.) — `terraform state show
<resource_address>` (Section 6) reveals every attribute Terraform
actually recorded for the real resource, letting you compare it
field-by-field against your written configuration to find the mismatch.

---

## 21. Summary Reference

Import connects an existing, already-created resource to a Terraform
state entry, without destroying and recreating it — the opposite
workflow from every earlier day's from-scratch provisioning.

Native `terraform import` (or its modern, previewable `import` block
equivalent, available since Terraform 1.5) is the recommended approach
for production use; `aztfexport` (Microsoft's tool — correctly named,
not "ASF export" or "az TF export") and Terraformer (Google's
open-source multi-cloud tool) trade manual effort for auto-generated
code requiring real refactoring before it matches idiomatic Terraform
practice.

`terraform state rm` never deletes anything in the real cloud
environment — it only removes Terraform's own bookkeeping record, and
should always be followed promptly by either a proper re-import or a
genuine `destroy`, never left in an indefinite mismatched state.

Azure App Service's default hostname binding is platform-managed and
tied to the App Service's own lifecycle — it shouldn't be
independently imported or managed as its own Terraform resource, which
is exactly the issue auto-generated exports can introduce.

---

*Guide covers: Terraform import fundamentals, the three import
methods (native terraform import, aztfexport, Terraformer) and their
honest tradeoffs, the top-down configuration-writing order, retrieving
Azure resource IDs via CLI instead of the Portal, the modern
declarative import block introduced in Terraform 1.5 as an alternative
to the CLI command, terraform state list/state show/plan for import
verification, interpreting small defaults-only plan diffs versus
structurally significant ones, deprecated resource name callbacks
(azurerm_service_plan, azurerm_linux_web_app), a detailed clarification
that terraform state rm never deletes real infrastructure, the
practical risk of leaving state desynchronized from reality, correcting
the tool name aztfexport (formerly aztfy) versus the video's
inconsistent naming, installing and running aztfexport, the concrete
limitations of auto-generated Terraform code (hardcoded values,
unnecessary explicit depends_on, exposed secrets, poor file structure),
Terraformer as a multi-cloud alternative and when it's the better
choice, a corrected explanation of the App Service default hostname
binding issue as documented platform behavior rather than a tool bug,
and a full PowerShell rewrite of the Bash-based demo environment setup
script.*
