# Terraform Functions — Full Solutions & Explainers
### Reference guide — use after attempting, or when genuinely stuck

> A note on how to use this file: solutions here reflect one correct way
> to solve each problem, not the only way. Where there's a real design
> decision (not just syntax), I've flagged it explicitly rather than
> presenting it as the single obvious answer.

---
---

# PROJECT 1 — The Name Cleaner — SOLUTION

### `variables.tf`

```hcl
variable "project_name" {
  type    = string
  default = "HR & Payroll System "
}
```

### `main.tf`

```hcl
locals {
  # Step 1: strip leading/trailing whitespace only
  trimmed = trimspace(var.project_name)

  # Step 2: lowercase everything
  lowered = lower(local.trimmed)

  # Step 3: replace internal spaces with hyphens
  hyphenated = replace(local.lowered, " ", "-")

  # Step 4: strip anything that isn't a lowercase letter, digit, or hyphen
  # "/[^a-z0-9-]/" is a regex: [^...] means "NOT any of these characters"
  clean_name = replace(local.hyphenated, "/[^a-z0-9-]/", "")

  # --- Now build each Azure-specific name from clean_name ---

  resource_group_name = "rg-${local.clean_name}"

  # Storage accounts: no hyphens allowed, max 24 chars (we cap at 20 for safety margin)
  storage_no_hyphens  = replace(local.clean_name, "-", "")
  storage_account_name = substr(local.storage_no_hyphens, 0, 20)

  # Key Vault: hyphens allowed, max 24 chars total including "kv-" prefix
  kv_raw  = "kv-${local.clean_name}"
  key_vault_name = substr(local.kv_raw, 0, 24)

  # VM name: max 15 chars total including "vm-" prefix (Windows limit)
  vm_raw = "vm-${local.clean_name}"
  vm_name = substr(local.vm_raw, 0, 15)
}

output "resource_group_name"  { value = local.resource_group_name }
output "storage_account_name" { value = local.storage_account_name }
output "key_vault_name"       { value = local.key_vault_name }
output "vm_name"              { value = local.vm_name }
```

### Explainer

**Why this exact order of operations (trim → lower → replace spaces → strip specials)?**
Order matters because each function only does its own single job on
whatever text it receives. If you strip special characters *before*
lowercasing, `"HR & Payroll"` would leave weird gaps where `&` used to be,
but the surrounding structure would still be inconsistent case. Doing
casing first, then structural cleanup (spaces → hyphens), then final
character sanitization, keeps each step predictable and easy to reason
about independently — this is a general engineering principle, not
just a Terraform quirk: normalize broad properties (case) before
narrow ones (character set).

**Why `substr()` after building the full prefixed name, not before?**
If you truncated `clean_name` to 20 characters *before* adding `"kv-"`,
your final Key Vault name could be `23` characters (`kv-` + 20 chars) —
technically fine here, but the pattern of "truncate the raw material,
then add the prefix" is fragile. It's safer to build the full candidate
string first, then enforce the length limit on the *actual final value*
that will be sent to Azure. Otherwise you're truncating based on an
assumption about prefix length that could silently drift if requirements
change.

**The regex `"/[^a-z0-9-]/"` — breaking down every character:**
- The outer `/ /` slashes tell Terraform "this is a regex pattern, not literal text"
- `[...]` defines a character set
- `^` as the *first* character inside `[...]` means "NOT" (negation)
- `a-z` = any lowercase letter, `0-9` = any digit, `-` = literal hyphen
- So the whole pattern matches: "any single character that is NOT a
  lowercase letter, digit, or hyphen" — and `replace()` swaps every
  match with `""` (nothing), effectively deleting it

**A gap worth noticing:** this solution doesn't handle the case where
`clean_name` ends up empty (e.g., if someone passes `"!!!@@@"` as
`project_name` — every character gets stripped). Try that input and
watch what happens to `resource_group_name` (`"rg-"`). This is exactly
the kind of edge case the stretch goals point at — worth adding a
`validation` block to catch it before it becomes a confusing Azure
API error instead of a clear Terraform error.

---
---

# PROJECT 2 — The Tag Enforcer — SOLUTION

### `variables.tf`

```hcl
variable "environment" {
  type    = string
  default = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}

variable "team_tags" {
  type    = map(string)
  default = {}
}
```

### `main.tf`

```hcl
locals {
  cost_center_map = {
    dev     = "CC-100"
    staging = "CC-200"
    prod    = "CC-300"
  }

  mandatory_tags = {
    ManagedBy   = "Terraform"
    Environment = var.environment
    CostCenter  = lookup(local.cost_center_map, var.environment, "CC-UNKNOWN")
    Department  = "Engineering"
    Compliance  = "Required"
  }

  # IMPORTANT DESIGN DECISION — see explainer below
  final_tags = merge(var.team_tags, local.mandatory_tags)

  total_tag_count = length(local.final_tags)
  tag_keys        = keys(local.final_tags)
}

output "final_tags"       { value = local.final_tags }
output "total_tag_count"  { value = local.total_tag_count }
output "tag_keys"         { value = local.tag_keys }
```

### Explainer

**Why `merge(var.team_tags, local.mandatory_tags)` and not the reverse?**
This is the one correction worth dwelling on. `merge()`'s rule is
"later arguments win on key conflicts." If your goal is that mandatory
tags are actually *mandatory* — meaning a team cannot override them,
even accidentally — then `mandatory_tags` must be the **second**
argument, so it always wins. Putting `team_tags` second (as I did in
an earlier draft of this same project) means a team passing
`{"ManagedBy": "Manual"}` would silently overwrite your compliance tag,
which defeats the entire stated purpose of "the platform team's policy
cannot be skipped." If the actual requirement had been "let teams
override anything they want, with sensible defaults," the original
order would have been correct — the point is that the merge order
is a real policy decision, not a coin flip, and you should be able to
justify it based on what you're actually trying to enforce.

**Why is `cost_center_map` a `local`, not a `variable`?**
Because it's internal business logic the module owns and controls —
teams calling this module shouldn't be able to redefine what `"CC-300"`
means for `prod`. If it were a variable, any caller could pass a
different cost center mapping and undermine the whole point of
centralizing this logic. This is the same "variable vs local" boundary
covered earlier: things the caller should control are variables;
things that are the module's own internal rules are locals.

**What happens with `environment = "uat"` despite the validation block?**
It can't — the `validation` block runs before anything else and will
reject `"uat"` immediately with your custom error message, since it's
not in the `["dev", "staging", "prod"]` list. This is actually a better
safety net than relying on `lookup()`'s fallback (`"CC-UNKNOWN"`) alone,
because it stops a bad environment name from ever reaching your tagging
logic in the first place, rather than silently producing a nonsense
cost center. Both layers of protection working together — validation
catching bad input at the door, and `lookup()`'s fallback as a second
safety net for anything that somehow slips through — is a genuinely
good defensive pattern.

**Stretch goal answer — finding missing mandatory tags:**
```hcl
locals {
  missing_required_tags = setsubtract(
    keys(local.mandatory_tags),
    keys(local.final_tags)
  )
}
```
`setsubtract(a, b)` returns everything in `a` that is NOT in `b`. Since
`final_tags` is built from a `merge()` that includes all of
`mandatory_tags`, this will always return an empty set in this design —
which is itself a useful thing to demonstrate: the check *proves*
your merge order is correctly enforcing the policy. If you deliberately
break the merge order (swap the arguments) and re-run this check, it
still shows empty, because `merge()` never drops keys, it only decides
which *value* wins on a shared key. This is worth sitting with: this
particular stretch goal check would not have caught the original bug —
teaches you that "presence of the key" and "correctness of the value"
are two different things to verify.

---
---

# PROJECT 3 — The Environment Switcher — SOLUTION

### `variables.tf`

```hcl
variable "environment" {
  type    = string
  default = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}

variable "vm_size_override" {
  type    = string
  default = null
}
```

### `main.tf`

```hcl
locals {
  vm_size_map = {
    dev     = "Standard_B2s"
    staging = "Standard_D2s_v5"
    prod    = "Standard_D4s_v5"
  }

  disk_size_map = {
    dev     = 64
    staging = 128
    prod    = 512
  }

  replica_map = {
    dev     = 1
    staging = 2
    prod    = 3
  }

  backup_map = {
    dev     = false
    staging = false
    prod    = true
  }

  # Attempt to read config.json — if missing or invalid, fall back to {}
  file_config = try(jsondecode(file("${path.module}/config.json")), {})

  config_file_loaded = local.file_config != {}

  # Safely pull vm_size out of the file config, null if not present
  config_vm_size = try(local.file_config.vm_size, null)

  # Layered fallback: override -> config file -> environment matrix -> hard fallback
  resolved_vm_size = coalesce(
    var.vm_size_override,
    local.config_vm_size,
    lookup(local.vm_size_map, var.environment, null),
    "Standard_B1s"
  )

  disk_size_gb   = lookup(local.disk_size_map, var.environment, 64)
  replica_count  = lookup(local.replica_map, var.environment, 1)
  backup_enabled = lookup(local.backup_map, var.environment, false)
}

output "resolved_vm_size"    { value = local.resolved_vm_size }
output "disk_size_gb"        { value = local.disk_size_gb }
output "replica_count"       { value = local.replica_count }
output "backup_enabled"      { value = local.backup_enabled }
output "config_file_loaded"  { value = local.config_file_loaded }
```

### Explainer

**Why does `resolved_vm_size` have FOUR arguments in `coalesce()`, not three?**
Look closely at the priority chain: override, config file, environment
matrix, hard fallback — that's four distinct sources. The brief said
"three levels" conceptually, but `lookup()` itself can return `null`
if you don't give it a default (or you can give `lookup()` a default,
collapsing levels 3 and 4 into one). Both are valid — I chose to keep
`lookup(...)`'s third argument as `null` and let `coalesce()` handle
the truly final fallback, because it makes the whole priority order
readable in one place (inside the `coalesce()` call) instead of split
between a `lookup()` default and a `coalesce()` default. This is a
readability choice, not a correctness requirement — if you passed
`"Standard_B1s"` as `lookup()`'s third argument instead and dropped
it from `coalesce()`, that also works correctly.

**Why wrap the ENTIRE `jsondecode(file(...))` in one `try()`, instead
of `try(file(...))` and `try(jsondecode(...))` separately?**
Because either step can fail independently, for different reasons —
`file()` fails if the file doesn't exist, `jsondecode()` fails if the
content isn't valid JSON — and you want the same fallback behavior
(`{}`) regardless of *which* step failed. Wrapping the composed
expression in a single `try()` means: "if anything in this chain
breaks, for any reason, just give me an empty map." Splitting it into
two `try()` calls would require you to reason about partial failure
states (e.g., "what if `file()` succeeds but returns garbage that
`jsondecode` chokes on") — more complexity for no real benefit here.

**The bug in `config_file_loaded = local.file_config != {}` — worth knowing this exists:**
This comparison technically works in current Terraform because map
equality compares contents, but it's a common source of confusion for
beginners who expect `!=` to behave like reference inequality (as in
some other languages). A more explicit and arguably clearer way to
write the same check:
```hcl
config_file_loaded = length(local.file_config) > 0
```
Both are correct. I'd lean toward the `length()` version in production
code because it reads unambiguously as "does this have any keys," while
`!= {}` requires the reader to trust that map comparison works the way
they think it does.

**Testing the empty-string edge case (`vm_size_override = ""`):**
Run this and check the result:
```bash
terraform plan -var="environment=dev" -var="vm_size_override="
```
`coalesce()` correctly treats `""` as empty and skips it, falling
through to the next argument — this is exactly the behavior you want,
and it's *why* `coalesce()` was the right function to reach for here
instead of a manual `var.vm_size_override != null ? ... : ...`
conditional, which would NOT have skipped an empty string automatically.

---
---

# PROJECT 4 — The NSG Port Manager — SOLUTION

### `provider.tf`

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

### `variables.tf`

```hcl
variable "project_name" {
  type    = string
  default = "doorman-demo"
}

variable "location" {
  type    = string
  default = "eastus"
}

variable "allowed_ports" {
  type    = string
  default = "80,443"
}

variable "extra_ports" {
  type    = list(string)
  default = []
}
```

### `main.tf`

```hcl
locals {
  base_ports      = split(",", var.allowed_ports)
  combined_ports  = concat(local.base_ports, var.extra_ports)
  unique_ports    = tolist(toset(local.combined_ports))  # dedupe, then back to a list for indexing
  ports_summary   = join(", ", sort(local.unique_ports))
  rule_count      = length(local.unique_ports)

  port_rules = [
    for idx, port in local.unique_ports : {
      name     = "allow-port-${port}"
      port     = port
      priority = 100 + idx   # guarantees uniqueness: 100, 101, 102...
    }
  ]
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.project_name}"
  location = var.location
}

resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-${var.project_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = { AllowedPorts = local.ports_summary }

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

output "rule_count"     { value = local.rule_count }
output "ports_allowed"  { value = local.ports_summary }
```

### Explainer

**Why `tolist(toset(...))` and not just `toset(...)` on its own?**
`toset()` gives you deduplication, but sets in Terraform have **no
guaranteed order** — you cannot index into a set with `[0]`, `[1]`,
etc., and a `for` expression over a set doesn't give you a reliable
position for building sequential priorities. Converting back to a list
with `tolist()` gives you something indexable again, at the cost that
the *order* after deduplication isn't necessarily the original input
order — which is exactly why the next line adds `sort()` when building
the human-readable summary, so at least the tag output is
deterministic and alphabetically consistent across runs, even if the
priority numbers assigned aren't tied to "the order the user typed them."

**Is it a problem that priorities aren't in the user's typing order?**
Not functionally — NSG rule priority only matters for evaluation order
when there's overlapping traffic logic (e.g., an Allow rule and a Deny
rule both matching the same port), and here every rule does the same
thing (Allow). If your stretch goal adds Deny rules, this becomes a
real design question worth thinking about carefully: Azure evaluates
NSG rules in priority order, lowest number first, so if you add a
`denied_ports` list, you'd need to decide whether deny rules should
get lower (higher-priority) numbers than allow rules, and structure
your `port_rules` construction accordingly rather than just appending.

**Why `100 + idx` instead of just using `idx` directly as the priority?**
Azure NSG rule priorities must be between 100 and 4096. Using `idx`
alone would start at `0`, which Azure rejects outright. `100 + idx`
is the simplest fix, though in a codebase with many dynamically-added
rules over time, some teams reserve blocks of priority ranges (e.g.,
100-199 for platform rules, 200-299 for app team rules) to leave room
for manual rules to be inserted later without renumbering everything —
worth knowing this exists as a real operational concern, even though
it's outside the scope of what this exercise asked for.

---
---

# PROJECT 5 — The Network Calculator — SOLUTION

### `provider.tf`

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

### `variables.tf`

```hcl
variable "project_name" {
  type    = string
  default = "network-demo"
}

variable "location" {
  type    = string
  default = "eastus"
}

variable "vnet_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "subnet_names" {
  type    = list(string)
  default = ["web", "app", "db"]
}
```

### `main.tf`

```hcl
locals {
  # Build a list of "8"s, one per subnet name, so cidrsubnets() knows
  # how many /24 slices to carve and produces exactly that many results.
  # range(N) produces [0, 1, 2, ..., N-1]; we don't use the numbers
  # themselves, just their count, to drive the loop.
  newbits_per_subnet = [for i in range(length(var.subnet_names)) : 8]

  # The "..." spreads the list into separate arguments, since cidrsubnets()
  # expects them comma-separated, not bundled as one list argument.
  subnet_cidrs = cidrsubnets(var.vnet_cidr, local.newbits_per_subnet...)

  # Pair each subnet name with its calculated CIDR
  subnet_map = zipmap(var.subnet_names, local.subnet_cidrs)
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.project_name}"
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${var.project_name}"
  address_space       = [var.vnet_cidr]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnets" {
  for_each             = local.subnet_map
  name                 = "snet-${each.key}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [each.value]
}

output "subnet_map"   { value = local.subnet_map }
output "total_count"  { value = length(local.subnet_map) }
```

### Explainer

**This is the hardest hint in the whole set — walking through it slowly:**
`cidrsubnets()` doesn't take "how many subnets do you want" as a
single number. It takes **one `newbits` argument per subnet you want**,
because in principle each subnet could be a *different* size (some /24,
some /26, etc.) — the function's flexibility is also why it's slightly
awkward to call dynamically. Since this project wants all subnets the
same size, we build a list that just repeats `8` once for every name
in `subnet_names`, then use `...` to unpack that list into individual
arguments. If `subnet_names` has 3 items, `newbits_per_subnet` is
`[8, 8, 8]`, and `cidrsubnets(var.vnet_cidr, 8, 8, 8)` is exactly what
gets called — the `...` and the repeated-list trick is just a way to
make that argument count dynamic instead of hardcoded.

**Why `zipmap()` instead of building the map with a `for` expression directly?**
You could absolutely write:
```hcl
subnet_map = { for idx, name in var.subnet_names : name => local.subnet_cidrs[idx] }
```
This is equally correct and arguably more explicit about *why* the
pairing works (matching by index). `zipmap()` is more concise for the
common case of "I have two same-length lists and want to pair them
positionally" — but it's worth knowing both approaches exist, because
`zipmap()` breaks down awkwardly the moment your pairing logic isn't
a simple 1-to-1 positional match (e.g., if you needed to skip some
combinations conditionally), whereas a `for` expression handles that
naturally.

**Stretch goal — first usable IP per subnet:**
```hcl
locals {
  first_usable_ip = { for name, cidr in local.subnet_map : name => cidrhost(cidr, 4) }
}
```
`cidrhost(prefix, hostnum)` returns a specific IP inside a CIDR block —
`hostnum = 0` would be the network address itself (not assignable to
a device), and Azure specifically reserves the first four addresses
in every subnet (network address, plus three for Azure's internal use)
before the first genuinely usable host address, which is why `4` is
the right number here, not `0` or `1` as you might first guess from
general networking knowledge.

---
---

# PROJECT 6 — The Safe Config Reader — SOLUTION

### `variables.tf`

```hcl
variable "environment" {
  type    = string
  default = "dev"
}

variable "api_key" {
  type      = string
  sensitive = true
  default   = "placeholder-key"
}

variable "vm_size_override" {
  type    = string
  default = null
}
```

### `team-config.json`

```json
{
  "vm_size": "Standard_D2s_v5",
  "backup_retention_days": 14,
  "region": "westeurope"
}
```

### `main.tf`

```hcl
locals {
  file_config = try(jsondecode(file("${path.module}/team-config.json")), {})

  config_file_was_loaded = length(local.file_config) > 0

  config_vm_size = try(local.file_config.vm_size, null)
  config_backup  = try(local.file_config.backup_retention_days, null)
  config_region  = try(local.file_config.region, null)

  resolved_vm_size = coalesce(
    var.vm_size_override,
    local.config_vm_size,
    "Standard_B2s"
  )

  backup_retention_days = coalesce(local.config_backup, 7)
  region                = coalesce(local.config_region, "eastus")

  # md5() applied to a sensitive value inherits the sensitive marking automatically —
  # this is intentional Terraform behavior, not a bug, and it means the output
  # below MUST also be marked sensitive, or Terraform will refuse to let it through.
  api_key_hash = md5(var.api_key)
}

output "resolved_vm_size"        { value = local.resolved_vm_size }
output "backup_retention_days"   { value = local.backup_retention_days }
output "region"                  { value = local.region }
output "config_file_was_loaded"  { value = local.config_file_was_loaded }

output "api_key_hash" {
  value     = local.api_key_hash
  sensitive = true
}
```

### Explainer

**Why does `md5(var.api_key)` need `sensitive = true` on its output — isn't a hash safe to show?**
This is a genuinely good question to have asked yourself, and the
honest answer is: Terraform doesn't know or care that a hash is
one-way and "safe" in a cryptographic sense. Terraform's sensitivity
tracking is mechanical — if a value was *derived from* something
marked sensitive, the result inherits that marking automatically,
regardless of what the derivation actually does to the data. This is
a deliberately conservative design choice on HashiCorp's part: it's
far safer to over-mark things as sensitive (occasionally annoying you
with an output error you have to fix) than to under-mark them and risk
a real secret slipping into a CI/CD log. If you genuinely need to
display a hash and are confident it can't be reversed to leak the
original secret, you'd use `nonsensitive()` explicitly to strip the
marking — but that's a deliberate override you're choosing to make,
not something Terraform assumes for you.

**Why is the `try()` pattern repeated three separate times
(`config_vm_size`, `config_backup`, `config_region`) instead of once?**
Because each key could be missing *independently* — a team's config
file might specify `region` but forget `vm_size`, or vice versa. If
you tried to read all three in one expression and any single key was
missing, wrapping the whole thing in one `try()` would give up on
*all three* values the moment it hit the first missing key, even if
the other two were present and valid. Testing this yourself is
instructive: change `team-config.json` to only contain `{"region":
"westeurope"}` and confirm that `resolved_vm_size` and
`backup_retention_days` still correctly fall back to their defaults
while `region` correctly picks up the file's value — that's proof the
three independent `try()` calls are doing real, necessary work, not
just being overly cautious.

**A limitation worth being upfront about:** this design silently
accepts *any* value type from the JSON file without validation — if
`team-config.json` had `"backup_retention_days": "fourteen"` (a string,
not a number), Terraform likely wouldn't error at this stage, but it
could cause a confusing type-mismatch error later when that value hits
an actual resource argument expecting a number. `try()` protects
against the *key being absent*, not against the *key having the wrong
type*. If robustness against malformed config content matters for your
real use case, you'd want to add explicit type-checking (`can(tonumber(...))`
wrapped in another layer) — genuinely more complexity than this
exercise asked for, but worth knowing it's a real gap.

---
---

## Cross-Project Patterns Worth Noticing Now That You've Seen All Six

1. **`try()` almost always wraps the riskiest, most specific operation**
   (a file read, a map key access) — not the whole surrounding logic.
   The tighter the `try()`, the more precisely you know what failure
   it's actually protecting against.

2. **`coalesce()` chains read as a priority list, top to bottom** —
   if you ever find yourself unsure what order to put arguments in,
   ask "which source should win if multiple are present?" and write
   that one first.

3. **`merge()` order is a policy decision, not a syntax detail** —
   Project 2 was the clearest example. Always ask "if both sides have
   the same key, which one *should* win, and does my code actually
   reflect that?"

4. **Functions that produce lists often need a partner function to
   become usable elsewhere** — `cidrsubnets()` needed `zipmap()` to
   become a `for_each`-ready map; `toset()` needed `tolist()` to
   become indexable again. Watch for this "convert-and-pair" pattern —
   it shows up constantly in real modules.
