# Apex Industries — Cloud Infrastructure Training Series

A 15-project Terraform + Azure learning series simulating a
generic, industry-agnostic corporate IT department. Where the
companion Meridian Bank series focused on compliance and
identity-first security, this series prioritizes **breadth** —
the specific Azure resources and mechanics that show up across
almost any org, regardless of what the company actually does.

This is the third series in a three-part learning path, built
directly on core Terraform fundamentals (NexaCore Technologies)
and security-first architecture patterns (Meridian Bank).

---

## Who This Is For

Built while learning Terraform from scratch, entirely self-funded.
Every project follows the same standing rules established across
the full learning journey:

- **No project depends on another being alive.** Every ticket is
  fully self-contained — clone any single folder, `terraform
  apply`, verify, `terraform destroy`.
- **Real money, real budget.** Every project shows an honest cost
  estimate before anything gets applied. Designed to run
  comfortably within a $5-10/month personal budget.
- **Every resource type is genuinely used somewhere real, common
  across most orgs.** Where a project revisits a pattern from
  NexaCore or Meridian, it's tagged explicitly so the reuse is
  visible, not accidental repetition.
- **Every project ends in something testable.** A real URL, a
  real image, a real recovery point — not just a CLI command
  confirming a resource exists.

---

## Prerequisites

```
Terraform CLI    v1.6+
Azure CLI        v2.50+
An Azure account (Free Tier or pay-as-you-go)
PowerShell       (all commands written for Windows + VS Code + PowerShell)
Python 3.11+     (for projects that deploy real application code)
```

```powershell
az login
az account show --output table
terraform version
```

---

## Project Index

| # | Project | Focus | Frequency | Est. Cost | Status |
|---|---|---|---|---|---|
| 01 | APX-INFRA-001 | Azure AD Fundamentals — Users, Groups, App Registrations | Everywhere | Free | Done |
| 02 | APX-INFRA-002 | Dynamic Group Membership | Everywhere | Free | Done |
| 03 | APX-INFRA-003 | Storage + Lifecycle Policy + First AD-to-Resource RBAC Bridge | Everywhere | ~$0.00 | Done |
| 04 | APX-INFRA-004 | VNet Peering — Two Networks, Genuinely Connected | Everywhere | ~$0.15 | Done |
| 05 | APX-INFRA-005 | VM Scale Set (VMSS) Basics | Everywhere | ~$0.15 | Done |
| 06 | APX-INFRA-006 | Load Balancer + VMSS Together | Everywhere | ~$0.50 | Done |
| 07 | APX-INFRA-007 | Multi-Tier Lab 1 — Web + App Tier | Everywhere | ~$0.15 | Done |
| 08 | APX-INFRA-008 | Multi-Tier Lab 2 — Data Tier via Private Endpoint | Common | ~$1.00 | Done |
| 09 | APX-INFRA-009 | Traffic Manager + Real QR Code Generator App | Common | ~$0.01 | Done |
| 10 | APX-INFRA-010 | Backup & Disaster Recovery — Recovery Services Vault | Everywhere | ~$0.10 | Done |
| 11 | APX-INFRA-011 | Azure Files + NAT Gateway | Everywhere | ~$0.10 | Planned |
| 12 | APX-INFRA-012 | VMSS Autoscale | Everywhere | ~$0.15 | Planned |
| 13 | APX-INFRA-013 | Governance Trio — Resource Locks, Cost Budgets, Policy | Everywhere | Free | Planned |
| 14 | APX-INFRA-014 | Terraform Workspaces | Everywhere | ~$0.00 | Planned |
| 15 | APX-INFRA-015 | CI/CD for Terraform (GitHub Actions) | Everywhere | Free | Planned |

---

## What Each Project Teaches

**APX-001 / 002 — Azure AD Fundamentals & Dynamic Groups:** the
`azuread` provider, genuinely separate from `azurerm` — managing
identity objects (users, groups, app registrations) rather than
billable resources. Dynamic group membership introduces rule-based
auto-population instead of manually maintained lists.

**APX-003 — Storage + Lifecycle Policy:** the first project
connecting the `azuread` and `azurerm` worlds — an Azure AD group
granted an RBAC role on a storage account, proving identity
objects and resources genuinely interoperate.

**APX-004 — VNet Peering:** two isolated networks connected
directly over Azure's private backbone. The core lesson: peering
is two one-way connections, not one — miss either direction and
traffic only flows one way.

**APX-005 / 006 — VMSS + Load Balancer:** the shift from managing
individual VMs to managing a self-healing pool of identical
instances, then distributing traffic across that pool.

**APX-007 / 008 — Multi-Tier Architecture:** Web Tier (public) →
App Tier (private) → Data Tier (Azure SQL, Private Endpoint only).
Includes a corrected App Service networking pattern: VNet
Integration (outbound) and Private Endpoint (inbound) are two
separate mechanisms that must both be present for genuine
App-to-App privacy — a common architectural mistake, fixed
explicitly in this series.

**APX-009 — Traffic Manager:** DNS-level failover routing, fronting
a real, working QR code generator app — not a JSON placeholder.

**APX-010 — Backup & Disaster Recovery:** Recovery Services Vault,
backup policy, and protected VM — the three-resource relationship
behind "what happens if this VM gets deleted," one of the most
universally required skills in cloud infrastructure regardless of
industry.

**APX-011 — Azure Files + NAT Gateway:** SMB file shares (the
cloud equivalent of a shared network drive) and controlled
outbound internet access — two of the most common "every org has
this somewhere" resource types.

**APX-012 — VMSS Autoscale:** extends APX-005/006's Scale Set with
real metric-driven scaling rules — the mechanism behind how most
production compute actually responds to load.

**APX-013 — Governance Trio:** Resource Locks (preventing
accidental deletion), Cost Budgets (spend alerts), and a return to
Azure Policy — the day-one governance controls almost every org
puts in place before anything else.

**APX-014 — Terraform Workspaces:** one config, multiple isolated
deployments (dev/stg) without folder duplication — solving the
repetition problem you'll have felt by this point in the series.

**APX-015 — CI/CD for Terraform:** GitHub Actions running plan
on pull request and apply on merge — turning everything built by
hand across this series into an automated pipeline.

---

## A Note on Series Design

The original plan for APX-010 repeated the full multi-tier +
Application Gateway architecture a second time (having already
appeared across MRB-006 through MRB-010, then again in APX-007
through APX-009). That was flagged as excessive repetition and
replaced — Backup & Disaster Recovery, and the genuinely new
resource categories in 011-013, prioritize breadth of exposure
over repeating an already-learned pattern a fourth time.

Repetition still matters — for_each, dynamic, and core mechanics
are deliberately kept in rotation throughout — but resource-type
variety was the higher priority once the architecture pattern had
been proven twice.

---

## Repository Structure

```
Apex Industries Training Series/
  APX-INFRA-001/
    providers.tf
    main.tf
    variables.tf
    outputs.tf
    terraform.tfvars.example
    .gitignore
    README.md
  APX-INFRA-002/
    ...
  ...
  APX-INFRA-015/
    ...
```

Each project folder is fully self-contained and independently
runnable. `terraform.tfvars` (with real values) is never
committed — only a `.example` version.

---

## Standard Workflow — Every Project

```powershell
cd APX-INFRA-00X

terraform init
terraform fmt -check -recursive
terraform validate
terraform plan -out=tfplan
terraform show tfplan
terraform apply tfplan

# ... verify via Azure CLI / terraform output, per that project's README ...

terraform destroy
```

---

## Companion Series

This is the third of three learning series built while going
through Terraform, in order:

- **NexaCore Technologies** — 10 projects, core Terraform
  mechanics: modules, remote state, for_each, dynamic blocks,
  Key Vault, App Service, Function Apps, SQL, monitoring.
- **Meridian Bank** — 10 projects, compliance/identity-first
  security patterns: Managed Identity, RBAC, Private Endpoints,
  Azure Policy, Application Gateway, multi-tier design.
- **Apex Industries** *(this series)* — 15 projects, breadth
  across the resource types most common in general corporate IT,
  with deliberate reuse of NexaCore and Meridian resources applied
  in new combinations rather than introduced fresh each time.

---

## Cost Discipline

Every project's cost estimate assumes a focused lab session
followed by prompt terraform destroy. The Application Gateway
projects (Meridian's capstone work) carry a genuine hourly cost
and are flagged accordingly in their individual READMEs —
everything in the Apex series specifically stays well under $1
per session.

---

*Built while learning Terraform from the ground up — no prior
DevOps background, self-funded, one project at a time.*
