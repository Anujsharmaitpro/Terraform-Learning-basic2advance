# HCP Terraform — Organizations, Projects, and Workspaces
## Deep-Dive Learning Guide — Day 25 / 28 Days of Easy Terraform
### Beginner-First Edition | PowerShell Throughout

---

## Before You Start

This is Day 25. Every prior day ran Terraform entirely from your own
machine — local state (until Day 4's remote backend), local
credentials, local execution. Today's topic is HashiCorp's managed
platform for running Terraform: a GUI-based service that handles
state storage, credential management, run history, and Git integration
for you.

One naming correction is worth making immediately, because it affects
whether you can even find the right product: the platform this video
demonstrates is called **HCP Terraform** — not "SCP Terraform," which
isn't a real product name (this appears to be a mishearing of "HCP" in
the source recording). It's also worth being precise about a second,
related naming layer the video blurs together: **HashiCorp Cloud
Platform (HCP)** is the umbrella brand covering several managed
products (HCP Vault, HCP Consul, HCP Boundary, and others). **HCP
Terraform** — formerly called **Terraform Cloud** until a 2024 rebrand
— is one specific product under that umbrella, and it's the one this
entire video is actually about. If you go looking for this yourself,
search for "HCP Terraform" or go directly to `app.terraform.io`.

---

## Table of Contents

1. What Is HCP Terraform? (And the Naming Correction)
2. Why HCP Terraform Exists — The CLI-Only Limitations Recap
3. The Hierarchy: Organization, Project, Workspace
4. The Three Workflow Types
5. Setting Up an Organization and Projects
6. Creating a VCS-Driven Workspace
7. The Critical Distinction: Terraform Variables vs Environment Variables
8. Why Interactive `az login` Cannot Work Here
9. A More Modern Alternative: OIDC Dynamic Credentials
10. Setting Up Service Principal Authentication Correctly
11. Triggering and Reviewing a Run
12. Parameterizing With a Terraform-Category Variable
13. The CLI-Driven Workflow
14. The `cloud` Block — Correct Syntax
15. `terraform login` — What It Does, and Where Credentials Land on Windows
16. Running a Plan via the CLI-Driven Workflow
17. A Pricing Reality Check
18. Sentinel — A Brief Cross-Reference to Day 21
19. The Assignment — Multi-Environment, Branch-Triggered Workspaces
20. Complete Reference Configuration
21. Common Mistakes
22. Practice Exercises
23. Summary Reference

---

## 1. What Is HCP Terraform? (And the Naming Correction)

HCP Terraform is HashiCorp's own managed service for running Terraform
— it stores your state file remotely and securely by default (no
manual backend configuration required, unlike Day 4's self-managed
Azure Blob Storage approach), manages credentials and secrets through
a GUI rather than shell environment variables, keeps a full history of
every plan and apply with logs, and can trigger runs automatically
from a Git repository without any separate CI/CD pipeline tooling.

Every concept in this guide — organizations, projects, workspaces,
workflows — belongs specifically to HCP Terraform, not to the broader
HCP umbrella platform, and not to a product called "SCP."

---

## 2. Why HCP Terraform Exists — The CLI-Only Limitations Recap

This connects directly to every prior day's manual credential and
state handling. Running Terraform purely from your local CLI, as
you've done through Day 1-24, has real limitations once you're working
with a team rather than learning solo:

- Storing login credentials securely requires you to build your own
  solution (environment variables, a `.gitignore`'d file, or a
  separate secrets tool like Key Vault, covered in Day 20)
- Automating runs on a schedule or on every Git push requires standing
  up a separate CI/CD tool
- Sharing private, reusable modules (Day 20) across a team requires
  your own registry infrastructure
- Keeping environments (dev/test/prod) cleanly separated requires
  disciplined manual state-file and folder-structure conventions,
  entirely on you to maintain correctly

HCP Terraform addresses all of these as built-in platform features
rather than things you assemble yourself.

---

## 3. The Hierarchy: Organization, Project, Workspace

**Organization** — the top level, typically representing your company
or team. Everything else lives inside one organization.

**Project** — a logical grouping of related workspaces. The video uses
one project per cloud provider (Azure, AWS, GCP) for its
multi-cloud series — a reasonable grouping strategy, though projects
can be organized by team, application, or any other boundary that
makes sense for your organization.

**Workspace** — the actual unit that maps to what you'd think of as
"one Terraform folder" in the CLI-only world: its own state file, its
own variables, its own run history, its own credentials. The video's
framing is accurate and worth repeating directly: whatever folder of
related `.tf` files you'd have grouped together locally (Day 6's file
structure discipline) becomes one workspace here.

---

## 4. The Three Workflow Types

**Version Control (VCS-driven)** — the workspace is linked to a Git
repository (GitHub, GitLab, Bitbucket, or Azure DevOps are supported).
Any push to the configured branch automatically triggers a plan (and,
if configured, an apply) — no separate webhook or pipeline setup
required; HCP Terraform configures the Git webhook for you.

**CLI-driven** — you keep working from your local terminal, but a
`cloud` block in your configuration (Section 14) tells Terraform to
execute the actual plan/apply *remotely* on HCP Terraform's
infrastructure rather than locally, while still streaming the output
back to your terminal. State, variables, and run history are all
still centrally managed on the platform.

**API-driven** — you trigger runs by calling HCP Terraform's REST API
directly from your own application or automation, rather than through
either the Git integration or the CLI.

---

## 5. Setting Up an Organization and Projects

At `app.terraform.io`, creating an account (via GitHub, GitLab, or
email) prompts you to create your first organization if you don't
already belong to one. From there:

1. Create an organization (e.g., a company or personal name)
2. Inside it, create one or more projects (e.g., `Azure`, `AWS`, `GCP`)
3. Inside each project, create workspaces (e.g., one per environment,
   or — as this particular video does for teaching purposes — one per
   lesson/topic)

This is entirely a GUI-driven process; there's no PowerShell or CLI
step for organization/project creation itself.

---

## 6. Creating a VCS-Driven Workspace

When creating a workspace and selecting the Version Control workflow:

- **VCS provider** — GitHub, GitLab, Bitbucket, or Azure DevOps
- **Repository** — the specific repo containing your `.tf` files
- **Working directory** (advanced option) — useful if your `.tf` files
  live in a subfolder rather than the repo root; left blank defaults
  to the repository root
- **Auto-apply** — whether a successful plan applies automatically, or
  waits for a human to review and confirm (the video deliberately
  leaves this unchecked initially, specifically to demonstrate the
  manual confirmation step)
- **Trigger type** — branch-based (any push to a specified branch
  triggers a run) or tag-based (only pushes matching a specific tag
  pattern trigger a run)

Once a `main.tf` (or any `.tf` file) exists in the linked repository's
configured branch, HCP Terraform automatically detects it on the next
push and queues a plan — you do not need to run `terraform init` or
`terraform plan` yourself anywhere for this workflow type.

---

## 7. The Critical Distinction: Terraform Variables vs Environment Variables

This is where the video spends the most time troubleshooting, and it's
worth resolving with a clear, definitive rule rather than reproducing
the trial-and-error. HCP Terraform workspace variables always belong
to exactly one of two categories, and the category determines *how*
the value is actually delivered to the Terraform run:

**Terraform variable** — populates a `variable { }` block declared in
your `.tf` configuration. It is functionally equivalent to passing
`-var="name=value"` on the CLI (Day 5). Use this category for anything
your own configuration explicitly declares as a `variable`, such as
`storage_account_name` in this project.

**Environment variable** — sets an actual operating-system-level
environment variable inside the remote execution environment where
your plan/apply actually runs. This is the category required for
**`ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`, `ARM_TENANT_ID`, and
`ARM_SUBSCRIPTION_ID`** — because, exactly as covered back in Day 3
and Day 22, the AzureRM provider reads these specific names directly
from the OS environment, not through Terraform's own variable
mechanism. There is no `variable "ARM_CLIENT_ID" { }` block anywhere
in your configuration for these — they bypass Terraform's variable
system entirely, which is precisely why setting them as a "Terraform
variable" in the UI (the mistake the video makes several times before
correcting it) does not work: the provider is looking in the OS
environment, and a Terraform-category variable never reaches there.

The simple, memorizable rule: **if the value's name matches a
`variable` block you wrote yourself, it's a Terraform variable; if
it's one of the four `ARM_*` provider-authentication names (or any
other name a tool reads via its own environment-variable convention,
rather than through a declared Terraform variable), it's an
Environment variable.**

---

## 8. Why Interactive `az login` Cannot Work Here

The video's confusion partway through — trying various approaches to
get Azure CLI-based authentication working inside a workspace run —
is worth resolving with a direct architectural fact rather than
treating it as an unresolved mystery: **`az login`'s standard flow
requires an interactive browser window to complete a device or
authorization-code login.** HCP Terraform's remote execution
environment is a headless, ephemeral, non-interactive compute
environment with no browser and no human present to click through a
login prompt during the run itself. There is no configuration that
makes an interactive `az login` flow work inside that environment —
it's not a matter of finding the right setting.

This is exactly why **Service Principal authentication (Section 10)
is not merely a "better" option but the only viable one** for
non-interactive, automated Azure authentication in this context — the
same reasoning that made Service Principals the right tool for
Day 3's CI/CD-oriented setup and Day 20's AKS provisioning.

---

## 9. A More Modern Alternative: OIDC Dynamic Credentials

Worth flagging as a genuinely better current option than what the
video demonstrates, in the same spirit as Day 20's Managed Identity
correction: HCP Terraform supports **OIDC (OpenID Connect) dynamic
credentials** for Azure. Instead of storing a long-lived
`ARM_CLIENT_SECRET` as a sensitive workspace variable (which is a
standing secret that must be manually rotated and could leak), HCP
Terraform presents a short-lived OIDC token to Azure AD at the start
of each run, and Azure AD issues temporary, run-scoped credentials in
exchange — no persistent secret is stored on the HCP Terraform side at
all.

Setting this up requires configuring an Azure AD federated identity
credential trusting HCP Terraform's OIDC issuer, then setting
`TFC_AZURE_PROVIDER_AUTH = true` and `TFC_AZURE_RUN_CLIENT_ID` as
workspace environment variables instead of a client secret. This is
more setup work than pasting a client secret into a sensitive
variable, but it eliminates exactly the class of standing-credential
risk Day 4, Day 12, and Day 20 have each flagged in different contexts
throughout this series. For a learning project, the video's
Service-Principal-with-stored-secret approach is fine to understand
and practice; for anything you'd actually run in production, OIDC
dynamic credentials are the stronger current recommendation.

---

## 10. Setting Up Service Principal Authentication Correctly

Using the exact same Service Principal creation steps from Day 3:

**PowerShell — creating (or reusing) a Service Principal, run locally
before configuring the workspace:**
```powershell
az login

$sp = az ad sp create-for-rbac `
  --name "hcp-terraform-day25" `
  --role "Contributor" `
  --scopes "/subscriptions/<your-subscription-id>" | ConvertFrom-Json

Write-Host "Client ID:       $($sp.appId)"
Write-Host "Client Secret:   $($sp.password)"
Write-Host "Tenant ID:       $($sp.tenant)"

$subId = az account show --query "id" -o tsv
Write-Host "Subscription ID: $subId"
```

**In the HCP Terraform workspace's Variables page, add four
Environment-category variables** (per Section 7's rule — all four go
in the Environment category, none in the Terraform category):

- `ARM_CLIENT_ID` = the `appId` value
- `ARM_CLIENT_SECRET` = the `password` value, marked **Sensitive**
- `ARM_TENANT_ID` = the `tenant` value
- `ARM_SUBSCRIPTION_ID` = your subscription ID

With all four correctly categorized as Environment variables, a
triggered run authenticates successfully — this is the actual fix
underlying the video's repeated trial and error, stated as a single
clear rule rather than a sequence of failed attempts.

---

## 11. Triggering and Reviewing a Run

Once authentication succeeds, a triggered run shows a **plan**
summarizing exactly what will change — in the video's example, "2 to
create" (a Resource Group and a Storage Account), with full detail on
each resource's attributes available by expanding it.

If **Auto-apply** was left unchecked (Section 6), the run pauses here,
waiting for a human to explicitly click **Confirm & Apply** or
**Discard Run**. This manual gate is directly analogous to the
`terraform apply` confirmation prompt you've seen locally throughout
this series (absent only when `--auto-approve` is used) — HCP
Terraform simply moves that same confirmation into the web UI instead
of your terminal.

---

## 12. Parameterizing With a Terraform-Category Variable

Adding a `variable` block to your configuration:

```hcl
variable "storage_account_name" {
  type = string
}

resource "azurerm_storage_account" "example" {
  name = var.storage_account_name
  # ...
}
```

...requires a corresponding **Terraform**-category workspace variable
(not Environment) supplying the actual value:

- Category: **Terraform variable**
- Key: `storage_account_name`
- Value: a name meeting Day 3's/Day 18's storage account naming rules
  (lowercase letters and numbers only, 3-24 characters) — the video
  hits exactly this familiar validation error on the first attempt,
  the same recurring naming constraint this entire series has flagged
  repeatedly

This is the HCP Terraform equivalent of a local `terraform.tfvars`
file or a `-var` flag — the value lives in the workspace's variable
store instead of a file, but the underlying mechanism (populating a
declared `variable` block) is identical to everything Day 5 already
covered.

---

## 13. The CLI-Driven Workflow

For this workflow, you keep running `terraform` commands from your own
machine, but the actual execution happens remotely on HCP Terraform's
infrastructure, with output streamed back to your terminal.

**PowerShell — starting from an existing local project folder:**
```powershell
Set-Location "C:\projects\day25"
```

If a `backend.tf` file exists from a prior day's remote-backend setup
(Day 4), it needs to be removed or renamed first — Section 14 explains
exactly why.

```powershell
Rename-Item -Path ".\backend.tf" -NewName "backend.tf.bak"
```

---

## 14. The `cloud` Block — Correct Syntax

The configuration block HCP Terraform's UI provides for CLI-driven
setup is the `cloud` block, added inside your `terraform { }` block:

```hcl
terraform {
  cloud {
    organization = "your-organization-name"

    workspaces {
      name = "CLI-test"
    }
  }
}
```

This is worth stating precisely rather than describing loosely as
"this block," because it has a hard, easy-to-miss constraint: **a
`cloud` block and a `backend` block (like the `azurerm` remote backend
from Day 4) cannot coexist in the same configuration.** They both
configure where Terraform's state and execution are managed, and
Terraform requires exactly one such configuration, not both
simultaneously. This is precisely why renaming the old `backend.tf`
file (Section 13) was a necessary step in the video, not an
arbitrary cleanup action — with both present, `terraform init` fails
outright with a conflicting-backend-configuration error.

---

## 15. `terraform login` — What It Does, and Where Credentials Land on Windows

```powershell
terraform login
```

This opens a browser window for you to generate and authorize an API
token, which the CLI then stores locally so subsequent commands can
authenticate to HCP Terraform automatically. On Windows, this token is
written to:

```
$env:APPDATA\terraform.d\credentials.tfrc.json
```

Worth being aware this file contains a live API token with access to
whatever your account can reach in HCP Terraform — treat it with the
same care as any other credential file covered throughout this series
(Day 4, Day 20, Day 22): never commit it to a repository, and be
mindful of who has access to the machine it's stored on.

---

## 16. Running a Plan via the CLI-Driven Workflow

```powershell
terraform init
```
With a valid `cloud` block and no conflicting `backend` block, this
now reports initializing "HCP Terraform" rather than the local/remote
backend messaging you've seen in every prior day of this series.

```powershell
terraform plan
```
The plan **executes remotely** on HCP Terraform's infrastructure —
not on your local machine — while streaming output to your terminal
in real time, and simultaneously appearing in that workspace's Runs
tab in the web UI, exactly as the video demonstrates. This dual
visibility (local terminal streaming + centralized web history) is
the specific practical benefit of the CLI-driven workflow over pure
local execution: you get the familiar terminal experience while
retaining all of HCP Terraform's centralized state, variable, and
audit-history management.

Authentication for this workflow requires the same four
Environment-category `ARM_*` variables (Section 10) configured on
*this* workspace specifically — workspace variables are scoped
per-workspace, not shared automatically across workspaces within the
same organization, which is exactly why the video has to re-enter
those four values again for the second, CLI-driven workspace.

---

## 17. A Pricing Reality Check

Worth stating plainly since it's a genuine practical consideration:
HCP Terraform offers a free tier suitable for exactly the kind of
individual learning and small-project usage this video demonstrates,
with limits on the number of managed resources and users. Paid tiers
unlock team-oriented features — Single Sign-On, Sentinel policy
enforcement (Section 18), higher resource limits, and additional
governance controls. Nothing in this guide requires a paid tier to
follow along, but it's worth checking HCP Terraform's current pricing
page before assuming everything scales for free as your usage grows
beyond a learning project.

---

## 18. Sentinel — A Brief Cross-Reference to Day 21

Not covered in the source video, but worth a short mention given its
direct relevance: HCP Terraform's paid tiers include **Sentinel** (and
more recently, OPA/Rego support), a Terraform-native policy-as-code
engine that can block a plan or apply from proceeding if it violates
an organization-defined rule — evaluated *before* `terraform apply`
runs, directly against the plan itself.

This is conceptually adjacent to, but architecturally distinct from,
**Day 21's Azure Policy**: Azure Policy enforces at the Azure Resource
Manager level regardless of which tool created the request (Terraform,
Portal, CLI, or anything else); Sentinel enforces specifically within
the HCP Terraform run pipeline, before a request is ever sent to
Azure at all. A mature governance setup can reasonably use both —
Sentinel catching policy violations early in the Terraform workflow
itself, Azure Policy as the platform-level backstop catching anything
that reaches Azure through any other path.

---

## 19. The Assignment — Multi-Environment, Branch-Triggered Workspaces

The video's explicit homework: build separate workspaces for Dev,
Test, and Prod environments, each triggered by commits to a
corresponding branch (e.g., a `dev` branch triggering the Dev
workspace's workflow, matching Section 6's branch-based trigger
configuration).

A practical sketch of the setup:

1. Create three workspaces under the same project: `myapp-dev`,
   `myapp-test`, `myapp-prod`
2. Configure each with the Version Control workflow, pointing at the
   same repository but a different trigger branch (`dev`, `test`,
   `main` respectively)
3. Set environment-specific Terraform-category variables per
   workspace (different resource name prefixes, different SKUs/sizes)
4. Set the same four `ARM_*` Environment-category variables on each
   workspace (or, if using a single Service Principal across all
   three, scoped with resource-group-level role assignments per
   environment following Day 20's least-privilege guidance, rather
   than one broadly-scoped Service Principal shared identically across dev/test/prod)
5. Push to the `dev` branch, confirm only the `myapp-dev` workspace
   triggers a run, not the others

This is a genuinely common real-world pattern and a fair interview
topic, exactly as the video notes — worth actually building rather
than only reading about.

---

## 20. Complete Reference Configuration

**`main.tf`** (VCS-driven workspace)
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

variable "storage_account_name" {
  type        = string
  description = "Globally unique, lowercase, 3-24 characters"
}

resource "azurerm_resource_group" "example" {
  name     = "example-resources"
  location = "West Europe"
}

resource "azurerm_storage_account" "example" {
  name                     = var.storage_account_name
  resource_group_name     = azurerm_resource_group.example.name
  location                = azurerm_resource_group.example.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}
```

**`main.tf`** (CLI-driven workspace — adds the `cloud` block, no
`backend` block present anywhere in this configuration)
```hcl
terraform {
  required_version = ">= 1.9.0"

  cloud {
    organization = "tech-tutorials-with-p"

    workspaces {
      name = "CLI-test"
    }
  }

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

**Workspace variables (both workspaces), correctly categorized:**

Environment variables (never Terraform variables):
`ARM_CLIENT_ID`, `ARM_CLIENT_SECRET` (Sensitive), `ARM_TENANT_ID`,
`ARM_SUBSCRIPTION_ID`

Terraform variables (VCS-driven workspace only, matching the
`variable` block above):
`storage_account_name`

---

## 21. Common Mistakes

**Mistake 1 — Categorizing `ARM_*` values as Terraform variables
instead of Environment variables.** Section 7's rule resolves this
definitively: if the AzureRM provider reads it via `os.Getenv`, it's
an Environment variable, full stop.

**Mistake 2 — Trying to get interactive `az login` working inside a
remote run.** Section 8 — architecturally impossible in a headless
execution environment; Service Principal (or OIDC dynamic
credentials) is required, not optional.

**Mistake 3 — Leaving both a `backend` block and a `cloud` block in
the same configuration.** They're mutually exclusive — Section 14.

**Mistake 4 — Assuming workspace variables are shared automatically
across workspaces.** They're scoped per-workspace; the same four
`ARM_*` values must be re-entered for each new workspace that needs them.

**Mistake 5 — Referring to the product as "SCP Terraform."** It's
**HCP Terraform** (part of the HashiCorp Cloud Platform umbrella,
formerly branded Terraform Cloud) — Section 1.

---

## 22. Practice Exercises

**Exercise 1** — A workspace variable named `ARM_CLIENT_SECRET` is
added under the "Terraform variable" category, marked Sensitive. The
subsequent run still fails with a subscription/authentication error.
Explain why, using Section 7's rule.

*Answer:* The AzureRM provider reads `ARM_CLIENT_SECRET` from the OS
environment directly, not from Terraform's variable system. A
Terraform-category variable never becomes an OS environment variable
in the run's execution context — it only populates a declared
`variable { }` block, which doesn't exist for provider authentication
values. The variable must be re-added under the "Environment
variable" category instead.

**Exercise 2** — Explain, using an architectural rather than a
policy-based reason, why `az login`'s standard interactive flow cannot
succeed inside an HCP Terraform remote run.

*Answer:* `az login`'s standard flow requires a browser to complete an
interactive or device-code authorization step. HCP Terraform's remote
execution environment is headless and non-interactive — there is no
browser and no human present during the run to complete that step, so
no configuration can make it succeed; a non-interactive authentication
method (Service Principal or OIDC dynamic credentials) is required instead.

**Exercise 3** — A team member's `terraform init` fails with a message
about conflicting backend configuration after they add a `cloud`
block to try HCP Terraform's CLI-driven workflow. What's the most
likely cause?

*Answer:* Their configuration still contains a `backend` block (for
example, the `azurerm` remote backend from Day 4) alongside the newly
added `cloud` block. These two are mutually exclusive — the old
`backend` block (or file containing it) needs to be removed or
renamed before `terraform init` will succeed with the `cloud` block
present.

---

## 23. Summary Reference

The product is **HCP Terraform** (formerly Terraform Cloud, part of
the broader HashiCorp Cloud Platform) — not "SCP Terraform."

Hierarchy: Organization → Project → Workspace, where a workspace maps
to what a CLI-only user would think of as one Terraform folder with
its own state, variables, and credentials.

Three workflows: Version Control (Git-triggered), CLI-driven (local
commands, remote execution), API-driven.

The single most important rule for Azure authentication in HCP
Terraform: `ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`, `ARM_TENANT_ID`, and
`ARM_SUBSCRIPTION_ID` must always be Environment-category variables,
never Terraform-category — because the AzureRM provider reads them
from the OS environment, bypassing Terraform's own variable system entirely.

Interactive `az login` cannot function inside HCP Terraform's headless
remote execution environment under any configuration — Service
Principal credentials, or the more modern OIDC dynamic credentials
approach, are architecturally required, not merely preferred.

A `cloud` block and a `backend` block cannot coexist in the same
Terraform configuration.

---

*Guide covers: HCP Terraform (correcting the naming confusion with
"SCP Terraform" and clarifying its relationship to the broader
HashiCorp Cloud Platform and its former Terraform Cloud branding), the
organization/project/workspace hierarchy, the three HCP Terraform
workflow types (Version Control, CLI-driven, API-driven), VCS-driven
workspace setup including auto-apply and branch/tag trigger
configuration, the critical and precisely defined distinction between
Terraform-category and Environment-category workspace variables, why
ARM_CLIENT_ID/ARM_CLIENT_SECRET/ARM_TENANT_ID/ARM_SUBSCRIPTION_ID must
always be Environment variables, the architectural impossibility of
interactive az login inside a headless remote execution environment,
OIDC dynamic credentials as a more modern secret-free alternative to
stored Service Principal secrets, run review and the Confirm & Apply
versus Discard Run gate, storage account naming validation recurring
from Day 3/18/22, the CLI-driven workflow setup, the cloud block's
correct syntax and its mutual exclusivity with a backend block,
terraform login and the Windows credentials.tfrc.json file location,
remote plan execution with local terminal streaming, HCP Terraform's
free tier and paid-tier features, Sentinel policy-as-code as a
cross-reference to Day 21's Azure Policy, and a practical sketch of
the multi-environment branch-triggered workspace assignment.*
