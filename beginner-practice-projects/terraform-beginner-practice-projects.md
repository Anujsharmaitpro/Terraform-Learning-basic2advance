# 6 Small Terraform Projects to Master Functions
### Beginner-friendly — each one is small, focused, and buildable in under 30 minutes

---

## Before You Start — Honest Setup Reality Check

Some projects here can be tested **without any Azure account** using `terraform console`
or `terraform plan`. Others actually deploy real Azure resources (which cost money).

| Project | Needs Azure account? | Approx Azure cost |
|---------|----------------------|-------------------|
| 1 — Name Badge Machine | ❌ No — console only | Free |
| 2 — Tag Factory | ❌ No — console only | Free |
| 3 — Environment Switcher | ❌ No — plan only | Free |
| 4 — Port Doorman (NSG) | ✅ Yes — deploys resources | ~$0 (NSG is free) |
| 5 — VNet + Subnet Calculator | ✅ Yes — deploys resources | ~$0 (VNet is free) |
| 6 — Safe Config Reader | ❌ No — plan + console | Free |

**Start with Projects 1-3 first.** Get comfortable with the functions before you touch real Azure.

---

## How to Create a New Project Folder (do this for every project)

```bash
mkdir project-1-name-badge && cd project-1-name-badge
touch main.tf variables.tf outputs.tf
terraform init   # only needed once per folder
```

For projects 4 and 5 you also need to be logged into Azure:

```bash
az login
az account set --subscription "YOUR_SUBSCRIPTION_ID"
```

---

---

# PROJECT 1 — The Name Badge Machine
## Functions practiced: `lower`, `replace`, `trimspace`, `format`, `substr`

### What you are building

A tiny module that takes a messy human-typed project name and produces
clean, valid Azure resource names from it. No Azure account needed —
you test everything in `terraform console`.

### The real-world problem this solves

Azure has strict naming rules: Resource Groups allow letters/numbers/hyphens,
Storage Accounts allow ONLY lowercase letters and numbers, max 24 chars.
If a developer types "My Payments App!!" as a project name, you need functions
to clean it before it hits the Azure API, otherwise the deployment fails
with a confusing error about invalid characters.

---

### File: `variables.tf`

```hcl
variable "project_name" {
  type        = string
  description = "Your project name — type it exactly as a human would"
  default     = "My Payments App!!"
}

variable "environment" {
  type        = string
  description = "Which environment: dev, staging, or prod"
  default     = "dev"
}
```

### File: `main.tf`

```hcl
# No provider needed — this file has only locals and outputs, nothing deploys

locals {
  # STEP 1: trimspace() — strip any accidental leading/trailing spaces
  trimmed = trimspace(var.project_name)

  # STEP 2: lower() — force everything to lowercase
  lowered = lower(local.trimmed)

  # STEP 3: replace() — swap spaces for hyphens
  hyphenated = replace(local.lowered, " ", "-")

  # STEP 4: replace() again — strip any special characters that Azure rejects
  # The pattern "/[^a-z0-9-]/" means: "anything that is NOT a lowercase letter,
  # digit, or hyphen" — replace all matches with nothing ("")
  clean_name = replace(local.hyphenated, "/[^a-z0-9-]/", "")

  # STEP 5: format() — build properly structured Azure resource names
  # Azure naming convention: rg-<project>-<environment>
  rg_name = format("rg-%s-%s", local.clean_name, var.environment)

  # STEP 6: substr() — Storage Accounts must be max 24 chars, no hyphens
  # First strip hyphens, then cut to 20 chars (leaving 4 chars room for a suffix)
  storage_base = replace(local.clean_name, "-", "")
  storage_name = substr(local.storage_base, 0, 20)
}

output "step_by_step" {
  description = "Watch the transformation happen step by step"
  value = {
    "1_original"   = var.project_name
    "2_trimmed"    = local.trimmed
    "3_lowered"    = local.lowered
    "4_hyphenated" = local.hyphenated
    "5_clean"      = local.clean_name
    "6_rg_name"    = local.rg_name
    "7_storage"    = local.storage_name
  }
}
```

### File: `outputs.tf`

```hcl
# Already inside main.tf above — nothing extra needed
```

---

### How to test it (no Azure account needed)

```bash
terraform init
terraform plan
```

You should see the `step_by_step` output printed showing every transformation.
Then **experiment** — this is where you actually learn:

```bash
# Try a messy name with special chars
terraform plan -var="project_name=HR & Finance System (v2)!!"

# Try a very long name and watch substr kick in
terraform plan -var="project_name=Enterprise Resource Planning System"

# Try uppercase mixed with spaces
terraform plan -var="project_name=AZURE CLOUD INFRA"
```

Also run these in `terraform console` (type `terraform console` in the folder):
```hcl
> lower("MY PAYMENTS APP!!")
> replace("my payments app!!", " ", "-")
> replace("my-payments-app!!", "/[^a-z0-9-]/", "")
> substr("mypayments", 0, 5)
> format("rg-%s-%s", "payments", "prod")
```

### What to experiment with

Change the `default` value in `variables.tf` to increasingly weird names
and predict what the output will be before running `terraform plan`.
If your prediction is right, you understand the function.

---

---

# PROJECT 2 — The Tag Factory
## Functions practiced: `merge`, `lookup`, `keys`, `values`, `length`

### What you are building

A module that produces a consistent, validated tag set for any Azure resource.
No Azure account needed — everything is tested via outputs.

### The real-world problem this solves

In enterprises, Azure resources without proper tags cause billing chaos —
nobody knows which team owns what, or which project to charge costs to.
The Tag Factory ensures every resource always gets the mandatory tags,
while still letting teams add their own custom tags on top.

---

### File: `variables.tf`

```hcl
variable "environment" {
  type    = string
  default = "dev"
}

variable "team_name" {
  type    = string
  default = "payments-team"
}

# A map that looks up the cost center code for each environment
variable "cost_centers" {
  type = map(string)
  default = {
    dev     = "CC-DEV-001"
    staging = "CC-STG-002"
    prod    = "CC-PRD-003"
  }
}

# Optional extra tags a team can add on top of the mandatory ones
variable "extra_tags" {
  type = map(string)
  default = {
    Workload = "Payments"
  }
}
```

### File: `main.tf`

```hcl
locals {
  # MANDATORY tags — every single Azure resource must have these
  mandatory_tags = {
    ManagedBy   = "Terraform"
    Environment = var.environment
    Team        = var.team_name
    # lookup() finds the cost center for this environment,
    # falls back to "CC-UNKNOWN" if someone passes an unexpected environment name
    CostCenter  = lookup(var.cost_centers, var.environment, "CC-UNKNOWN")
  }

  # merge() combines mandatory + extra tags into one final tag map.
  # IMPORTANT: if extra_tags has a key that also exists in mandatory_tags,
  # extra_tags WINS (because it comes second in the merge call).
  # This lets teams override tags, but only explicitly — no accidents.
  final_tags = merge(local.mandatory_tags, var.extra_tags)

  # Useful info about the tag set
  total_tag_count     = length(local.final_tags)
  tag_names_only      = keys(local.final_tags)
  tag_values_only     = values(local.final_tags)
}

output "tag_report" {
  value = {
    mandatory_tags  = local.mandatory_tags
    final_tags      = local.final_tags
    total_tags      = local.total_tag_count
    tag_names       = local.tag_names_only
  }
}
```

---

### How to test it

```bash
terraform plan
```

Then experiment:

```bash
# Test the lookup fallback — pass an unknown environment
terraform plan -var="environment=uat"

# Test that extra_tags get merged in
terraform plan -var='extra_tags={"Workload":"HR","Project":"Phase2"}'

# Test merge override — try to override a mandatory tag from extra_tags
terraform plan -var='extra_tags={"ManagedBy":"Manual","Workload":"Payments"}'
# ^ Watch whether extra_tags or mandatory_tags wins on "ManagedBy"
```

Also try in `terraform console`:
```hcl
> merge({"a"="1", "b"="2"}, {"b"="OVERRIDE", "c"="3"})
> lookup({"dev"="CC-001","prod"="CC-003"}, "prod", "UNKNOWN")
> lookup({"dev"="CC-001","prod"="CC-003"}, "staging", "UNKNOWN")
> keys({"ManagedBy"="Terraform","Team"="payments"})
> length({"ManagedBy"="Terraform","Team"="payments","Env"="dev"})
```

### What to experiment with

Add a new key to `mandatory_tags` AND `extra_tags` with the same name.
Predict which one survives in `final_tags` before running — then check.

---

---

# PROJECT 3 — The Environment Switcher
## Functions practiced: `lookup`, conditional expression (`? :`), `coalesce`, `try`

### What you are building

A module that automatically picks the right VM size, disk size, and
replica count based on the environment. Tests with `terraform plan` only
(no actual deployment, no Azure cost).

### The real-world problem this solves

Teams waste money when dev environments accidentally use prod-sized
(expensive) VMs, or when prod accidentally gets tiny dev machines.
The Switcher makes environment-appropriate sizing automatic and
un-bypassable without a code change.

---

### File: `variables.tf`

```hcl
variable "environment" {
  type    = string
  default = "dev"

  # validation block: prevents anyone from passing a typo like "development" or "production"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod — nothing else accepted."
  }
}

# Optional override: a team can explicitly force a VM size
# If they leave it blank (null), the Switcher picks one automatically
variable "vm_size_override" {
  type    = string
  default = null
}
```

### File: `main.tf`

```hcl
locals {
  # --- VM sizing config ---
  vm_size_map = {
    dev     = "Standard_B2s"
    staging = "Standard_D2s_v5"
    prod    = "Standard_D4s_v5"
  }

  # coalesce(): use the override if someone gave one, otherwise look up the map
  # This is the "layered config" pattern: team preference -> platform default
  vm_size = coalesce(
    var.vm_size_override,
    lookup(local.vm_size_map, var.environment, "Standard_B2s")
  )

  # --- Replica count ---
  # Conditional expression (ternary): "if this is prod, use 3, otherwise use 1"
  # This is exactly like: if environment == "prod": count = 3 else: count = 1
  replica_count = var.environment == "prod" ? 3 : 1

  # --- Disk config ---
  disk_size_map = {
    dev     = 64
    staging = 128
    prod    = 512
  }

  disk_size_gb = lookup(local.disk_size_map, var.environment, 64)

  # --- try() demo: safely read an optional team config ---
  # Pretend an external file MIGHT exist with team settings
  # try() means: "if reading this file crashes, just use an empty map instead"
  team_config = try(
    jsondecode(file("${path.module}/team-config.json")),
    {}   # fallback — empty map — if the file doesn't exist
  )

  # Then safely read a key from that config, with another try() fallback
  team_budget_tag = try(local.team_config.budget_code, "UNSET")
}

output "deployment_plan" {
  value = {
    environment   = var.environment
    vm_size       = local.vm_size
    replica_count = local.replica_count
    disk_size_gb  = local.disk_size_gb
    budget_code   = local.team_budget_tag
    was_overridden = var.vm_size_override != null
  }
}
```

---

### How to test it

```bash
# Test all three environments — compare the outputs side by side
terraform plan -var="environment=dev"
terraform plan -var="environment=staging"
terraform plan -var="environment=prod"

# Test the override: force a custom VM size
terraform plan -var="environment=dev" -var="vm_size_override=Standard_F4s_v2"

# Test the validation: try to break it with a bad environment name
terraform plan -var="environment=production"
# ^ Should FAIL with your custom error message — that's the correct behavior

# Test try(): create the optional file and see it get picked up
echo '{"budget_code":"BUDGET-2026"}' > team-config.json
terraform plan -var="environment=dev"
# Now delete it and run again — try() should silently fall back
rm team-config.json
terraform plan -var="environment=dev"
```

---

---

# PROJECT 4 — The Port Doorman (NSG)
## Functions practiced: `split`, `join`, `toset`, `length`, `concat`, dynamic blocks

### ⚠️ This one deploys real Azure resources

Resources created: 1 Resource Group + 1 NSG (both are free in Azure).
**Run `terraform destroy` when done so nothing lingers.**

### What you are building

An Azure Network Security Group whose inbound rules are generated
automatically from a comma-separated list of ports you provide.
No copy-pasting the same rule block five times.

---

### File: `provider.tf`

```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.8.0"
    }
  }
}

provider "azurerm" {
  features {}
}
```

### File: `variables.tf`

```hcl
variable "project_name" {
  type    = string
  default = "doorman-demo"
}

variable "location" {
  type    = string
  default = "eastus"
}

# The magic input: a comma-separated list of ports typed as one string
# This is exactly how pipeline parameters and CI/CD tools often pass lists
variable "allowed_ports" {
  type        = string
  default     = "80,443,8080,22"
  description = "Comma-separated list of TCP ports to allow inbound"
}

# Extra ports a specific team might need on top of the standard ones
variable "extra_ports" {
  type    = list(string)
  default = ["3000"]
}
```

### File: `main.tf`

```hcl
locals {
  # split() turns the comma-separated string into a proper list
  base_ports = split(",", var.allowed_ports)
  # "80,443,8080,22"  ->  ["80", "443", "8080", "22"]

  # concat() merges the base list with any extra ports
  all_ports_list = concat(local.base_ports, var.extra_ports)
  # ["80","443","8080","22"] + ["3000"]  ->  ["80","443","8080","22","3000"]

  # toset() deduplicates and makes it safe for for_each
  # (if someone accidentally passes "80" in both base AND extra, it only appears once)
  all_ports = toset(local.all_ports_list)

  # join() builds a readable summary for the tag/description
  ports_summary = join(", ", local.all_ports_list)
  # -> "80, 443, 8080, 22, 3000"

  # length() tells us how many rules will be created
  rule_count = length(local.all_ports)

  # Build the full rule objects — one per port
  # (We need priority to be unique per rule — 100, 101, 102, etc.)
  port_rules = [
    for idx, port in tolist(local.all_ports) : {
      name     = "allow-port-${port}"
      port     = port
      priority = 100 + idx
    }
  ]
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.project_name}"
  location = var.location
  tags     = { ManagedBy = "Terraform", Demo = "Project4-PortDoorman" }
}

resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-${var.project_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = { AllowedPorts = local.ports_summary }

  # dynamic block: Terraform generates one security_rule{} block per port
  # This replaces writing 5 identical security_rule blocks by hand
  dynamic "security_rule" {
    for_each = local.port_rules
    content {
      name                       = security_rule.value.name
      priority                   = security_rule.value.priority
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = security_rule.value.port
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
  }
}

output "nsg_summary" {
  value = {
    nsg_name      = azurerm_network_security_group.nsg.name
    rules_created = local.rule_count
    ports_allowed = local.ports_summary
  }
}
```

---

### How to test it

```bash
terraform init
terraform plan   # review what will be created — always read the plan first
terraform apply  # type "yes" to confirm

# Experiment — add new ports without touching main.tf
terraform apply -var="allowed_ports=80,443,3389"
terraform apply -var='extra_ports=["8080","9090"]'

# Test deduplication — pass "80" in both places, confirm only one rule appears
terraform apply -var="allowed_ports=80,443" -var='extra_ports=["80","8080"]'

# ALWAYS clean up when done — NSG is free but good habit
terraform destroy
```

---

---

# PROJECT 5 — The VNet + Subnet Calculator
## Functions practiced: `cidrsubnets`, `cidrsubnet`, `length`, `toset`, `for_each`

### ⚠️ This one deploys real Azure resources

Resources created: 1 Resource Group + 1 VNet + 3 Subnets (all free in Azure).
**Run `terraform destroy` when done.**

### What you are building

A VNet whose subnets are carved out mathematically from the parent address
space, instead of being hardcoded IP ranges. Change one variable and the
entire network re-calculates itself.

---

### File: `provider.tf`

```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.8.0"
    }
  }
}

provider "azurerm" {
  features {}
}
```

### File: `variables.tf`

```hcl
variable "project_name" {
  type    = string
  default = "network-demo"
}

variable "location" {
  type    = string
  default = "eastus"
}

variable "vnet_address_space" {
  type        = string
  default     = "10.0.0.0/16"
  description = "The big parent CIDR block. Subnets will be carved from this."
}

variable "subnet_names" {
  type        = list(string)
  default     = ["web", "app", "db"]
  description = "Names of the subnets to create — order matters for IP assignment"
}
```

### File: `main.tf`

```hcl
locals {
  # cidrsubnets() — carve N subnets out of the parent block in one call.
  # The number "8" means "add 8 bits to the parent prefix to get each subnet size."
  # Parent = /16, add 8 bits = /24 subnets.
  # It carves them consecutively, so you always get non-overlapping ranges.
  subnet_cidrs = cidrsubnets(
    var.vnet_address_space,
    # repeat "8" once per subnet (one 8 per entry in subnet_names)
    8, 8, 8
  )
  # If vnet = 10.0.0.0/16  ->  ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]

  # zipmap() pairs each subnet name with its automatically-calculated CIDR
  # keys = names ("web","app","db"), values = CIDRs ("10.0.0.0/24", etc.)
  subnet_map = zipmap(var.subnet_names, local.subnet_cidrs)
  # -> { web = "10.0.0.0/24", app = "10.0.1.0/24", db = "10.0.2.0/24" }
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.project_name}"
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${var.project_name}"
  address_space       = [var.vnet_address_space]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  tags = { ManagedBy = "Terraform" }
}

resource "azurerm_subnet" "subnets" {
  # for_each loops over the map — creates one subnet per entry
  for_each = local.subnet_map

  name                 = "snet-${each.key}"          # e.g. "snet-web"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [each.value]                 # e.g. ["10.0.0.0/24"]
}

output "network_layout" {
  value = {
    vnet_cidr   = var.vnet_address_space
    subnets     = local.subnet_map
    total_count = length(local.subnet_map)
  }
}
```

---

### How to test it

Before deploying, test the math in `terraform console`:

```hcl
> cidrsubnets("10.0.0.0/16", 8, 8, 8)
> cidrsubnets("192.168.0.0/24", 2, 2, 2)
> cidrsubnet("10.0.0.0/16", 8, 0)
> cidrsubnet("10.0.0.0/16", 8, 1)
> cidrsubnet("10.0.0.0/16", 8, 2)
> zipmap(["web","app","db"], ["10.0.0.0/24","10.0.1.0/24","10.0.2.0/24"])
```

Then deploy:
```bash
terraform init
terraform plan
terraform apply

# Experiment — change the parent CIDR and watch all subnets recalculate
terraform apply -var="vnet_address_space=172.16.0.0/16"

# Try a /24 parent carved into smaller /26 subnets (newbits = 2, not 8)
# Note: you'd need to edit main.tf and change the 8,8,8 to 2,2,2 for this

terraform destroy
```

---

---

# PROJECT 6 — The Safe Config Reader
## Functions practiced: `try`, `coalesce`, `jsondecode`, `sensitive`, `file`

### ❌ No Azure account needed — plan and console only

### What you are building

A module that reads from an optional config file on disk, handles the file
being missing gracefully, applies layered fallbacks using `coalesce`, and
keeps a sensitive value hidden from plan output using `sensitive()`.

This is a pure "resilience + safety" practice project.

---

### File: `variables.tf`

```hcl
variable "environment" {
  type    = string
  default = "dev"
}

# Simulates a secret that should NEVER appear in terminal output
variable "api_key" {
  type      = string
  sensitive = true
  default   = "super-secret-key-abc123"
}

# Optional team override for VM size
variable "team_vm_size_override" {
  type    = string
  default = null
}
```

### File: `config.json` — create this file in the same folder

```json
{
  "vm_size": "Standard_D2s_v5",
  "backup_retention_days": 14,
  "region": "westeurope"
}
```

### File: `main.tf`

```hcl
locals {
  # try() — attempt to read and parse config.json.
  # If the file doesn't exist → catch the error → fall back to empty map {}
  # If the file exists but has invalid JSON → catch it → fall back to {}
  file_config = try(jsondecode(file("${path.module}/config.json")), {})

  # try() — attempt to read vm_size from the parsed config.
  # If file_config is {} (empty) → "vm_size" key doesn't exist → try() catches it
  config_vm_size = try(local.file_config.vm_size, null)

  # coalesce() — layered priority:
  # 1st choice: team's explicit override (most trusted, most specific)
  # 2nd choice: what the config file says
  # 3rd choice: hardcoded platform safe default (always last resort)
  final_vm_size = coalesce(
    var.team_vm_size_override,
    local.config_vm_size,
    "Standard_B2s"
  )

  # try() — safely read backup days; fall back to 7 if not in config
  backup_retention = try(local.file_config.backup_retention_days, 7)

  # try() — safely read region; fall back to "eastus" if not in config
  region = try(local.file_config.region, "eastus")

  # sensitive() — mark the processed key as sensitive even inside locals
  # This stops it from accidentally showing in ANY output, log, or plan
  protected_key = sensitive(var.api_key)
}

output "resolved_config" {
  value = {
    vm_size          = local.final_vm_size
    backup_retention = local.backup_retention
    region           = local.region
    config_loaded    = length(local.file_config) > 0
  }
}

# sensitive = true is REQUIRED on an output if its value came from a sensitive source
output "api_key_check" {
  value     = local.protected_key
  sensitive = true   # shows as "(sensitive value)" in plan output — never plaintext
}
```

---

### How to test it — this is where you learn the most

```bash
# Test 1: Normal run with config.json present
terraform plan

# Test 2: Rename config.json and watch try() silently fall back
mv config.json config.json.bak
terraform plan
# All values should now be the hardcoded fallbacks
mv config.json.bak config.json

# Test 3: Break the JSON and watch try() catch the parse error
echo "THIS IS NOT VALID JSON{{{" > config.json
terraform plan
# Should still work — try() catches the jsondecode() crash
# Restore the real file
cat > config.json << 'EOF'
{
  "vm_size": "Standard_D2s_v5",
  "backup_retention_days": 14,
  "region": "westeurope"
}
EOF

# Test 4: Override from command line — beats everything
terraform plan -var="team_vm_size_override=Standard_F4s_v2"

# Test 5: Confirm the API key NEVER shows in plain text
terraform plan
# api_key_check should show as "(sensitive value)"
```

Also test in `terraform console`:
```hcl
> try(jsondecode("not-valid-json"), {})
> coalesce(null, "", "fallback-wins")
> coalesce(null, "middle-wins", "last")
> coalesce("first-wins", "second", "third")
> try({"a"="1"}.b, "key-doesnt-exist-fallback")
```

---

---

## Your Progression Order

```
Project 1 (console)
    → Comfortable with lower/replace/format?
    ↓
Project 2 (console)
    → Comfortable with merge/lookup/keys?
    ↓
Project 3 (plan only)
    → Comfortable with coalesce/try/conditional?
    ↓
Project 6 (plan only)
    → Comfortable with try/coalesce/sensitive together?
    ↓
Project 4 (deploys to Azure)
    → Comfortable with split/join/toset/dynamic?
    ↓
Project 5 (deploys to Azure)
    → Comfortable with cidrsubnets/zipmap/for_each?
    ↓
You now know the core 25 enterprise functions in actual working context.
```

---

## One Rule That Applies to Every Project

**Predict before you run.**

Before every `terraform plan`, write down on a piece of paper exactly what
you *think* the output will be. Then run it. If you were right: you understood
the function. If you were wrong: the gap between your prediction and the
real output is exactly the thing you needed to learn — and you learned it
in a way that will stick, because you were surprised.

This one habit turns 6 small projects into the equivalent of 60.
