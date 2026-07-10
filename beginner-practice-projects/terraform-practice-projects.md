# Terraform Practice Projects — Beginner Blueprints

> Two real-world projects. No solutions. No code given.
> Every requirement below mirrors what you would receive in an actual infrastructure ticket.

---

# Project 1 — Cloud Resume Storage Pipeline

## Section 1 — Project Overview

### What you are building

A serverless document hosting environment on Azure that stores and serves a static resume website. You will provision a **Storage Account** (for hosting), a **CDN Profile** (for fast global delivery), and an **Azure DNS Zone** (to map a custom domain to your CDN endpoint). Two environments — `dev` and `prod` — are deployed from the same Terraform code using different variable files.

### Architecture at a glance

```
Visitor's Browser
      ↓
Azure CDN Endpoint  (caches and delivers globally)
      ↓
Azure DNS Zone  (routes your custom domain to the CDN)
      ↓
Storage Account  (holds the actual HTML/CSS/JS files)
      └── $web container  (static website container — fixed name required by Azure)
```

### Why this matters architecturally

This project teaches three things simultaneously:

- **Resource dependency chaining** — DNS depends on CDN, CDN depends on Storage. You must provision them in the correct order, and Terraform must understand that relationship.
- **Environment parity without code duplication** — `dev` uses cheaper, locally-redundant storage. `prod` uses geo-redundant storage. Same code, different inputs.
- **Real Azure naming constraints** — Storage Account names have strict rules that will break your plan if you don't handle them programmatically. This forces you to use built-in functions rather than hardcoded strings.

### Real environment requirements

| Requirement | Dev | Prod |
|---|---|---|
| Azure Region | `eastus` | `eastus` |
| Storage Replication | `LRS` (Locally Redundant) | `GRS` (Geo Redundant) |
| CDN SKU | `Standard_Microsoft` | `Standard_Microsoft` |
| Custom domain | `dev.myresume.io` | `myresume.io` |
| Static website enabled | Yes | Yes |
| HTTPS only | No (dev relaxed) | Yes (enforced) |
| Resource Group | `resume-dev-rg` | `resume-prod-rg` |

---

## Section 2 — Naming Conventions

### Pattern rule

Every Azure resource name must follow this exact pattern:

```
{project}-{environment}-{resource-type}
```

**Exception:** Storage Account names cannot contain hyphens (Azure hard rule).
Use this pattern instead:

```
{project}{environment}sa
```

### Naming table — follow exactly

| Resource | Dev Name | Prod Name |
|---|---|---|
| Resource Group | `resume-dev-rg` | `resume-prod-rg` |
| Storage Account | `resumedevsa` | `resumeprodsa` |
| CDN Profile | `resume-dev-cdn` | `resume-prod-cdn` |
| CDN Endpoint | `resume-dev-endpoint` | `resume-prod-endpoint` |
| DNS Zone | `resume-dev-dns` | `resume-prod-dns` |

### Variable and file naming rules

| Context | Rule | Example |
|---|---|---|
| Variable names | `snake_case` | `storage_account_name` |
| Local names | `snake_case` | `local.name_prefix` |
| Resource labels | `snake_case` | `"storage_account" "main"` |
| Output names | `snake_case` | `cdn_endpoint_url` |
| Tag keys | `PascalCase` | `Environment`, `ManagedBy` |
| `.tfvars` files | `{env}.tfvars` | `dev.tfvars`, `prod.tfvars` |

### The one rule you must not break

> The word `dev` or `prod` must appear in your code **exactly once** — in the variable value inside your `.tfvars` file. Every resource name and tag must derive it from `var.environment`. If you type `"dev"` or `"prod"` anywhere inside a `.tf` file, refactor it.

---

## Section 3 — Core Components to Build

### Component A — Variables and locals scaffold

**File:** `variables.tf`, `locals.tf`

Declare all input variables. Then build a `locals` block that produces:

- `name_prefix` — the derived string `"{project}-{environment}"` used to name every resource
- `storage_name` — derived from `name_prefix` but with hyphens stripped and forced to lowercase, capped at 24 characters
- `common_tags` — a map combining all required tags, built using the `merge()` function

**Example variable values to use in `dev.tfvars`:**

```
project          = "resume"
environment      = "dev"
location         = "eastus"
cost_center      = "CC-WEB-001"
replication_type = "LRS"
https_only       = false
custom_domain    = "dev.myresume.io"
```

**Example variable values to use in `prod.tfvars`:**

```
project          = "resume"
environment      = "prod"
location         = "eastus"
cost_center      = "CC-WEB-002"
replication_type = "GRS"
https_only       = true
custom_domain    = "myresume.io"
```

**Functions you will need:** `lower()`, `replace()`, `substr()`, `merge()`

---

### Component B — Storage Account with validation

**File:** `main.tf`, `variables.tf`

Provision one `azurerm_storage_account` with static website hosting enabled. The storage name must be derived programmatically — never typed manually. Add a `validation` block on your `project` variable that rejects any input that would produce an invalid storage account name.

Add a `lifecycle` block with:
- `prevent_destroy = true` on the **prod** resource group
- `ignore_changes` for any tag that uses a timestamp

Write a comment in your code explaining why you chose the resource group and not the storage account for `prevent_destroy`.

**Example storage account properties to configure:**

```
account_tier             = "Standard"
account_replication_type = (from var.replication_type)
min_tls_version          = "TLS1_2"
https_traffic_only       = (from var.https_only)
static_website:
  index_document     = "index.html"
  error_404_document = "404.html"
```

---

### Component C — CDN Profile and Endpoint

**File:** `main.tf`

Provision an `azurerm_cdn_profile` and an `azurerm_cdn_endpoint` that points to the Storage Account's static website origin. The origin hostname must be derived from the Storage Account's primary web endpoint — not hardcoded.

**Example CDN properties to configure:**

```
cdn_profile:
  sku = "Standard_Microsoft"

cdn_endpoint:
  origin_host_header = (derived from storage account primary_web_endpoint)
  is_https_allowed   = true
  is_http_allowed    = (from var.https_only — inverted: dev=true, prod=false)
  querystring_caching_behavior = "IgnoreQueryString"

origin:
  name       = "storage-origin"
  https_port = 443
  http_port  = 80
```

---

### Component D — Outputs

**File:** `outputs.tf`

Create exactly four outputs. Each must have a `description`:

1. `resource_group_name` — the name of the resource group created
2. `storage_primary_web_endpoint` — the direct URL of the static website on Storage
3. `cdn_endpoint_url` — the CDN delivery URL (`https://{endpoint-name}.azureedge.net`)
4. `applied_tags` — the full tag map applied to resources in this environment

After running `terraform apply`, run `terraform output` and confirm all four values are populated and make sense. The CDN endpoint URL and the storage endpoint URL should be different — if they are the same, something is wrong.

---

## Section 4 — Architect's Hints and Pitfalls

### Pitfall 1 — The CDN origin hostname is not the storage account URL

Beginners often point the CDN origin at the storage account's blob endpoint (`https://{name}.blob.core.windows.net`). This is wrong for static websites. Azure static websites use a **separate web endpoint** attribute on the storage account. Look up the correct attribute name in the `azurerm_storage_account` documentation — they are not the same attribute and they return different URLs.

### Pitfall 2 — `https_traffic_only` does not equal `is_https_allowed` on the CDN

The storage account has one HTTPS enforcement setting. The CDN endpoint has two separate settings: `is_https_allowed` and `is_http_allowed`. Setting `https_traffic_only = true` on the storage account does not automatically enforce HTTPS on the CDN — you must configure the CDN endpoint separately. In prod, both HTTP settings must be deliberately set. In dev, you are intentionally relaxing this — document why in a comment.

### Hint — Run plan twice before touching prod values

After your first successful apply with `dev.tfvars`, run `terraform plan -var-file="environments/dev.tfvars"` again with no changes. It must report zero changes. If it reports any changes, something in your config is unstable — fix it before switching to `prod.tfvars`. A config that drifts on every apply is not production-ready.

---

---

# Project 2 — Multi-Team Internal App Platform

## Section 1 — Project Overview

### What you are building

A shared internal hosting platform on Azure that provisions isolated networking environments for two internal teams: the **API team** and the **Frontend team**. Each team gets their own **Virtual Network**, a set of **Subnets** (at least three per team), and a **Network Security Group** with inbound rules driven entirely by data — not hardcoded rule blocks. One shared **Storage Account** holds deployment artifacts for both teams. Two environments: `dev` and `prod`.

### Architecture at a glance

```
                    ┌─────────────────────────────────┐
                    │        Resource Group             │
                    │  (one per environment)            │
                    └──────────────┬──────────────────-┘
                                   │
              ┌────────────────────┴────────────────────┐
              │                                         │
   ┌──────────▼──────────┐                ┌────────────▼──────────┐
   │     API Team VNet    │                │  Frontend Team VNet   │
   │  ┌───────────────┐  │                │  ┌───────────────┐   │
   │  │  app subnet   │  │                │  │  app subnet   │   │
   │  │  data subnet  │  │                │  │  mgmt subnet  │   │
   │  │  mgmt subnet  │  │                │  │  cache subnet │   │
   │  └───────────────┘  │                │  └───────────────┘   │
   │  NSG (port rules)   │                │  NSG (port rules)    │
   └─────────────────────┘                └──────────────────────┘
                              │
                  ┌───────────▼────────────┐
                  │   Shared Storage Acct  │
                  │  (artifacts container) │
                  └────────────────────────┘
```

### Why this matters architecturally

- **Data-driven infrastructure** — NSG rules are generated from a list of ports, not written as individual hardcoded blocks. Adding a port means changing one variable value, not writing a new resource block.
- **`for_each` over `count`** — Subnets are created with `for_each`. You will understand exactly why removing a subnet from the middle of a `count`-based list is destructive, and why `for_each` prevents that.
- **Dynamic blocks** — This is the textbook scenario for `dynamic` blocks: a variable number of nested blocks inside a resource, driven by input data.

### Real environment requirements

| Requirement | Dev | Prod |
|---|---|---|
| Azure Region | `eastus` | `westeurope` |
| API VNet CIDR | `10.0.0.0/16` | `10.10.0.0/16` |
| Frontend VNet CIDR | `10.1.0.0/16` | `10.11.0.0/16` |
| API allowed ports | `22, 80, 443, 8080` | `80, 443` |
| Frontend allowed ports | `80, 443, 3000` | `80, 443` |
| Storage replication | `LRS` | `GRS` |
| NSG rule priority base | `100` | `100` |

---

## Section 2 — Naming Conventions

### Pattern rule

```
{project}-{team}-{environment}-{resource-type}
```

**Exception:** Storage Account — no hyphens, lowercase + numbers only, max 24 chars:

```
{project}{environment}artifacts
```

### Naming table — follow exactly

| Resource | Dev — API Team | Dev — Frontend Team |
|---|---|---|
| Resource Group | `platform-dev-rg` | (same RG, shared) |
| API VNet | `platform-api-dev-vnet` | — |
| Frontend VNet | — | `platform-fe-dev-vnet` |
| API NSG | `platform-api-dev-nsg` | — |
| Frontend NSG | — | `platform-fe-dev-nsg` |
| Shared Storage | `platformdevartifacts` | (shared) |
| Artifacts Container | `deployment-artifacts` | (shared) |

### Subnet naming pattern

Subnets within each VNet follow:

```
{team-prefix}-{subnet-purpose}
```

Examples:
```
api-app      api-data      api-mgmt
fe-app       fe-mgmt       fe-cache
```

### Variable and file naming rules

| Context | Rule | Example |
|---|---|---|
| Variable names | `snake_case` | `api_allowed_ports` |
| Local names | `snake_case` | `local.api_name_prefix` |
| Resource labels — single | use `main` | `"resource_group" "main"` |
| Resource labels — collections | use descriptive plural | `"azurerm_subnet" "api_subnets"` |
| NSG dynamic iterator | explicit name | `iterator = port` |
| Output names | `snake_case` | `api_vnet_id` |

### Singular vs. Plural rule for this project

| Situation | Rule | Example |
|---|---|---|
| One VNet per team | Use team prefix + `main` | `azurerm_virtual_network.api_main` |
| Multiple subnets | Use plural label | `azurerm_subnet.api_subnets` |
| Variable holding one value | Singular | `var.environment` |
| Variable holding a list | Plural | `var.api_allowed_ports` |
| Dynamic block iterator | Singular descriptive | `iterator = port` |

---

## Section 3 — Core Components to Build

### Component A — Variables, locals, and team configuration scaffold

**File:** `variables.tf`, `locals.tf`

Declare all variables. Then build a `locals` block that produces derived values for **both teams** — you should not repeat the same derivation logic twice. The two teams share the same structure; only the prefix and CIDR differ.

**Example variable values — `dev.tfvars`:**

```
project     = "platform"
environment = "dev"
location    = "eastus"
cost_center = "CC-INFRA-001"

api_vnet_cidr       = "10.0.0.0/16"
api_allowed_ports   = [22, 80, 443, 8080]
api_subnets = {
  api-app  = "10.0.0.0/24"
  api-data = "10.0.1.0/24"
  api-mgmt = "10.0.2.0/24"
}

fe_vnet_cidr        = "10.1.0.0/16"
fe_allowed_ports    = [80, 443, 3000]
fe_subnets = {
  fe-app   = "10.1.0.0/24"
  fe-mgmt  = "10.1.1.0/24"
  fe-cache = "10.1.2.0/24"
}
```

**Example variable values — `prod.tfvars`:**

```
project     = "platform"
environment = "prod"
location    = "westeurope"
cost_center = "CC-INFRA-002"

api_vnet_cidr       = "10.10.0.0/16"
api_allowed_ports   = [80, 443]
api_subnets = {
  api-app  = "10.10.0.0/24"
  api-data = "10.10.1.0/24"
  api-mgmt = "10.10.2.0/24"
}

fe_vnet_cidr        = "10.11.0.0/16"
fe_allowed_ports    = [80, 443]
fe_subnets = {
  fe-app   = "10.11.0.0/24"
  fe-mgmt  = "10.11.1.0/24"
  fe-cache = "10.11.2.0/24"
}
```

**Mandatory tags on every resource:**

```
Environment = var.environment
ManagedBy   = "Terraform"
Project     = var.project
CostCenter  = var.cost_center
Team        = (api or fe — set per resource)
```

---

### Component B — Dual VNets and subnets using `for_each`

**File:** `main.tf`

Provision two Virtual Networks — one for the API team, one for the Frontend team. Each VNet gets its own set of subnets, created using `for_each` with the subnet map from your variables.

You must use `for_each` — not `count`. Write a comment in your code explaining what would happen to the `api-mgmt` subnet if you used `count` and then removed `api-data` from the list.

**API VNet properties:**

```
name          = (derived from local.api_name_prefix + "-vnet")
address_space = [var.api_vnet_cidr]
```

**API Subnet properties (for_each over var.api_subnets):**

```
name             = each.key         (e.g. "api-app")
address_prefixes = [each.value]     (e.g. ["10.0.0.0/24"])
```

Apply identical structure for the Frontend team. Do not copy-paste the resource blocks — think about whether a module or a well-structured `for_each` over a team map can avoid the duplication. Attempt the duplication first, then consider the refactor.

---

### Component C — NSG with dynamic inbound rules

**File:** `main.tf`

Provision two NSGs — one per team. Inbound allow rules must be generated dynamically from the `allowed_ports` list for each team. You must use a `dynamic` block — no hardcoded `security_rule` blocks.

**Rules for priority assignment:**

- Priority = `100 + port_number`
- Port 80 → priority 180
- Port 443 → priority 543
- Port 8080 → priority 8180
- Port 3000 → priority 3100

**This means:** adding a port to the list never changes another port's priority. Write a comment explaining why position-based priority (`100 + index * 10`) would be fragile.

**NSG rule properties per port:**

```
name                       = "allow-inbound-{port}"
priority                   = 100 + port
direction                  = "Inbound"
access                     = "Allow"
protocol                   = "Tcp"
source_port_range          = "*"
destination_port_range     = (the port as a string)
source_address_prefix      = "*"
destination_address_prefix = "*"
```

Use `iterator = port` in your dynamic block. Do not use the default iterator name.

---

### Component D — Shared storage account and outputs

**File:** `main.tf`, `outputs.tf`

Provision one shared `azurerm_storage_account` with one container named `deployment-artifacts`. The storage account name must be programmatically derived and validated.

Add a `precondition` inside a `lifecycle` block on the storage account that checks the derived name is valid (3–24 chars, lowercase alphanumeric only) after all transformations are applied.

**Storage properties:**

```
account_tier             = "Standard"
account_replication_type = (LRS for dev, GRS for prod)
min_tls_version          = "TLS1_2"
container_access_type    = "private"
```

**Required outputs (all with descriptions):**

```
api_vnet_id            = azurerm_virtual_network.api_main.id
fe_vnet_id             = azurerm_virtual_network.fe_main.id
api_subnet_ids         = map of subnet name → subnet id (for_each produces this naturally)
fe_subnet_ids          = map of subnet name → subnet id
shared_storage_name    = the derived storage account name
applied_tags           = local.common_tags
```

---

## Section 4 — Architect's Hints and Pitfalls

### Pitfall 1 — Port-based priority vs. index-based priority

A common beginner approach for NSG rule priorities is `100 + (index * 10)`. This works until someone inserts a new port in the middle of the list. Suddenly every port after the inserted one changes its priority on the next apply — Terraform will update all those rules even though nothing about them changed. In a production NSG this creates unnecessary noise and risk.

Port-number-based priority (`100 + port`) is stable because a port's number never changes. The risk to watch: Azure NSG priorities have a maximum of 4096. Port 8080 → priority 8180 exceeds this. Add a `validation` block or `precondition` that catches ports which would produce an invalid priority before Terraform contacts Azure.

### Pitfall 2 — Two teams means duplicated resource blocks — or a design decision

You have two teams with identical resource shapes (VNet → Subnets → NSG). The naive solution is to write two complete sets of resource blocks — one for `api`, one for `fe`. This works but is fragile: if the structure needs to change (e.g. adding a new subnet type), you must change it in two places.

The better solution is to build a `locals` map that combines both teams' configurations under a single key, then loop over that map with `for_each`. This is harder to set up but means the structure only exists once. Attempt the duplicated approach first so you understand the pain, then attempt the refactored version. The goal is to feel why the refactor matters — not just to know it theoretically.

### Hint — The `for_each` subnet map is already the right shape for outputs

When you use `for_each` to create subnets, Terraform stores the results as a map automatically — keyed by whatever you used as the `for_each` key. This means `azurerm_subnet.api_subnets` is already a map of subnet name → subnet object. Your output does not need any transformation: you can reference it directly and it will produce the map of IDs the output requires. If you find yourself writing a `for` expression to reconstruct a map that already exists, you are doing extra work unnecessarily.

---

---

## Self-Check — Before You Consider Either Project Done

Run through every item below after each project. Each one catches a real category of mistake:

| Check | What it catches |
|---|---|
| `terraform validate` passes cleanly | Syntax errors, missing required arguments |
| `terraform plan` after first apply reports zero changes | Unstable config — timestamp drift, unstable ordering |
| Removing one subnet from the map shows exactly one destroy | Confirms `for_each` is working correctly, not `count` |
| Setting `environment = "staging"` fails immediately with your message | Confirms variable validation is working |
| `terraform output` shows no secret values | Confirms sensitive output handling |
| Prod NSG has 2 rules, dev NSG has more | Confirms dynamic block is driven by input, not hardcoded |
| Storage account name contains no hyphens or uppercase | Confirms name derivation functions are applied |
| Every resource in the portal has all required tags | Confirms `common_tags` is applied everywhere |

---

*These projects are designed to be built in order — Project 1 first, Project 2 second.
Project 1 teaches resource chaining and environment parity.
Project 2 teaches data-driven infrastructure and dynamic generation.
Together they cover the core Terraform skill set expected in a junior DevOps role.*
