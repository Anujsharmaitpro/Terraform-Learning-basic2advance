# Terraform Built-in Functions — A Complete Beginner-to-Pro Guide
### (with Azure / `azurerm` provider examples throughout)

> Source reference: https://developer.hashicorp.com/terraform/language/functions (Terraform v1.15.x docs, verified live)

---

## 0. Before We Start: What Even *Is* a Terraform Function?

Forget Terraform for a second. Think of a function like a kitchen blender.

- You put **raw ingredients** in (the arguments).
- The blender **does something** to them (the logic).
- You get a **finished smoothie** out (the return value).

In Terraform, a function is exactly that: you give it one or more values, it transforms or combines them, and it hands back a new value. You never write the blender's internal mechanics yourself — Terraform ships ~100 of these blenders pre-built. You just call them.

```hcl
max(5, 12, 9)
# => 12
```

That's it. `max` is the function name, `(5, 12, 9)` are the arguments separated by commas, and `12` is what comes back.

### Three rules every beginner must internalize

1. **You cannot write your own functions in plain `.tf` files.** Functions are baked into the Terraform language itself. The only exception is "provider-defined functions" (advanced, covered briefly at the end) — these are functions a *provider* (like the Azure provider) ships for you, called like `provider::terraform::encode_tfvars(...)`.
2. **Functions are not resources.** A function like `upper("hello")` doesn't create anything in Azure. It just computes a value *in memory* while Terraform is figuring out your plan. Resources (`azurerm_resource_group`, `azurerm_storage_account`, etc.) are what actually create cloud infrastructure. Functions are the glue/logic that feeds the right values into those resources.
3. **Functions are pure** — same input always gives same output (with the tiny exception of things like `timestamp()` or `uuid()`, which deliberately return something different every time, and Terraform has special rules around those, explained later).

### How to practice without writing a whole `.tf` file

Terraform has a built-in REPL (an interactive playground) called the **console**. This is the single most underrated learning tool for this topic.

```bash
terraform console
> max(5, 12, 9)
12
> upper("hello")
"HELLO"
> exit
```

**Beginner tip:** Open a terminal right now, `cd` into any folder with a `provider.tf`, run `terraform console`, and try every example in this guide as you read it. You'll learn 10x faster by typing than by reading.

---

## 1. The "Shape" of a Function Call

```
function_name(argument1, argument2, argument3)
```

- Arguments are separated by commas.
- Some functions take a fixed number of arguments (`min(a, b)`).
- Some take a *variable* number (`max(1, 2, 3, 4, 5, ...)`).
- Some take a list/array as their single argument, written with `...` to "spread" it: `max(local.numbers...)`.
- Functions can be **nested** inside each other, just like math: `upper(trimspace(" hello "))` first trims the spaces, then uppercases the result. Terraform evaluates from the inside out, exactly like algebra.

---

## 2. The 10 Categories — Mental Map First

Terraform organizes its ~100 functions into 10 buckets. Memorize this map before diving into details, because once you know *which drawer* a tool lives in, you'll guess function names correctly even before reading docs:

| # | Category | What it's for, in one sentence |
|---|----------|----------------------------------|
| 1 | Numeric | Math: min, max, rounding, logs, powers |
| 2 | String | Text manipulation: case, trimming, splitting, regex |
| 3 | Collection | Working with lists, maps, sets: merging, filtering, sorting |
| 4 | Encoding | Converting between formats: JSON, YAML, Base64, CSV |
| 5 | Filesystem | Reading files and paths from disk |
| 6 | Date and time | Timestamps, adding durations, formatting dates |
| 7 | Hash and crypto | Hashing strings/files (SHA, MD5), encryption helpers |
| 8 | IP network | Calculating subnets and CIDR ranges (huge for Azure VNets!) |
| 9 | Type conversion | Forcing a value into a specific type (string, number, list...) |
| 10 | Terraform-specific | Functions tied to Terraform's own internals (tfvars encoding, etc.) |

We'll now go drawer by drawer. For each, I'll explain the *concept* like you've never coded before, then show a real Azure use case.

---

## 3. Numeric Functions

These do math. If you've used a calculator, you already understand 90% of this category.

| Function | Plain-English meaning |
|---|---|
| `min(a, b, ...)` | smallest number in the list |
| `max(a, b, ...)` | largest number in the list |
| `ceil(x)` | rounds **up** to the nearest whole number |
| `floor(x)` | rounds **down** to the nearest whole number |
| `pow(base, exp)` | base raised to the power of exp (base² = `pow(base, 2)`) |
| `log(x, base)` | logarithm of x in the given base |
| `parseint(str, base)` | reads a string like `"101"` as a number in a given base (e.g. binary) |
| `signum(x)` | tells you if a number is negative (-1), zero (0), or positive (1) |

### Azure example: auto-sizing disk count

Imagine you want to calculate how many data disks an Azure VM needs based on required storage, where each disk is capped at 1TB:

```hcl
variable "required_storage_gb" {
  default = 3500
}

locals {
  # ceil rounds UP so we never under-provision
  disk_count = ceil(var.required_storage_gb / 1024)
}

resource "azurerm_managed_disk" "data" {
  count                = local.disk_count
  name                 = "disk-${count.index}"
  location             = azurerm_resource_group.rg.location
  resource_group_name  = azurerm_resource_group.rg.name
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = 1024
}
```

`ceil(3500/1024)` = `ceil(3.41)` = `4` disks. Without `ceil`, `floor` would have given you `3` and silently left you 400GB short — this is exactly the kind of subtle bug functions help you avoid *if* you pick the right one.

---

## 4. String Functions

This is the category you will use constantly — almost every Azure resource name, tag, or DNS label needs some text massaging (Azure is very strict about lowercase names, length limits, no special characters, etc.).

| Function | Plain-English meaning |
|---|---|
| `upper(str)` / `lower(str)` | ALL CAPS / all lowercase |
| `title(str)` | Capitalizes The First Letter Of Each Word |
| `trim(str, chars)` / `trimspace(str)` | strips unwanted characters/whitespace from both ends |
| `trimprefix(str, prefix)` / `trimsuffix(str, suffix)` | removes a known prefix/suffix |
| `split(sep, str)` | breaks a string into a list using a separator |
| `join(sep, list)` | the opposite of split — glues a list into one string |
| `replace(str, search, replace)` | find-and-replace |
| `format(spec, ...)` | like `printf` — builds a string from a template |
| `formatlist(spec, ...)` | same as `format` but applied across a list, returns a list |
| `substr(str, offset, length)` | grabs part of a string |
| `regex(pattern, str)` / `regexall(pattern, str)` | pattern matching (advanced, regular expressions) |
| `startswith(str, prefix)` / `endswith(str, suffix)` / `strcontains(str, substr)` | true/false checks |
| `chomp(str)` | removes trailing newline |
| `indent(spaces, str)` | adds indentation to multi-line strings (useful for YAML inside templates) |
| `strrev(str)` | reverses a string |
| `templatestring(str, vars)` | renders a string as a template with variables |

### Azure example: building a valid, unique storage account name

Azure Storage Accounts must be **3–24 characters, lowercase letters and numbers only, globally unique**. This is the textbook real-world use case for string functions:

```hcl
variable "project_name" {
  default = "My Awesome Project"
}

locals {
  # "My Awesome Project" -> "myawesomeproject"
  clean_name = lower(replace(var.project_name, " ", ""))

  # Truncate so we have room for a random suffix and stay under 24 chars
  storage_name = "${substr(local.clean_name, 0, 14)}${substr(random_id.suffix.hex, 0, 8)}"
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "azurerm_storage_account" "sa" {
  name                     = local.storage_name
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}
```

### Azure example: `format()` for consistent naming conventions

Many Azure teams enforce naming patterns like `rg-<project>-<env>-<region>`:

```hcl
locals {
  rg_name = format("rg-%s-%s-%s", var.project_name, var.environment, var.location_short)
}
# format("rg-%s-%s-%s", "payments", "prod", "eus") => "rg-payments-prod-eus"
```

---

## 5. Collection Functions

A "collection" is Terraform's word for a **list**, **map**, **set**, or **tuple** — basically, any value that holds multiple items. This category is where Terraform really earns the "infrastructure as *code*" title, because it gives you the equivalent of loops and data transforms without a full programming language.

| Function | Plain-English meaning |
|---|---|
| `length(x)` | how many items (or characters, for a string) |
| `merge(map1, map2, ...)` | combines maps into one (later maps win on key conflicts) |
| `concat(list1, list2, ...)` | glues lists end to end |
| `keys(map)` / `values(map)` | get just the keys, or just the values, from a map |
| `lookup(map, key, default)` | safely get a value, with a fallback if the key is missing |
| `contains(list, value)` | true/false — is this value in the list? |
| `distinct(list)` | removes duplicate entries |
| `flatten(list)` | turns a list-of-lists into one flat list |
| `compact(list)` | removes empty string entries |
| `coalesce(a, b, c, ...)` | returns the first non-null, non-empty value |
| `coalescelist(list1, list2, ...)` | same idea, but for lists |
| `element(list, index)` | get one item by position (wraps around if index is too big) |
| `index(list, value)` | find the position of a value in a list |
| `slice(list, start, end)` | grab a sub-section of a list |
| `sort(list)` | alphabetical sort |
| `reverse(list)` | reverse the order |
| `range(start, limit, step)` | generates a sequence of numbers |
| `zipmap(keys, values)` | builds a map by pairing two lists together |
| `setunion` / `setintersection` / `setsubtract` | classic set-theory operations |
| `setproduct` | all possible combinations of two or more sets |
| `chunklist(list, size)` | splits a list into fixed-size groups |
| `transpose(map)` | swaps keys/values in a map of lists |
| `one(list)` | returns the single element of a one-item list, or errors/null otherwise |
| `alltrue` / `anytrue` | check booleans across a whole collection |
| `sum(list)` | adds up all numbers in a list |
| `matchkeys` | filter one list based on matches in another |

### Azure example: `for_each` + `merge` for consistent tagging

This is one of the most common real patterns in Azure Terraform code — merging "global" tags with "resource-specific" tags:

```hcl
locals {
  common_tags = {
    Environment = "Production"
    ManagedBy   = "Terraform"
    CostCenter  = "12345"
  }
}

resource "azurerm_storage_account" "sa" {
  name                     = local.storage_name
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  # merge() lets the resource-specific tag win if there's a conflict
  tags = merge(local.common_tags, {
    Workload = "Backups"
  })
}
```

### Azure example: deploying multiple subnets with `for_each`

```hcl
variable "subnets" {
  default = {
    web = "10.0.1.0/24"
    app = "10.0.2.0/24"
    db  = "10.0.3.0/24"
  }
}

resource "azurerm_subnet" "subnet" {
  for_each             = var.subnets
  name                 = each.key
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [each.value]
}

output "subnet_names" {
  # keys() pulls just the names out of the map for a tidy output
  value = keys(var.subnets)
}
```

### Azure example: `lookup()` for environment-specific VM sizing

```hcl
variable "vm_sizes" {
  default = {
    dev  = "Standard_B2s"
    prod = "Standard_D4s_v5"
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
  size = lookup(var.vm_sizes, var.environment, "Standard_B1s") # falls back safely
  # ... other required arguments
}
```

---

## 6. Encoding Functions

These convert data **between formats** — most importantly to and from **JSON**, which is exactly what Azure's REST API and many `azurerm` resource arguments expect under the hood (policies, ARM templates, custom scripts).

| Function | Plain-English meaning |
|---|---|
| `jsonencode(value)` | Terraform value → JSON string |
| `jsondecode(str)` | JSON string → Terraform value |
| `yamlencode(value)` / `yamldecode(str)` | same idea, for YAML |
| `base64encode(str)` / `base64decode(str)` | text ↔ Base64 (Azure VM custom data/extensions love Base64) |
| `base64gzip(str)` | compress then Base64-encode (keeps cloud-init scripts small) |
| `csvdecode(str)` | CSV text → list of maps |
| `urlencode(str)` | makes a string safe to use inside a URL |
| `textencodebase64` / `textdecodebase64` | Base64 with explicit character-encoding control |

### Azure example: `jsonencode()` for an Azure Policy definition

Azure Policy rules are literally JSON. Instead of hand-writing fragile JSON strings, build it as native Terraform data and let `jsonencode` handle the formatting:

```hcl
resource "azurerm_policy_definition" "allowed_locations" {
  name         = "allowed-locations"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Allowed locations"

  policy_rule = jsonencode({
    if = {
      not = {
        field = "location"
        in    = ["eastus", "westeurope"]
      }
    }
    then = {
      effect = "deny"
    }
  })
}
```

### Azure example: `base64encode()` for VM custom-data (cloud-init)

Azure VMs expect `custom_data` to be Base64-encoded text:

```hcl
resource "azurerm_linux_virtual_machine" "vm" {
  # ...
  custom_data = base64encode(templatefile("${path.module}/cloud-init.yaml", {
    hostname = "web01"
  }))
}
```

---

## 7. Filesystem Functions

These let Terraform **read files on your local machine** (the machine running `terraform apply`, not Azure itself) at plan time.

| Function | Plain-English meaning |
|---|---|
| `file(path)` | reads a file's contents as plain text |
| `filebase64(path)` | reads a file and returns it Base64-encoded |
| `fileexists(path)` | true/false check |
| `fileset(path, pattern)` | lists files matching a wildcard pattern |
| `templatefile(path, vars)` | reads a file AND substitutes `${variable}` placeholders inside it — extremely common |
| `abspath` / `dirname` / `basename` / `pathexpand` | path manipulation helpers |

### Azure example: `templatefile()` for cloud-init / VM bootstrap scripts

This is one of the highest-value functions in real-world Azure Terraform. Keep your bootstrap script in its own file instead of an ugly inline heredoc:

`cloud-init.yaml`:
```yaml
#cloud-config
hostname: ${hostname}
package_update: true
packages:
  - nginx
```

`main.tf`:
```hcl
resource "azurerm_linux_virtual_machine" "vm" {
  custom_data = base64encode(templatefile("${path.module}/cloud-init.yaml", {
    hostname = "web-${var.environment}"
  }))
  # ...
}
```

`templatefile` reads the file, replaces `${hostname}` with the value you pass in, and gives you back the finished text — then `base64encode` wraps it for Azure.

---

## 8. Date and Time Functions

| Function | Plain-English meaning |
|---|---|
| `timestamp()` | current UTC time, RFC3339 format, evaluated at **apply** time |
| `plantimestamp()` | current UTC time at **plan** time |
| `formatdate(spec, timestamp)` | reformat a timestamp into a custom layout |
| `timeadd(timestamp, duration)` | add a duration (e.g. `"24h"`) to a timestamp |
| `timecmp(t1, t2)` | compares two timestamps: -1, 0, or 1 |

**Important beginner gotcha:** `timestamp()` returns a *different* value every single run, which means any resource argument using it directly will show as "changed" on every `terraform plan`. Best practice is to use it only for things like SAS token expiry, and wrap it with `ignore_changes` in `lifecycle` blocks where appropriate.

### Azure example: expiring a Storage Account SAS token

```hcl
data "azurerm_storage_account_sas" "sas" {
  connection_string = azurerm_storage_account.sa.primary_connection_string
  start              = timestamp()
  expiry             = timeadd(timestamp(), "8760h") # +1 year
  # ... permissions block
}
```

---

## 9. Hash and Crypto Functions

| Function | Plain-English meaning |
|---|---|
| `md5`, `sha1`, `sha256`, `sha512` | hash a string, return hex digest |
| `base64sha256`, `base64sha512` | same hashes, Base64-encoded instead of hex |
| `filemd5`, `filesha256`, `filesha512`, etc. | hash a **file's contents** instead of a literal string |
| `bcrypt(str)` | one-way password hash (Modular Crypt Format) |
| `uuid()` | random UUID, different every apply (like `timestamp`, used carefully) |
| `uuidv5(namespace, name)` | deterministic UUID — same inputs always give the same UUID |
| `rsadecrypt(ciphertext, key)` | decrypts RSA-encrypted data |

### Azure example: trigger redeployment when a script changes (`filesha256`)

A very common Azure pattern: force an Azure Function App or VM extension to redeploy only when the actual script content changes, using a hash as a "fingerprint":

```hcl
resource "azurerm_virtual_machine_extension" "custom_script" {
  name                 = "bootstrap"
  virtual_machine_id   = azurerm_linux_virtual_machine.vm.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.1"

  settings = jsonencode({
    script = base64encode(file("${path.module}/scripts/bootstrap.sh"))
  })

  # If the script content changes, this hash changes, forcing a redeploy
  triggers = {
    script_hash = filesha256("${path.module}/scripts/bootstrap.sh")
  }
}
```

---

## 10. IP Network Functions — Critical for Azure Networking

If you do any Azure VNet/Subnet work, this category is non-negotiable. These functions do CIDR math so you never have to do it by hand.

| Function | Plain-English meaning |
|---|---|
| `cidrsubnet(prefix, newbits, netnum)` | carves a smaller subnet out of a larger CIDR block |
| `cidrsubnets(prefix, newbits...)` | does the above for **multiple** subnets at once, in one call |
| `cidrhost(prefix, hostnum)` | gives you a specific usable IP address inside a CIDR block |
| `cidrnetmask(prefix)` | converts CIDR notation into a dotted subnet mask |

### Azure example: auto-carving subnets from a VNet address space

Instead of hardcoding `10.0.1.0/24`, `10.0.2.0/24`, etc. (error-prone and hard to resize), calculate them:

```hcl
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-main"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

locals {
  # Carve three /24 subnets out of the /16 VNet in one shot
  subnet_cidrs = cidrsubnets("10.0.0.0/16", 8, 8, 8)
  # => ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
}

resource "azurerm_subnet" "web" {
  name                 = "snet-web"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [local.subnet_cidrs[0]]
}

resource "azurerm_subnet" "app" {
  name                 = "snet-app"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [local.subnet_cidrs[1]]
}
```

`cidrsubnet("10.0.0.0/16", 8, 0)` says: "take the /16, add 8 bits to make it a /24, and give me subnet number 0" → `10.0.0.0/24`. This is the textbook way every serious Azure landing-zone module slices address space.

---

## 11. Type Conversion Functions

Terraform is strongly typed internally, even though `.tf` files don't always make that obvious. These functions force a value into a specific shape, or help you handle errors gracefully.

| Function | Plain-English meaning |
|---|---|
| `tostring(x)` | force to string |
| `tonumber(x)` | force to number |
| `tobool(x)` | force to boolean |
| `tolist(x)` | force to list |
| `toset(x)` | force to set (removes duplicates, unordered) |
| `tomap(x)` | force to map |
| `try(expr1, expr2, ...)` | tries each expression in order, returns the first that doesn't error |
| `can(expr)` | returns `true`/`false` instead of erroring — used inside validation rules |
| `sensitive(x)` / `nonsensitive(x)` | marks/unmarks a value as sensitive (hidden in plan/apply output) |
| `issensitive(x)` | checks if a value is currently marked sensitive |
| `type(x)` | returns the type of a value (useful for debugging) |
| `ephemeralasnull(x)` | converts an ephemeral value to `null` (advanced, for write-only/ephemeral secrets workflows) |

### Azure example: `try()` for resilient optional lookups

```hcl
output "first_nic_private_ip" {
  # If the VM somehow has zero NICs, return "N/A" instead of crashing the whole plan
  value = try(azurerm_linux_virtual_machine.vm.private_ip_address, "N/A")
}
```

### Azure example: `sensitive()` to hide secrets from plan output

```hcl
resource "azurerm_key_vault_secret" "db_password" {
  name         = "db-password"
  value        = sensitive(random_password.db.result)
  key_vault_id = azurerm_key_vault.kv.id
}
```

### Azure example: `can()` inside a variable validation block

```hcl
variable "location" {
  type = string
  validation {
    condition     = can(regex("^[a-z]+$", var.location))
    error_message = "Location must be lowercase letters only, e.g. 'eastus'."
  }
}
```

---

## 12. Terraform-Specific Functions (Provider-Defined)

A newer, more advanced category: functions that a **provider** ships, not Terraform core. You call these with the `provider::<local_name>::<function>` syntax. Today the built-in `terraform` provider ships a few:

| Function | Plain-English meaning |
|---|---|
| `provider::terraform::encode_tfvars(obj)` | turns an object into `.tfvars`-file-style text |
| `provider::terraform::decode_tfvars(str)` | parses `.tfvars` file text back into an object |
| `provider::terraform::encode_expr(value)` | turns a value into Terraform expression syntax (as text) |

**Beginner note:** This is a relatively advanced/rare category — most Azure beginners won't touch it for months. Knowing it exists (and that *any other Azure provider, like `azurerm`, could theoretically ship its own functions too*) is enough for now.

---

## 13. Putting It All Together — A Realistic Mini Azure Module

This stitches together functions from nearly every category, to show how they actually compose in real code:

```hcl
variable "project_name" { default = "Payments App" }
variable "environment"  { default = "prod" }

locals {
  # STRING functions: build a clean, valid name
  name_clean = lower(replace(var.project_name, " ", "-"))

  # COLLECTION functions: merge default + custom tags
  tags = merge(
    { Environment = var.environment, ManagedBy = "Terraform" },
    { Project = local.name_clean }
  )

  # IP NETWORK functions: carve subnets automatically
  subnet_cidrs = cidrsubnets("10.10.0.0/16", 8, 8)

  # NUMERIC function: size disks safely
  disk_count = ceil(var.required_storage_gb / 1024)
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-${local.name_clean}-${var.environment}"
  location = "eastus"
  tags     = local.tags
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${local.name_clean}"
  address_space       = ["10.10.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  count                = length(local.subnet_cidrs)
  name                 = "snet-${count.index}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [local.subnet_cidrs[count.index]]
}
```

Walk through it once more slowly: `replace`/`lower` (string) clean the name → `merge` (collection) builds tags → `cidrsubnets` (IP network) carves address space → `ceil` (numeric) sizes disks → `length` (collection) drives the `count` loop. That's the real job of functions: **plumbing data correctly between your inputs and your Azure resources.**

---

## 14. Common Beginner Mistakes (Save Yourself the Debugging Pain)

1. **Confusing `format()` placeholders.** `%s` is for strings, `%d` for integers — mixing them up throws a runtime error.
2. **Forgetting `merge()` is "later wins."** `merge(a, b)` — if both have a `Name` key, `b`'s value wins. Order matters.
3. **Using `timestamp()`/`uuid()` directly on a resource argument** and being surprised every `plan` shows a diff. Wrap the resource in a `lifecycle { ignore_changes = [...] }` block if you don't want constant drift.
4. **Treating `try()` as a generic try/catch.** It only catches *expression errors* (like a missing map key or invalid index) — it won't catch problems with actual Azure API calls.
5. **`length()` on a number.** It only works on collections and strings — `length(5)` errors. Always check the type first.
6. **Index out of range with `element()` vs `[]`.** `element()` wraps around (modulo) if your index is too big; plain `list[index]` throws an error instead. Pick the one you actually want.

---

## 15. Your Practice Plan

1. Open `terraform console` and run every example from sections 3–11 by hand.
2. Build the "mini Azure module" in section 13 in a real (even empty/sandbox) Azure subscription, changing `required_storage_gb` and watching `disk_count` recalculate.
3. Break things on purpose: pass a string into `ceil()`, or call `cidrsubnet` with bits that overflow the address space, and read the error messages closely — Terraform's function errors are usually very descriptive.
4. Once comfortable, go re-read the original docs page (https://developer.hashicorp.com/terraform/language/functions) — it will now read like a reference card instead of a wall of jargon.

---

*This guide reflects the function list as published in the official HashiCorp documentation for Terraform v1.15.x (the current latest version as of this writing). Always double-check the live docs for any new functions added in future releases, since this page is actively maintained.*
