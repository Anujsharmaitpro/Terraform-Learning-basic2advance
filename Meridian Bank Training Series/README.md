# Meridian Bank — Cloud Infrastructure Training Series

A 10-project Terraform + Azure learning series simulating a
mid-size private bank's cloud infrastructure team. Each project
is a self-contained ticket — provision it, verify it, destroy it —
building from foundational compliance concepts up to a complete
bank-grade, multi-tier application architecture.

This series is the second in a two-part learning path. It assumes
familiarity with core Terraform (resources, variables, outputs,
`for_each`) from the companion **NexaCore Technologies** series,
and focuses specifically on security, identity, and compliance
patterns common in regulated industries.

---

## Who This Is For

Built while learning Terraform from scratch, entirely self-funded.
Every project in this series was deliberately designed around
three constraints:

- **No project depends on another being alive.** Every ticket is
  fully standalone — clone any single folder, `terraform apply`,
  verify, `terraform destroy`. Nothing requires a prior project's
  infrastructure to still be running.
- **Real money, real budget.** Every project includes an honest
  cost estimate before you apply anything. The series is designed
  to run comfortably within a $5-10/month personal budget,
  including two intentionally more expensive networking projects
  that are clearly flagged.
- **Resource frequency is labelled honestly.** Every project notes
  whether the Azure services it covers are used in nearly every
  org, common in specific org types, or niche — so time is spent
  learning what actually transfers to a job, not just what's
  interesting.

---

## Prerequisites

```
Terraform CLI    v1.6+
Azure CLI        v2.50+
An Azure account (Free Tier or pay-as-you-go)
PowerShell       (all commands in this series are written for
                  Windows + VS Code + PowerShell)
```

```powershell
az login
az account show --output table
terraform version
```

---

## The Meridian Bank Naming Standard

Every project in this series follows one consistent pattern,
established in MRB-001:

```
Resource naming: {org}-{env}-{workload}-{resource-type}
  org      = mrb
  env      = dev / stg / prod
  workload = short description
  type     = rg / kv / vm / vnet / sql / agw / etc.
```

**Mandatory tags on every resource** (8 tags — stricter than
typical beginner tutorials, modeling real compliance requirements):

| Tag | Purpose |
|---|---|
| `Project` | Ticket code (e.g. `MRB-INFRA-001`) |
| `Environment` | `dev` / `stg` / `prod` |
| `Owner` | Responsible engineer |
| `ManagedBy` | Always `terraform` |
| `CostCentre` | Billing code |
| `Team` | Owning team |
| `DataClassification` | `public` / `internal` / `confidential` / `restricted` |
| `ComplianceScope` | `none` / `internal-audit` / `pci-dss` / `gdpr` |

---

## Project Index

| # | Project | Focus | Frequency | Est. Cost |
|---|---|---|---|---|
| 01 | [MRB-INFRA-001](./MRB-INFRA-001) | Secure Storage + Compliance Baseline | Everywhere | ~$0.00 |
| 02 | [MRB-INFRA-002](./MRB-INFRA-002) | Azure AD + Managed Identity (VM) | Everywhere | ~$0.05 |
| 03 | [MRB-INFRA-003](./MRB-INFRA-003) | Managed Identity (App Service) + Key Vault References | Everywhere | ~$0.02 |
| 04 | [MRB-INFRA-004](./MRB-INFRA-004) | Private Networking + Standard Load Balancer | Everywhere | ~$0.50/session |
| 05 | [MRB-INFRA-005](./MRB-INFRA-005) | Traffic Manager + Routing Concepts | Everywhere | ~$0.01 |
| 06 | [MRB-INFRA-006](./MRB-INFRA-006) | Multi-Tier Design Part 1 — Web + App Tier, VNet Integration | Everywhere | ~$0.10/session |
| 07 | [MRB-INFRA-007](./MRB-INFRA-007) | Multi-Tier Design Part 2 — Data Tier via Private Endpoint | Common | ~$1.00/session |
| 08 | [MRB-INFRA-008](./MRB-INFRA-008) | Azure Policy — Automated Compliance Enforcement | Common (regulated orgs) | Free |
| 09 | [MRB-INFRA-009](./MRB-INFRA-009) | Application Gateway + WAF ⚠️ | Common (enterprise) | ~$0.36/hr — see warning |
| 10 | [MRB-INFRA-010](./MRB-INFRA-010) | Full Capstone — Complete Bank-Grade Architecture ⚠️ | Common | ~$0.40/hr — see warning |

> ⚠️ **MRB-009 and MRB-010 include an Application Gateway**, the
> one resource in this entire series with a genuine fixed hourly
> cost (~$0.36/hr) even while idle. Both projects are designed for
> a single 1-3 hour focused session: apply → verify → destroy
> immediately. See each project's README for full detail.

---

## What Each Project Teaches

**MRB-001 — Secure Storage:** versioning, soft delete, TLS 1.2
enforcement, private-only blob access. The compliance-tag pattern
used throughout the rest of the series.

**MRB-002 / MRB-003 — Managed Identity:** the single biggest
mindset shift in this series. Instead of storing a password in
Key Vault and reading it, an Azure resource becomes its own Azure
AD identity and proves itself directly — zero credentials in
Terraform state. Demonstrated first on a VM, then generalized to
App Service using native Key Vault references in `app_settings`.

**MRB-004 / MRB-005 — Traffic Distribution:** Load Balancer
(Layer 4, traffic physically flows through it) versus Traffic
Manager (DNS-level routing, traffic never passes through it) —
two genuinely different mechanisms for the same broad goal.

**MRB-006 / MRB-007 — Multi-Tier Architecture:** the series shifts
from "learn a resource" to "design a system." Web Tier (public) →
App Tier (VNet-integrated, zero public access) → Data Tier (Azure
SQL reachable only via Private Endpoint, no firewall rules at
all, since no public entry point exists to filter).

**MRB-008 — Azure Policy:** compliance stops being a manually
followed checklist and becomes something Azure itself enforces —
a resource missing a required tag is rejected at creation time,
regardless of who or what is creating it.

**MRB-009 — Application Gateway:** Layer 7 (application-aware)
routing and WAF-based attack detection, in front of a real
backend. The one deliberately costly lesson in the series.

**MRB-010 — Capstone:** every pattern above, assembled into one
complete architecture. No new Terraform concepts — pure synthesis
and correctness under complexity.

---

## Repository Structure

```
Meridian Bank Training Series/
├── MRB-INFRA-001/
│   ├── providers.tf
│   ├── backend.tf
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars.example
│   ├── .gitignore
│   └── README.md
├── MRB-INFRA-002/
│   └── ...
├── ...
└── MRB-INFRA-010/
    └── ...
```

Each project folder is fully self-contained and independently
runnable. `terraform.tfvars` (with real values) is never
committed — only a `.example` version showing the expected
structure.

---

## Standard Workflow — Every Project

```powershell
cd MRB-INFRA-00X

terraform init
terraform fmt -check -recursive
terraform validate
terraform plan -out=tfplan
terraform show tfplan          # review before applying
terraform apply tfplan

# ... verify via Azure CLI / terraform output, per that project's README ...

terraform destroy              # always, every time, no exceptions
```

---

## Companion Series

This is the second of two learning series built while going
through Terraform fundamentals:

- **NexaCore Technologies** — 10 projects covering core Terraform
  mechanics: modules, remote state, `for_each`, `dynamic` blocks,
  Key Vault, App Service, Function Apps, SQL, and monitoring.
- **Meridian Bank** *(this series)* — applies those fundamentals
  to a stricter, compliance-driven, identity-first architecture
  pattern common in regulated industries.

---

## A Note on Cost Discipline

Every project's cost estimate assumes a focused lab session
followed by prompt `terraform destroy`. Nothing in this series is
designed to run continuously. If you're following along on your
own budget, treat "destroy when done" as the actual last step of
every project — not an optional cleanup task.

---

*Built while learning Terraform from the ground up — no prior
DevOps background, self-funded, one project at a time.*
