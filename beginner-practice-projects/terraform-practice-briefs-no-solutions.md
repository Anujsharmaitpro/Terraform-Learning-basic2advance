# Terraform Functions — Practice Project Briefs
### No solutions included. That's intentional.

The only rule: write every line yourself. If you copy code from anywhere,
you are only cheating your own understanding.

---

## How to use these briefs

Each project has:
- **The scenario** — a realistic business problem
- **Your task** — what you need to build
- **Functions to use** — the tools you must use (you figure out how)
- **Acceptance criteria** — how you know it works correctly
- **Hints** — nudges if you are genuinely stuck (not answers)
- **Stretch goals** — harder challenges once the base is working

---
---

# PROJECT 1 — The Name Cleaner
**Difficulty: Beginner | No Azure account needed**
**Concepts: `lower`, `replace`, `trimspace`, `substr`, `format`**

---

### The Scenario

Your company has a shared Azure subscription.
Every team creates resources by running Terraform and passing their
project name as a variable. The problem: people type names like
`"HR & Payroll System "`, `"AZURE INFRA v2!"`, `"my project"` —
all of which violate Azure naming rules in different ways.

Your job is to build a locals-only module that accepts any messy
project name and produces four clean, Azure-valid output values.

---

### Your Task

Create a `main.tf` and `variables.tf` that:

1. Accepts one variable: `project_name` (string)
2. Computes four locals using string functions
3. Produces four outputs showing the cleaned values

The four outputs must be:

| Output name | What it should contain | Example (input: `"HR & Payroll System "`) |
|---|---|---|
| `resource_group_name` | `rg-<cleaned>` format, lowercase, hyphens for spaces, no specials | `rg-hr-payroll-system` |
| `storage_account_name` | lowercase, no hyphens or specials, max 20 chars | `hrpayrollsystem` |
| `key_vault_name` | `kv-<cleaned>`, max 24 chars total | `kv-hr-payroll-system` |
| `vm_name` | `vm-<cleaned>`, max 15 chars total (Windows VM limit) | `vm-hr-payroll-s` |

---

### Acceptance Criteria

Run `terraform plan` with each of these inputs and verify every
output looks correct — no capitals, no spaces, no special characters,
no length violations:

```bash
terraform plan -var='project_name=HR & Payroll System '
terraform plan -var='project_name=AZURE INFRA v2!!'
terraform plan -var='project_name=my project'
terraform plan -var='project_name=A Very Long Project Name That Exceeds All Azure Limits Easily'
```

---

### Hints (read only if stuck for 20+ minutes)

- Hint 1: Functions can be nested inside each other. The output of one
  becomes the input of the next. Think about what order the cleaning
  steps need to happen in.

- Hint 2: `trimspace()` only strips from the outside edges. Spaces
  inside the string need a different function.

- Hint 3: `substr(string, offset, length)` — the offset is where to
  start (0 = beginning), the length is how many characters to keep.

- Hint 4: For the `replace` pattern that strips special characters,
  look into how Terraform's `replace()` accepts a regex pattern
  when the search string is wrapped in `/forward-slashes/`.

---

### Stretch Goals

- Add a second variable `environment` and include it in the names
  (e.g. `rg-hr-payroll-system-prod`)
- Add a `validation` block to the variable that rejects any input
  shorter than 3 characters
- What happens to `storage_account_name` if the input is only 2 chars?
  Handle that edge case.

---
---

# PROJECT 2 — The Tag Enforcer
**Difficulty: Beginner | No Azure account needed**
**Concepts: `merge`, `lookup`, `keys`, `values`, `length`**

---

### The Scenario

Your platform team has a policy: every Azure resource deployed via
Terraform must carry five mandatory tags. Individual teams can add
their own tags on top, but they cannot remove or skip the mandatory ones.

Your module must enforce this.

---

### Your Task

Create a module with two variables:

- `environment` — one of: `dev`, `staging`, `prod`
- `team_tags` — a `map(string)` of any extra tags the team wants to add

The mandatory tags that must always appear are:

```
ManagedBy   = "Terraform"
Environment = <value of the environment variable>
CostCenter  = <looked up from a map you define internally>
Department  = "Engineering"
Compliance  = "Required"
```

Your cost center map (define this as a local, not a variable):
```
dev     -> "CC-100"
staging -> "CC-200"
prod    -> "CC-300"
```

Produce these outputs:
1. `final_tags` — the merged result of mandatory + team tags
2. `total_tag_count` — how many tags exist in the final set
3. `tag_keys` — a list of just the tag names

---

### Acceptance Criteria

```bash
# Test 1: basic run
terraform plan -var='environment=prod' -var='team_tags={"Workload":"Payments"}'
# mandatory tags present? cost center = CC-300? team tag also present?

# Test 2: team tries to override a mandatory tag
terraform plan -var='environment=dev' -var='team_tags={"ManagedBy":"Manual","Workload":"HR"}'
# What happens to ManagedBy? Does the mandatory value survive or does the team win?
# Is that the right behavior? If not, how would you fix it?

# Test 3: unknown environment
terraform plan -var='environment=uat' -var='team_tags={}'
# What happens to CostCenter? Does it error or fall back gracefully?
```

---

### Hints

- Hint 1: `merge(map1, map2)` — the second argument's values win on
  key conflicts. Think carefully about which argument order enforces
  the mandatory tags correctly.

- Hint 2: `lookup(map, key, default)` — the third argument is what
  gets returned if the key doesn't exist in the map.

- Hint 3: `length()` works on maps too, not just lists.

---

### Stretch Goals

- Add a `validation` block that rejects environments not in the
  allowed list, with a clear error message
- Add a fifth output `missing_required_tags` that lists any mandatory
  tag keys that are somehow absent from the final result
  (this is harder — think about `keys()` and set operations)

---
---

# PROJECT 3 — The Environment Switcher
**Difficulty: Beginner-Intermediate | No Azure account needed**
**Concepts: `coalesce`, `try`, `lookup`, conditional expression `? :`**

---

### The Scenario

Your team deploys the same application to three environments.
Each environment needs different-sized infrastructure.
There is also a config file on disk that can optionally override
certain settings. And some settings might not exist at all —
the code must survive that gracefully.

---

### Your Task

Create a module that reads an environment variable and produces
the correct configuration values for that environment, with
layered fallbacks using `coalesce` and `try`.

**Configuration matrix** (implement this as locals, not hardcoded per-resource):

| Setting | dev | staging | prod |
|---|---|---|---|
| vm_size | Standard_B2s | Standard_D2s_v5 | Standard_D4s_v5 |
| disk_size_gb | 64 | 128 | 512 |
| replica_count | 1 | 2 | 3 |
| backup_enabled | false | false | true |

**Layered override logic** (implement for `vm_size` only):

Priority order (highest to lowest):
1. `var.vm_size_override` — if the caller passed an explicit size, use it
2. Value from `config.json` file on disk — if the file exists and has `vm_size`
3. The environment-appropriate size from your configuration matrix
4. `"Standard_B1s"` — the absolute last-resort fallback

**Variables you need:**
- `environment` (string, validated to only accept dev/staging/prod)
- `vm_size_override` (string, nullable, default null)

**Outputs:**
- `resolved_vm_size` — the final vm size after all fallbacks
- `disk_size_gb`
- `replica_count`
- `backup_enabled`
- `config_file_loaded` — true or false: did the file exist and parse successfully?

---

### Acceptance Criteria

```bash
# Test 1: no file, no override — should use the matrix
terraform plan -var="environment=dev"
terraform plan -var="environment=prod"

# Test 2: explicit override beats everything
terraform plan -var="environment=dev" -var="vm_size_override=Standard_F4s_v2"

# Test 3: create a config.json with {"vm_size":"Standard_E2s_v5"} — should it win?
# (depends on your priority order — check your implementation)

# Test 4: bad JSON in config.json — should not crash
echo "INVALID{JSON" > config.json
terraform plan -var="environment=dev"

# Test 5: validation — should reject "production" as an environment name
terraform plan -var="environment=production"
```

---

### Hints

- Hint 1: `try(expression, fallback)` — if the expression errors for
  any reason, the fallback is returned instead. Useful when a file
  might not exist or a key might not be present.

- Hint 2: `coalesce(a, b, c)` skips `null` and `""` and returns
  the first real value. All four values in your priority chain
  need to be the same type.

- Hint 3: `jsondecode(file("path"))` can be wrapped in `try()`
  as one unit if you want to catch both file-not-found and
  invalid-JSON errors in one go.

- Hint 4: For the conditional (ternary), the syntax is:
  `condition ? value_if_true : value_if_false`

---

### Stretch Goals

- Implement the same layered-override logic for `disk_size_gb` too
- Add an output `override_source` that says which source actually
  won: `"explicit_override"`, `"config_file"`, `"env_matrix"`, or `"fallback"`
- What if someone passes `vm_size_override = ""` (empty string)?
  Does `coalesce` handle it correctly? Test it.

---
---

# PROJECT 4 — The NSG Port Manager
**Difficulty: Intermediate | ⚠️ Deploys to Azure — NSG + RG are free**
**Concepts: `split`, `join`, `toset`, `concat`, `length`, `dynamic` block**

---

### The Scenario

Your security team manages Network Security Groups via Terraform.
Instead of writing one `security_rule` block per port (which means
copy-pasting and maintaining duplicate code), they want to pass
a comma-separated string of ports and have Terraform generate
the rules automatically.

---

### Your Task

Build a Terraform module that:

1. Accepts `allowed_ports` as a single comma-separated string variable
   (e.g. `"80,443,22,3306"`)
2. Accepts `extra_ports` as a `list(string)` variable for any additions
3. Deploys one `azurerm_resource_group` and one `azurerm_network_security_group`
4. Generates one NSG inbound allow rule per unique port — using a `dynamic` block
5. Produces a readable output summarizing what was deployed

**Rules the module must follow:**
- Duplicate ports (same port in both `allowed_ports` and `extra_ports`)
  must produce only ONE rule — not two
- Each rule must have a unique priority number — no two rules can share a priority
- The NSG tag `AllowedPorts` must contain a human-readable joined string
  of all ports (e.g. `"22, 80, 443, 3306"`)

---

### Acceptance Criteria

```bash
# After apply:
# - NSG exists in Azure portal with correct number of rules
# - No two rules have the same priority
# - No duplicate rules even if port appeared in both inputs

terraform apply -var="allowed_ports=80,443"
# Should create 2 rules

terraform apply -var="allowed_ports=80,443,22" -var='extra_ports=["3306","8080"]'
# Should create 5 rules

terraform apply -var="allowed_ports=80,443" -var='extra_ports=["80","8080"]'
# Should create 3 rules (not 4 — 80 is a duplicate)

terraform destroy
```

---

### Hints

- Hint 1: `split(",", string)` turns `"80,443,22"` into `["80","443","22"]`

- Hint 2: `concat(list1, list2)` combines two lists end to end —
  duplicates are kept at this stage

- Hint 3: `toset()` removes duplicates — but the order is not guaranteed
  after this. To assign sequential priorities, you may need to convert
  back to a list with `tolist()` and use the index

- Hint 4: A `dynamic` block loops over a collection and produces one
  copy of its inner `content {}` block per item. Look up the syntax
  for `dynamic` in the Terraform docs — it is not the same as `for_each`
  on a resource.

- Hint 5: For unique priorities, think about how `index()` or a
  `for` expression with `idx` could help you assign `100`, `101`, `102`...

---

### Stretch Goals

- Add a variable `denied_ports` that creates Deny rules instead of Allow rules
- Add validation that rejects port numbers outside the valid TCP range (1-65535)
- Add an output `rule_count` that shows how many rules were actually created

---
---

# PROJECT 5 — The Network Calculator
**Difficulty: Intermediate | ⚠️ Deploys to Azure — VNet + Subnets are free**
**Concepts: `cidrsubnets`, `cidrsubnet`, `zipmap`, `length`, `for_each`**

---

### The Scenario

Your networking team manages Azure VNets. Every time they need a new
environment, they hardcode subnet CIDRs by hand — which leads to
IP overlaps between environments (breaking VNet peering), and
painful rework when the address space needs to change.

You will build a module that calculates subnets mathematically.

---

### Your Task

Build a module that:

1. Accepts the parent VNet CIDR as a variable (e.g. `"10.0.0.0/16"`)
2. Accepts subnet names as a `list(string)` variable
3. Automatically carves one subnet per name from the parent block
4. Deploys the VNet and all subnets to Azure
5. Outputs a map showing each subnet name and its calculated CIDR

**Rules:**
- Subnets must be `/24` slices of a `/16` parent
- No subnet CIDRs should be hardcoded — all must come from a function
- Adding a new name to the `subnet_names` variable must create a new
  subnet automatically, with no other changes required

---

### Acceptance Criteria

```bash
# Base deployment
terraform apply -var='subnet_names=["web","app","db"]'
# Output should show: web=10.0.0.0/24, app=10.0.1.0/24, db=10.0.2.0/24

# Add a subnet — only one new resource should be created, none modified
terraform apply -var='subnet_names=["web","app","db","management"]'

# Change the parent CIDR — all subnet CIDRs should recalculate accordingly
terraform apply -var='vnet_cidr=172.16.0.0/16' -var='subnet_names=["web","app","db"]'

terraform destroy
```

---

### Hints

- Hint 1: `cidrsubnets(parent, newbits, newbits, newbits...)` — you need
  one `newbits` argument per subnet. To get /24 from a /16, the newbits
  value is `8` (because /16 + 8 = /24). How do you pass a variable number
  of `8`s based on the length of `subnet_names`?

- Hint 2: After calculating the CIDRs, you have two separate lists:
  subnet names and subnet CIDRs. `zipmap(keys_list, values_list)`
  pairs them into one map.

- Hint 3: `for_each` on a resource requires a map or a set.
  The map from `zipmap` feeds directly into `for_each`.
  Then `each.key` is the subnet name, `each.value` is the CIDR.

- Hint 4: Generating a list of `8`s with the right count —
  think about what `[for i in range(length(var.subnet_names)) : 8]`
  produces, and whether that can be spread with `...`

---

### Stretch Goals

- Add a second VNet in a different region with a different address space,
  ensure no subnet CIDRs overlap between the two VNets
- Add an output `first_usable_ip_per_subnet` using `cidrhost()` —
  Azure reserves the first 4 IPs in every subnet, so the first
  usable host is index 4, not 0

---
---

# PROJECT 6 — The Safe Config Reader
**Difficulty: Intermediate | No Azure account needed**
**Concepts: `try`, `coalesce`, `sensitive`, `jsondecode`, `file`**

---

### The Scenario

Your module is used by many different teams. Some teams provide a
`team-config.json` file with their preferences. Some don't.
Some provide it but with missing keys. Some accidentally write
invalid JSON. Your module must survive all of these situations
without crashing, and must never expose secrets in plan output.

---

### Your Task

Build a module that:

1. Tries to read `team-config.json` from the module directory —
   if it's missing or broken, continues without crashing
2. Reads `vm_size`, `backup_retention_days`, and `region` from
   the file if they exist
3. Falls back to sensible defaults for any missing values
4. Accepts a sensitive `api_key` variable that must NEVER appear
   in plan or apply terminal output
5. Accepts an optional `vm_size_override` variable
   (the override should beat the config file value)

**Expected fallback chain for `vm_size`:**
```
vm_size_override variable
    → vm_size from config file
        → "Standard_B2s" (hardcoded last resort)
```

**Outputs to produce:**
- `resolved_vm_size`
- `backup_retention_days`
- `region`
- `config_file_was_loaded` (true/false)
- `api_key_hash` — the MD5 hash of the key, so you can verify it
  was read correctly without exposing the value itself

---

### Acceptance Criteria

```bash
# Test 1: config.json present and valid
terraform plan

# Test 2: config.json deleted — should still work, all fallbacks apply
mv team-config.json team-config.json.bak
terraform plan

# Test 3: config.json has invalid JSON
echo "NOT{VALID" > team-config.json
terraform plan  # must not crash

# Test 4: config.json present but missing some keys
echo '{"region": "westeurope"}' > team-config.json
terraform plan  # vm_size and backup_retention should fall back to defaults

# Test 5: api_key must never appear as plaintext
terraform plan -var="api_key=my-top-secret"
# Search through entire output — "my-top-secret" must not appear anywhere
```

---

### Hints

- Hint 1: `try(expr1, expr2)` — wrap the entire `jsondecode(file(...))` call
  in one `try()` to handle both file-not-found and bad-JSON in one go.

- Hint 2: After loading the file, each key access on the result can
  also be wrapped in `try()` individually, with `null` as the fallback.
  That way `coalesce()` can skip the nulls.

- Hint 3: `sensitive()` marks a value — but if an output references
  that value, the output block also needs `sensitive = true` explicitly.

- Hint 4: `md5(value)` returns a hash string. But `md5(sensitive_value)`
  — does the result inherit the sensitive marking? Test it and see.

---

### Stretch Goals

- Add a check: if `api_key` is shorter than 16 characters, produce a
  warning (you can't actually `print` in Terraform, but you can
  make an output called `api_key_warning` that surfaces a message)
- Make `config_file_was_loaded` show not just true/false but also
  which keys were successfully loaded vs which fell back to defaults

---
---

## General Rules for All Projects

**Do not look up solutions.** If you are stuck, re-read the hints.
If hints are not enough, go back to `terraform console` and experiment
with just the function in isolation until you understand what it returns.

**Test one function at a time.** Do not write the whole file and then
run it. Write one local, check its output, add the next one.

**Break things deliberately.** After each project works, try to break it
in a specific way and predict the exact error message before running.
This is how you learn to debug, not just how to build.

**`terraform console` is always available.** Any expression you can
write in a `locals` block, you can test in `terraform console` first.
Use it constantly.
