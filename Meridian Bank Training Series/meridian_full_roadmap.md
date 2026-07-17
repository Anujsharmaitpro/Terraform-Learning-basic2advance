# Meridian Bank — Cloud Infrastructure Training Series
## Full Roadmap (Revised) | Budget: $5-10/month
**Track:** Cloud Infrastructure Engineer (Trainee) | **Cloud:** Azure | **Tool:** Terraform

---

## What Changed From the Original Plan

```
Original constraint   →  Near-zero cost, destroy same session, avoid anything with fixed hourly charges
Revised constraint    →  $5-10/month buffer, can run labs for a few hours or a weekend, still destroy when done
```

This unlocks:
- Application Gateway (previously flagged as too costly)
- Standard SKU Load Balancer
- Occasional longer-running multi-day labs
- Slightly better VM/App Service tiers where the lesson needs it

This does NOT unlock:
- Leaving things running indefinitely
- Premium/Enterprise SKUs (still no reason to use them for learning)
- Skipping the cost check before every apply

---

## Design Philosophy for This Series

Three things you asked for, all reflected in the structure below:

1. **Azure AD topics included** — App Registration, Managed Identity, RBAC.
   These are used in almost every org, tech or non-tech.

2. **Resource frequency labelled honestly** — every project marks whether
   the resource is used everywhere, common in most orgs, or niche to a
   specific org type. Not every Azure service belongs on your core skill list.

3. **Multi-tier app design as the throughline** — starting around MRB-006,
   projects stop being single-resource exercises and start being architecture
   exercises: Web tier → App tier → Data tier, properly separated and secured.

---

## Full Roadmap

| # | Project | Focus | Frequency | Est. Cost |
|---|---|---|---|---|
| 1 | MRB-INFRA-001 | Secure Storage + Compliance Baseline | Everywhere | ~$0.00 | ✅ Done |
| 2 | MRB-INFRA-002 | Azure AD + Managed Identity | Everywhere | ~$0.00 |
| 3 | MRB-INFRA-003 | Key Vault + RBAC (no legacy access policies) | Everywhere | ~$0.00 |
| 4 | MRB-INFRA-004 | Private Networking + Standard Load Balancer | Everywhere | ~$0.05/hr |
| 5 | MRB-INFRA-005 | Traffic Manager + Routing Concepts | Everywhere | ~$0.01 |
| 6 | MRB-INFRA-006 | Multi-Tier Design Part 1 — Web + App Tier | Everywhere | ~$0.02/hr |
| 7 | MRB-INFRA-007 | Multi-Tier Design Part 2 — Add Data Tier | Common | ~$0.03/hr |
| 8 | MRB-INFRA-008 | Application Gateway ⚠️ | Common (enterprise) | ~$0.36/hr |
| 9 | MRB-INFRA-009 | Multi-Tier Capstone — Full Stack Behind App Gateway | Common | ~$0.40/hr |
| 10 | MRB-INFRA-010 | Cosmos DB or Service Bus (your choice at the time) | Niche | ~$0.00 (serverless) |

---

## Project Breakdown

---

### ✅ MRB-INFRA-001 — Secure Storage + Compliance Baseline
**Status:** Completed
**Frequency:** Used in every org, every industry.

Storage Account with versioning, soft delete, HTTPS-only, TLS 1.2
minimum, private container access. The compliance-tag pattern
(`DataClassification`, `ComplianceScope`) that carries through
the rest of the series.

---

### 📋 MRB-INFRA-002 — Azure AD + Managed Identity
**Frequency:** Used in nearly every org — this is foundational identity work.
**New Concepts:** App Registration, Service Principal, System-Assigned
Managed Identity, RBAC role assignment.

**Why This Matters:**
Every project so far has used either a password, an SSH key, or a
Key Vault secret to authenticate. Managed Identity removes the need
for credentials entirely — an Azure resource proves its own identity
to Azure AD directly. This is the standard for how real banks and
enterprises connect services securely.

**What You Will Build:**
```
A Linux VM with a System-Assigned Managed Identity
  → granted RBAC role: "Key Vault Secrets User"
  → reads a secret from Key Vault
  → with ZERO credentials anywhere in your Terraform config
```

**Terraform Resources:**
```
azurerm_resource_group
azurerm_key_vault                    (RBAC authorization model, not access policies)
azurerm_key_vault_secret
azurerm_linux_virtual_machine        (identity block — system assigned)
azurerm_role_assignment              (NEW — grants the VM's identity access)
```

**Cost:** VM on `Standard_B1s`, destroy same session. Near zero.

---

### 📋 MRB-INFRA-003 — Key Vault + RBAC (No Legacy Access Policies)
**Frequency:** Used everywhere.
**New Concepts:** RBAC-based Key Vault authorization vs the legacy
access-policy model you used in the NexaCore series.

**Why This Matters:**
In NCT-INFRA-004 (NexaCore series) you used `access_policy` blocks.
That model is being phased out industry-wide in favour of RBAC —
the same permission model used for every other Azure resource.
Meridian Bank mandates RBAC for all new Key Vaults.

**What Changes:**
```hcl
# Old model (NexaCore, NCT-004) — access_policy block inside the vault
resource "azurerm_key_vault" "kv" {
  access_policy { ... }
}

# New model (Meridian, MRB-003) — RBAC authorization + separate role assignment
resource "azurerm_key_vault" "kv" {
  enable_rbac_authorization = true
}

resource "azurerm_role_assignment" "kv_access" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id          = data.azurerm_client_config.current.object_id
}
```

**Cost:** Near zero.

---

### 📋 MRB-INFRA-004 — Private Networking + Standard Load Balancer
**Frequency:** Used everywhere.
**New Concepts:** Standard SKU Load Balancer, backend pools, health probes,
load balancing rules.

**Why This Matters:**
A Load Balancer distributes traffic across multiple VMs or App
Services so no single instance is a point of failure. This is
one of the most universally used networking components — startup,
bank, retailer, everyone uses this pattern.

**What You Will Build:**
```
Two Linux VMs (backend pool)
  ← Standard Load Balancer
      ← Health probe checking VM availability
      ← Load balancing rule distributing HTTP traffic
```

**Cost:** Standard LB has a small hourly charge (~$0.025/hr) plus
data processing. For a few hours of lab time: well under $1.

---

### 📋 MRB-INFRA-005 — Traffic Manager + Routing Concepts
**Frequency:** Used everywhere with multi-region needs.
**New Concepts:** DNS-based traffic routing, routing methods
(priority, weighted, performance).

**Why This Matters:**
Load Balancer works within one region. Traffic Manager works
ACROSS regions — routing users to the closest or healthiest
region. You will simulate this concept using two endpoints
(does not require actually deploying to two Azure regions).

**Cost:** Pay per DNS query. For lab-scale testing: fractions of a cent.

---

### 📋 MRB-INFRA-006 — Multi-Tier Design Part 1: Web + App Tier
**Frequency:** Universal architecture pattern.
**New Concepts:** None — this is your first pure architecture/integration
project. Every resource type is one you already know. The lesson is
how to separate concerns correctly.

**Why This Matters:**
This is where the series shifts from "learn a resource" to
"design a system." A proper multi-tier app has:
```
Web Tier   → public facing, minimal logic, talks only to App Tier
App Tier   → business logic, NOT publicly accessible, talks to Data Tier
Data Tier  → database, NOT publicly accessible, only App Tier can reach it
```

**What You Will Build (Part 1 — two tiers):**
```
┌─────────────────────────────────────────────┐
│  Web Tier — App Service (public)             │
│  Subnet: web-subnet (10.0.1.0/24)            │
└───────────────────┬───────────────────────────┘
                    │ VNet-integrated, private call only
                    ▼
┌─────────────────────────────────────────────┐
│  App Tier — App Service (NOT public)         │
│  Subnet: app-subnet (10.0.2.0/24)            │
│  NSG blocks all inbound except from web-subnet│
└─────────────────────────────────────────────┘
```

**Cost:** Two `F1`/`B1` App Services + VNet integration
(VNet integration requires at least `B1` tier — small monthly cost,
destroy after lab).

---

### 📋 MRB-INFRA-007 — Multi-Tier Design Part 2: Add Data Tier
**Frequency:** Common in most orgs with a database-backed app.

**What You Will Build (extends MRB-006):**
```
Web Tier   → App Service (public)
App Tier   → App Service (private, VNet-integrated)
Data Tier  → Azure SQL with Private Endpoint (NEW — no public access at all)
             Subnet: data-subnet (10.0.3.0/24)
```

**New Concept:** Private Endpoint — instead of a public SQL Server
with firewall rules (what you did in NCT-INFRA-007), the database
has NO public IP at all. It is only reachable from inside the VNet.
This is the bank-grade approach.

**Cost:** SQL Basic tier (~$5/month if left running — destroy after
lab) + Private Endpoint (~$0.01/hr). Still well inside your budget
for a lab session.

---

### 📋 MRB-INFRA-008 — Application Gateway ⚠️ COST WARNING
**Frequency:** Common in enterprise/regulated environments.

> **Read this before starting this project:**
> Application Gateway (Standard_v2) has a fixed cost of roughly
> **$0.36/hour** the moment it exists — even completely idle.
> Left running for a full day: **~$8-9**.
> Left running a full month: **~$260**.
>
> This is the ONE project in this entire series (across both
> NexaCore and Meridian) where the resource itself is genuinely
> expensive. Your $5-10/month budget covers a few hours of lab
> time — not a multi-day session.
>
> **Plan to:** apply, verify, take notes/screenshots, destroy —
> all in a single 1-2 hour sitting.

**What You Will Build:**
```
Application Gateway (public entry point)
  → Path-based routing rules
  → Web Application Firewall (WAF) — basic detection mode
  → Routes to your Web Tier App Service from MRB-006
```

**Why This Matters Despite the Cost:**
App Gateway is a Layer 7 (application-aware) load balancer —
it can route based on URL path, inspect for common web attacks
(WAF), and terminate SSL. This is standard front door
infrastructure at any company handling real customer traffic.
Worth the one-time cost of a short lab to understand it properly.

---

### 📋 MRB-INFRA-009 — Multi-Tier Capstone: Full Stack Behind App Gateway
**Frequency:** This exact combination is common in regulated industries.

Brings together MRB-006, 007, and 008 into one complete,
realistic architecture:

```
Internet
   │
   ▼
Application Gateway (WAF enabled)
   │
   ▼
Web Tier — App Service (public subnet)
   │
   ▼
App Tier — App Service (private subnet, VNet-integrated)
   │
   ▼
Data Tier — Azure SQL (private endpoint, no public access)
```

Every tier secured. Every tag compliant. This is your portfolio
piece for the Meridian series — the equivalent of NCT-INFRA-010
in the NexaCore series, but bank-grade from the ground up.

**Cost:** Same App Gateway warning as MRB-008 applies — single
tight session, destroy immediately after.

---

### 📋 MRB-INFRA-010 — Your Choice: Cosmos DB or Service Bus
**Frequency:** Niche — common in specific architectures (event-driven
systems, globally distributed apps) but not universal.

This is presented honestly as optional/niche exposure rather than
a "must learn" project. Pick based on interest:

**Option A — Cosmos DB (Serverless):**
NoSQL database, pay-per-request, near-zero cost at low volume.
Common in retail/e-commerce and global-scale apps.

**Option B — Service Bus (Basic tier):**
Enterprise message queue — more robust than the Storage Queue
you used in NCT-INFRA-008. Common in finance and enterprise
integration scenarios (which fits the Meridian Bank theme well).

We will decide together when you reach this point.

---

## Resource Frequency Legend — Your Honest Skill Map

```
"Everywhere"           → Learn this regardless of what company you join
                         Resource Group, Storage, Key Vault, Networking,
                         Load Balancer, Managed Identity, RBAC

"Common"                → Very likely to appear in mid-to-large orgs
                         SQL + Private Endpoints, App Gateway,
                         Traffic Manager

"Niche"                 → Depends heavily on the org's architecture
                         Cosmos DB, Service Bus, Container Registry,
                         Function Apps (from the NexaCore series)
```

This distinction matters for job interviews — when someone asks
"what Azure services have you worked with," lead with the
"Everywhere" list. It signals foundational competence.
The "Niche" list is a bonus, not the headline.

---

## Cost Summary Across the Whole Series

```
MRB-001 to MRB-005    →  Each project: under $0.10 for a full lab session
MRB-006, MRB-007      →  Each project: $0.20-0.50 if run for a few hours
MRB-008, MRB-009      →  Each project: $1-3 for a tight single session
MRB-010               →  Under $0.10 (serverless tiers)
─────────────────────────────────────────────────────────────────────
Full series total     →  Well under your $5-10/month budget,
                         even if you run every project once
                         and occasionally forget to destroy same-day
```

**One habit to build now:** set up a simple Azure Cost Alert at
$5/month while you go through this series. Real teams do this too —
it is not a beginner-only safety net.

```powershell
# Optional: set a basic budget alert (one-time setup)
az consumption budget create `
  --budget-name "learning-budget" `
  --amount 10 `
  --time-grain Monthly `
  --category Cost `
  --start-date 2026-07-01 `
  --end-date 2027-07-01
```

---

*Meridian Bank — Cloud Platform Engineering | Internal Training Material*
*Full Series Roadmap | Revised Budget: $5-10/month*
*CONFIDENTIAL — Internal Use Only*
