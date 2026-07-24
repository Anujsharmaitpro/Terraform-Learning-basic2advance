# Apex Industries — Full Project List (Updated)
## Reflecting All Requirements Gathered So Far
## Now Also Weaving In Meridian Bank Resources + Repeated Terraform Mechanics

---

## Standing Rules This List Follows

```
✓ Every project fully self-contained — no cross-project dependency
✓ $5-10/month budget — cost shown before every apply
✓ Micro-SKU enforcement — smallest SKU always, unless the lesson
  genuinely requires a step up
✓ Azure AD topics included throughout, not front-loaded and dropped
✓ Resource frequency labelled — Everywhere / Common / Niche
✓ Pacing kept at Beginner+++ — one genuinely new concept per
  project, previously covered resources reused in NEW combinations
  rather than every project introducing something from scratch
✓ Ends in something testable — a real URL, page, or output you
  can open and interact with, not just CLI existence checks
✓ VMSS, Load Balancer, and Multi-Tier design explicitly included
  (per your direct request)
```

---

## Full List — Three Threads Tracked Per Project

Every project now explicitly tracks THREE kinds of repetition, not
just new Azure services:

```
Thread 1: NEW CONCEPT           → the one genuinely new thing
Thread 2: RESOURCE REUSE         → tagged [NCT] NexaCore or [MRB] Meridian,
                                     showing exactly which prior series
                                     this resource first appeared in
Thread 3: MECHANIC REPETITION    → for_each, dynamic, or a specific
                                     function (format/jsonencode/keys/
                                     merge/file/toset), deliberately
                                     reused so it never goes stale
```

| # | Project | New Concept | Resource Reuse (Source Series) | Mechanic Repeated | Testable Output | Cost |
|---|---|---|---|---|---|---|
| 001 | Azure AD Fundamentals | `azuread_user/group/application` | — (first project) | — (baseline) | `az ad` CLI confirms objects | Free |
| 002 | Dynamic Group Membership | `dynamic_membership` rule | AD Group [APX-001] | — | Group rule confirmed via CLI | Free |
| 003 | Storage + Lifecycle Policy | `azurerm_storage_management_policy` | Storage Account [NCT-001/003], RBAC role assignment pattern [MRB-002/003] | **`for_each`** reintroduced — lifecycle `rule` blocks via map | Lifecycle policy visible via CLI | ~$0.00 |
| 004 | VNet Peering | `azurerm_virtual_network_peering` | VNet/Subnet [NCT-002], Private DNS pattern [MRB-007] | **`format()`** — building peering names dynamically | Two web pages proving cross-VNet reachability | ~$0.10/session |
| 005 | VMSS Basics | `azurerm_linux_virtual_machine_scale_set` | VM base config [NCT-002], Managed Identity [MRB-002] applied to the scale set this time | **`for_each`** — NOT needed on VMSS itself (it's one resource that internally scales), but used again for a `map(object)` of instance tags | "Hello from instance X" page | ~$0.15/session |
| 006 | Load Balancer + VMSS | `azurerm_lb` backend pool → VMSS | Load Balancer [MRB-004], now paired with VMSS instead of individual VMs | **`for_each`** — LB health probes defined as a map, reused exactly like MRB-004's pattern | Hit LB repeatedly, watch responses rotate | ~$0.50/session |
| 007 | Multi-Tier Lab 1 | VNet Integration for App Service | App Service + delegation [MRB-006], Key Vault RBAC [MRB-002/003] | **`dynamic`** block reintroduced — App Tier's `app_settings`-adjacent NSG rules via `dynamic "security_rule"` [MRB-006 pattern] | Web Tier page calling App Tier, showing response | ~$0.10/session |
| 008 | Multi-Tier Lab 2 — Data Tier | Private Endpoint for SQL | Private Endpoint + Private DNS [MRB-007], SQL + Key Vault secrets [NCT-007] | **`for_each`** on SQL firewall-adjacent config OR DNS records; **`format()`** for the connection string, same as NCT-007/MRB-007 | Web page showing live data from private DB | ~$1.00/session |
| 009 | Traffic Manager | DNS-level routing, Priority method | Traffic Manager [MRB-005], App Services from 007/008 | **`for_each`** on `map(object({name, priority}))` — identical pattern to MRB-005's `app_endpoints` variable | Traffic Manager FQDN routes to healthy endpoint | ~$0.01 |
| 010 | Capstone | — (pure synthesis) | Everything: NCT modules pattern [NCT-003/010], Azure Policy [MRB-008], Managed Identity [MRB-002/003], App Gateway [MRB-009] | **All four**: `for_each`, `dynamic`, `format()`, `jsonencode()` (policy rule, same as MRB-008) — every mechanic from both prior series in one project | One working multi-tier app, publicly reachable, full chain confirmed | ~$0.40/hr — session-based |

---

## What Changed From the Original Sketch

```
ORIGINAL sketch had:           NOW REPLACED WITH:
─────────────────────────────────────────────────────────────
Conditional Access (002)   →   Dynamic Group Membership
                                (Conditional Access needs paid
                                 Premium P1 licensing — dropped
                                 per budget rule)

Redis Cache (007)          →   Removed — folded VMSS + Load
                                Balancer in as their own dedicated
                                projects instead (005, 006), since
                                you specifically asked for these

Generic "networking basics" →  VNet Peering, given a genuine
(004)                          testable cross-VNet page instead
                                of just resource existence
```

---

## The Reuse Pattern, Made Explicit

This is the part directly answering your "add already-covered
resources plus use them in a new way" note — shown as one continuous
thread instead of scattered across each project description:

```
Azure AD Group (001, static)
   ↓ evolves into
Dynamic Group (002, same resource type, new membership mechanism)
   ↓ connects to
Storage Account via RBAC (003, first AD→resource bridge)
   ↓ storage pattern reapplied to
SQL Database with Private Endpoint (008, same lifecycle-thinking,
   new resource type)

VNet (004, two peered networks)
   ↓ same networking foundation hosts
VMSS (005, compute placed into that network shape)
   ↓ same VMSS fronted by
Load Balancer (006, distribution layer added on top)
   ↓ same distribution concept reapplied at DNS level via
Traffic Manager (009)

App Service pattern (used implicitly across identity work)
   ↓ becomes
Web Tier + App Tier (007, VNet-integrated for the first time)
   ↓ combines with
Data Tier (008)
   ↓ all of it becomes
Capstone (010)
```

Nothing in this series introduces a resource type and then
abandons it — every one gets picked back up later in a genuinely
different role.

---

## Cross-Series Resource Index — Where Each Reused Piece First Appeared

```
[NCT-001]  azurerm_storage_account, basic provider setup
[NCT-002]  VNet, Subnet, NSG, VM, dependency chains
[NCT-003]  Modules, remote state, locals{} naming pattern
[NCT-007]  SQL Server + Database, for_each with map(string), format()
             for connection strings
[NCT-009]  dynamic blocks, map(object({...})), Log Analytics/Alerts
[NCT-010]  Full capstone synthesis pattern (mirrored by APX-010)

[MRB-002]  Managed Identity (VM), RBAC role assignment pattern
[MRB-003]  Managed Identity (App Service), Key Vault references
             in app_settings
[MRB-004]  Standard Load Balancer, backend pools, health probes
[MRB-005]  Traffic Manager, for_each on map(object) for endpoints
[MRB-006]  VNet Integration, subnet delegation, dynamic NSG rules
[MRB-007]  Private Endpoint, Private DNS Zone, zero-public-access
             database pattern
[MRB-008]  Azure Policy, jsonencode() for policy rules
[MRB-009]  Application Gateway, WAF configuration
```

## Terraform Mechanic Repetition — Tracked Explicitly So Nothing Goes Stale

```
for_each (map)        → NCT-007 → APX-003 → APX-006 → APX-008 → APX-009 → APX-010
for_each (set)         → NCT-008 → APX-005 (instance tags)
dynamic block           → NCT-009/MRB-006 → APX-007 → APX-010
format()                → NCT-005/007 → APX-004 → APX-008 → APX-010
jsonencode()            → MRB-008 → APX-010
keys()                  → NCT-007/009 → reused in APX-006/008/009 outputs
locals.name_prefix       → NCT-003 onward → every APX project
```

Nothing introduced once and abandoned — every mechanic gets at
least 3 more reps across this series after its first appearance.

---

## Extension — Projects 011 to 015 (Senior-Level Topics)

Same standing rules apply: self-contained, budget-conscious,
micro-SKU by default, testable output, resource/mechanic reuse
tracked explicitly.

| # | Project | New Concept | Resource Reuse (Source) | Mechanic Repeated | Testable Output | Cost |
|---|---|---|---|---|---|---|
| 011 | Terraform Workspaces | `terraform workspace new/select` — one config, multiple isolated states, no folder duplication | Reuses APX-003's storage + lifecycle config, run through `dev` and `stg` workspaces | `locals.name_prefix` [NCT-003] now incorporates `terraform.workspace` automatically | Two isolated storage accounts from ONE config, proven via `terraform workspace list` | ~$0.00 |
| 012 | CI/CD for Terraform (GitHub Actions) | `.github/workflows/terraform.yml` — plan on PR, apply on merge | Reuses APX-004's VNet peering config as the pipeline's target | `terraform plan -out=tfplan` [best-practices guide] now runs INSIDE a pipeline, not just manually | A GitHub Actions run showing a real plan output as a PR comment | Free (GitHub Actions free tier) |
| 013 | Cosmos DB (Serverless) | `azurerm_cosmosdb_account` + `azurerm_cosmosdb_sql_container` | Key Vault secrets pattern [MRB-002/003] stores the Cosmos connection string | `for_each` on multiple containers via `map(object)` [NCT-007/MRB-005 pattern] | A page reading/writing a document to Cosmos DB live | ~$0.00 (serverless, pay-per-request) |
| 014 | Event-Driven Architecture | `azurerm_eventgrid_topic` + subscription triggering a Function App | Function App + Storage Queue [NCT-008], now triggered by Event Grid instead of a queue poll | `dynamic` block on Event Grid subscription filters [MRB-006/APX-007 pattern] | Trigger an event, watch the Function App log react within seconds | ~$0.00 (Event Grid free tier covers this easily) |
| 015 | Capstone 2.0 — CI/CD-Deployed Multi-Tier App | Full pipeline: GitHub Actions applies APX-010's architecture automatically on merge, using Workspaces for dev/stg | Everything: APX-010's full stack + Workspaces [011] + CI/CD [012] + Cosmos or Event Grid as an added service layer [013/014] | Every mechanic from the entire series, orchestrated end-to-end | A merge to `main` triggers a real deployment, ending in a live, working, multi-tier URL — the full loop, automated | ~$0.40/hr — session-based (App Gateway still the cost driver) |

### Why These Five, Specifically

```
011 (Workspaces)  → the natural next step after you've built the
                     SAME config 10+ times with slightly different
                     tfvars — workspaces are how real teams avoid
                     folder duplication for that exact problem

012 (CI/CD)        → the single most requested "make it feel like
                     a real job" skill — turns everything you've
                     done manually into an automated pipeline

013 (Cosmos DB)     → explicitly labeled Niche earlier in the
                     series, but genuinely common in modern
                     cloud-native apps — worth the exposure at
                     senior level even if it's not "everywhere"

014 (Event Grid)    → the event-driven pattern underlies a huge
                     amount of real serverless architecture —
                     natural pairing with the Function App work
                     from NexaCore

015 (Capstone 2.0)  → proves you can operate the FULL loop:
                     write code → pipeline plans it → pipeline
                     applies it → real infrastructure appears —
                     this is the actual day-to-day rhythm of a
                     real DevOps role, not just "run terraform
                     apply by hand"
```

---

## Status (Full 15)

## Status (Full 15)

```
APX-001   ✅  Done
APX-002   ✅  Done (rebuilt at correct Beginner+++ pace)
APX-003   ✅  Done
APX-004   📋  Next — VNet Peering with testable cross-network pages
APX-005 to 010   📋  Roadmapped — VMSS, LB, Multi-Tier, Capstone
APX-011 to 015   📋  Roadmapped — Workspaces, CI/CD, Cosmos DB,
                     Event Grid, Capstone 2.0
```

Say **"APX-004"** whenever you're ready, or flag anything on this
list you'd like adjusted before I build the next one.

---

*Apex Industries — Cloud Platform Engineering | Training Series*
