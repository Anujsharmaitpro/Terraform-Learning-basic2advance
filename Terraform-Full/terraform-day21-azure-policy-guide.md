# Terraform + Azure Policy — Governance as Code
## Deep-Dive Learning Guide — Day 21 / 28 Days of Easy Terraform
### Beginner-First Edition | PowerShell Throughout

---

## Before You Start

This is Day 21. You've covered fundamentals, expressions/functions,
data sources, several mini projects, provisioners (Day 19), and
modules (Day 20).

Today's topic is **Azure Policy** — a governance mechanism that
enforces rules across an entire subscription, not just within a single
Terraform run. The source video for this guide is genuinely useful
because it shows a real, extended debugging session: the instructor
spends roughly 20 minutes fighting hand-typed JSON syntax errors
before eventually reaching for `jsonencode()`. Rather than replicate
that trial-and-error verbatim, this guide explains the *correct*
approach from the start — building the policy rule as a native HCL
object and letting `jsonencode()` convert it — and explains exactly
why the manual-JSON approach was so fragile, so you understand the
"why," not just the fixed code.

I'll also flag a few things worth knowing that the video doesn't fully
resolve: a resource-naming deprecation you should be aware of, a more
correct fix for the "reference a variable inside the policy" problem
the instructor explicitly asked viewers to solve, and the real
distinction between Azure Policy enforcement and Terraform-level
variable validation (Day 12) — they solve different problems and
aren't substitutes for each other.

---

## Table of Contents

1. What Is Azure Policy? (And How It Differs From What You've Built So Far)
2. Why "Policy as Code" Matters
3. The Three Policies This Project Builds
4. The Subscription Data Source
5. Anatomy of a Real Azure Policy Rule (Correct JSON Structure)
6. Why Hand-Typed JSON Inside HCL Is Fragile — And the Actual Fix
7. Building Policy 1 — Mandatory Tags (Done Correctly)
8. Building Policy 2 — Allowed Locations
9. Building Policy 3 — Allowed VM Sizes
10. The Policy Definition Resource — Fields Explained
11. Policy Assignment — A Deprecation You Should Know About
12. Why `var.allowed_tags[0]` Failed — Sets vs Lists Revisited
13. `jsonencode()` vs `jsondecode()` — Clearing Up the Mix-up
14. Single Quotes Are Not Valid HCL Strings
15. Testing — Triggering a Policy Violation on Purpose
16. The 24-Hour Compliance Evaluation Cycle
17. `-target` — What It Does and Why It's Not a Daily-Use Flag
18. Azure Policy vs Terraform Variable Validation — Not the Same Tool
19. Parameterized Policies — A Design Choice Worth Knowing About
20. Complete Corrected Working Code
21. Common Mistakes
22. Practice Exercises
23. Summary Reference

---

## 1. What Is Azure Policy? (And How It Differs From What You've Built So Far)

Every prior project in this series used Terraform to *create*
resources. Azure Policy is different: it's a governance service that
evaluates resources — however they were created, whether by your
Terraform code, someone else's Terraform, the Azure Portal, or the CLI
— against a rule, and can **deny** the operation outright if it
violates that rule.

This is a genuinely important distinction. A Day 12 `validation` block
on a Terraform variable only stops *your own* `terraform apply` run
from proceeding with a bad value. It has zero effect on a colleague
who creates a resource manually in the Portal, or through a different
tool entirely. Azure Policy operates at the Azure Resource Manager
(ARM) control-plane level — it applies regardless of which tool
initiated the request. Section 18 returns to this distinction in more
detail, because conflating the two is a common misunderstanding.

---

## 2. Why "Policy as Code" Matters

Defining policies through Terraform (rather than manually in the
Azure Portal) gives you the same benefits Day 1 established for
infrastructure generally: version-controlled history of what rules
exist and when they changed, code review before a new restriction goes
live, and the ability to apply identical governance rules consistently
across multiple subscriptions or environments by reusing the same
Terraform code.

---

## 3. The Three Policies This Project Builds

- **Allowed locations** — resources may only be created in specific
  Azure regions (East US, West US in this project)
- **Mandatory tags** — every resource must carry certain tags (this
  project uses `Department` and `Project`)
- **Allowed VM sizes** — virtual machines may only use specific SKUs,
  for cost control

All three use the **Deny** effect: a resource that violates the rule
is rejected outright at creation time, not merely flagged for later review.

---

## 4. The Subscription Data Source

Policy assignments need to reference the subscription they apply to.
This is a straightforward data source, connecting directly to the Day
13 pattern of reading existing information rather than creating it:

```hcl
data "azurerm_subscription" "current" {}
```

No arguments are required — it simply returns details about whichever
subscription your current authentication context (Service Principal
or `az login` session) is scoped to. Relevant attributes:
`data.azurerm_subscription.current.id` and `.subscription_id`.

---

## 5. Anatomy of a Real Azure Policy Rule (Correct JSON Structure)

Before writing any Terraform, it helps to know what a *correct* Azure
Policy rule actually looks like as JSON — independent of Terraform
entirely. This is the structure Azure's policy engine actually expects:

```json
{
  "if": {
    "field": "location",
    "notIn": ["eastus", "westus"]
  },
  "then": {
    "effect": "deny"
  }
}
```

Key things to get exactly right, because Azure Policy's JSON syntax is
case-sensitive and unforgiving of small mistakes:

- The condition keywords are `notIn`, `in`, `exists`, `allOf`, `anyOf`
  — camelCase, exactly as shown. Not "not in", not "any of" with a
  space.
- `field` references a resource property. For a top-level property
  like the resource's region, it's just `"location"`. For a specific
  tag, the syntax is `"tags['TagName']"` — bracket notation with the
  tag name inside single quotes *within the JSON string itself* (this
  is JSON content, not HCL — the single-quote rule from Section 14
  doesn't apply here, because this text lives inside a JSON string
  value, not as an HCL string literal).
- For "does this tag exist," the comparator is `"exists"`, with a
  value of `"false"` (checking that it does *not* exist) or `"true"`.
- Multiple conditions where *any one* being true should trigger the
  effect use `"anyOf"`, containing an array of condition objects. If
  *all* conditions must be true, use `"allOf"` instead.

For the mandatory-tags policy specifically, checking two tags looks like this:

```json
{
  "if": {
    "anyOf": [
      { "field": "tags['Department']", "exists": "false" },
      { "field": "tags['Project']", "exists": "false" }
    ]
  },
  "then": {
    "effect": "deny"
  }
}
```

This is exactly what the video was trying to hand-type as raw text
inside HCL, and it's a lot of nested brackets and commas to get right
by hand — which is precisely why it went wrong repeatedly.

---

## 6. Why Hand-Typed JSON Inside HCL Is Fragile — And the Actual Fix

The video's approach was to write the policy rule as a raw JSON string
literal (using HCL's heredoc syntax, `<<-EOF ... EOF`) directly inside
the resource block. Every open brace needs a matching close brace in
the right place, every value needs a comma except the last one in a
list, and there's no IDE-level syntax checking of JSON content sitting
inside an HCL heredoc — mismatched brackets only surface as a
provider-level parse error at `terraform plan` time, with an
unhelpful message and no line number pointing at the actual problem.
That's exactly the multi-attempt debugging shown in the transcript.

**The actual fix, and the correct approach from the start:** build the
policy rule as a native HCL object (a map of maps, using ordinary HCL
syntax with `=` and no manual bracket-counting for JSON), then wrap
the *entire* object in the `jsonencode()` function, which Terraform
converts to valid JSON automatically:

```hcl
policy_rule = jsonencode({
  if = {
    field = "location"
    notIn = var.allowed_locations
  }
  then = {
    effect = "deny"
  }
})
```

This is functionally identical to the raw JSON from Section 5, but
written in familiar HCL — the same syntax you've used in every
`variable`, `locals`, and `resource` block throughout this entire
series. Terraform validates the HCL structure at parse time (catching
mismatched braces immediately, with an actual line number), and
`jsonencode()` guarantees syntactically correct output JSON every
single time — no manually counting brackets, no worrying about
trailing commas.

This also solves the exact problem the video explicitly asked viewers
to help solve: referencing a Terraform variable *inside* the policy
rule. Because the policy rule is now genuine HCL rather than a string
of pre-written JSON text, `var.allowed_locations` is just a normal HCL
expression — no string interpolation gymnastics required at all.

---

## 7. Building Policy 1 — Mandatory Tags (Done Correctly)

The video ultimately gave up trying to reference a variable-driven
list of tags and hardcoded two `anyOf` entries by hand. Since the
underlying blocker (JSON-in-a-string interpolation) is removed by
using `jsonencode()`, the fully dynamic version — supporting any
number of mandatory tags without manual duplication — is actually
straightforward, using a `for` expression exactly like Day 8's pattern:

```hcl
variable "mandatory_tags" {
  type        = list(string)
  description = "Tags every resource must have"
  default     = ["Department", "Project"]
}

resource "azurerm_policy_definition" "mandatory_tags" {
  name         = "mandatory-tags-policy"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Mandatory Tags Policy"

  policy_rule = jsonencode({
    if = {
      anyOf = [
        for tag in var.mandatory_tags : {
          field  = "tags['${tag}']"
          exists = "false"
        }
      ]
    }
    then = {
      effect = "deny"
    }
  })
}
```

Note `mandatory_tags` is declared as `list(string)`, not `set(string)`
— Section 12 explains exactly why that distinction matters here.

---

## 8. Building Policy 2 — Allowed Locations

```hcl
variable "allowed_locations" {
  type        = list(string)
  description = "Azure regions resources are permitted to be created in"
  default     = ["eastus", "westus"]
}

resource "azurerm_policy_definition" "allowed_locations" {
  name         = "allowed-locations-policy"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Allowed Locations Policy"

  policy_rule = jsonencode({
    if = {
      field = "location"
      notIn = var.allowed_locations
    }
    then = {
      effect = "deny"
    }
  })
}
```

Note: Azure region names in policy definitions are typically written
without spaces or capitals — `"eastus"`, not `"East US"`. This is a
detail worth checking against the current Azure region name list if
your `terraform apply` reports a resource as non-compliant when you
expected it to pass.

---

## 9. Building Policy 3 — Allowed VM Sizes

```hcl
variable "allowed_vm_sizes" {
  type        = list(string)
  description = "VM SKUs permitted for cost control"
  default     = ["Standard_B2s", "Standard_B2ms"]
}

resource "azurerm_policy_definition" "allowed_vm_sizes" {
  name         = "allowed-vm-sizes-policy"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Allowed VM Sizes Policy"

  policy_rule = jsonencode({
    if = {
      field = "Microsoft.Compute/virtualMachines/sku.name"
      notIn = var.allowed_vm_sizes
    }
    then = {
      effect = "deny"
    }
  })
}
```

The `field` value here is a resource-type-specific property path —
`Microsoft.Compute/virtualMachines/sku.name` targets the VM size field
specifically on the virtual machine resource type, rather than a
generic top-level property like `location`.

---

## 10. The Policy Definition Resource — Fields Explained

- `name` — the internal resource name (used in the resource ID)
- `policy_type` — `"Custom"` for definitions you write yourself, as
  opposed to `"BuiltIn"` definitions Microsoft already provides for
  extremely common rules (many "allowed locations"/"allowed SKUs"
  style policies already exist as built-ins — worth checking the
  built-in policy library before writing a custom one, since reusing
  a built-in avoids maintaining your own JSON rule at all)
- `mode` — controls which resource types get evaluated. `"All"`
  evaluates every resource type, including resource groups and
  subscriptions themselves. `"Indexed"` restricts evaluation to
  resource types that support tags and location, which can reduce
  evaluation overhead for large policy sets — but I'd recommend
  confirming current behavior for resource-group-level evaluation in
  Microsoft's documentation before relying on `"Indexed"` in a
  scenario (like this project's) where you specifically want the
  resource group itself checked, since documented behavior here has
  shifted across API versions. Using `"All"` is the safer, unambiguous
  choice while you're learning.
- `display_name` — human-readable name shown in the Azure Portal
- `policy_rule` — the `jsonencode()`-wrapped condition covered above

---

## 11. Policy Assignment — A Deprecation You Should Know About

The video used a generically named `azurerm_policy_assignment`
resource. Worth flagging directly, since this exact pattern has come
up repeatedly across this series (Day 17's App Service resources, Day
20's AKS identity guidance): the AzureRM provider has moved toward
**scope-specific** policy assignment resources rather than one generic
type. For a subscription-level assignment — which is what this project
needs — the current, non-deprecated resource is:

```hcl
resource "azurerm_subscription_policy_assignment" "mandatory_tags" {
  name                 = "mandatory-tags-assignment"
  policy_definition_id = azurerm_policy_definition.mandatory_tags.id
  subscription_id      = data.azurerm_subscription.current.id
}

resource "azurerm_subscription_policy_assignment" "allowed_locations" {
  name                 = "allowed-locations-assignment"
  policy_definition_id = azurerm_policy_definition.allowed_locations.id
  subscription_id      = data.azurerm_subscription.current.id
}

resource "azurerm_subscription_policy_assignment" "allowed_vm_sizes" {
  name                 = "allowed-vm-sizes-assignment"
  policy_definition_id = azurerm_policy_definition.allowed_vm_sizes.id
  subscription_id      = data.azurerm_subscription.current.id
}
```

There are matching scope-specific resources for other assignment
levels too — `azurerm_resource_group_policy_assignment`,
`azurerm_management_group_policy_assignment`, and
`azurerm_resource_policy_assignment` for a single specific resource —
useful if you later want to scope one of these policies more narrowly
than the whole subscription.

---

## 12. Why `var.allowed_tags[0]` Failed — Sets vs Lists Revisited

The video declared the mandatory-tags variable as a `set(string)` and
then tried to access it by numeric index (`var.allowed_tags[0]`),
which failed. This is exactly the Day 7 and Day 12 lesson resurfacing:
**sets have no inherent order and cannot be accessed by numeric
index** — only lists can. The instructor's own earlier material in
this series already covers this, which makes it a good reminder that
choosing the right type constraint up front avoids this entire class
of error. Section 7's solution sidesteps the problem two ways at once:
using `list(string)` instead of `set(string)`, and using a `for`
expression instead of manual indexing at all — so it works correctly
regardless of type or however many tags you configure.

---

## 13. `jsonencode()` vs `jsondecode()` — Clearing Up the Mix-up

The video's spoken narration at one point says "JSON decode" while
describing what is actually the `jsonencode()` function — worth being
precise here since these are opposite operations:

- `jsonencode(hcl_value)` — takes an HCL value (object, list, string,
  number) and converts it **into** a JSON-formatted string. This is
  what's needed for `policy_rule`, because Azure's API expects the
  rule as a JSON string.
- `jsondecode(json_string)` — the reverse: takes a JSON-formatted
  string and parses it **into** an HCL value you can work with. This
  was covered back in Day 12's file-handling assignment, for reading
  external JSON config files into Terraform.

For `policy_rule`, you always want `jsonencode()` — you're going from
HCL *to* JSON, not the other direction.

---

## 14. Single Quotes Are Not Valid HCL Strings

At one point the video's fix for a syntax error was removing single
quotes from a string. Worth stating plainly rather than treating this
as a mysterious quirk: **HCL strings must use double quotes.** Single
quotes are not a valid alternative string delimiter in HCL, unlike
Python, JavaScript, or many other languages where both are
interchangeable. If you see `'like this'` anywhere in a `.tf` file, it
will produce a parse error — the fix is always to use `"like this"`
instead. This wasn't really "finding a fix" so much as correcting an
invalid syntax choice that shouldn't have been there in the first
place.

---

## 15. Testing — Triggering a Policy Violation on Purpose

**`resource_group.tf`** — deliberately missing required tags and using
a disallowed region, to confirm the policies actually block creation:

```hcl
resource "azurerm_resource_group" "test" {
  name     = "test-rg"
  location = "Canada Central"   # not in allowed_locations -> should be denied
  # tags intentionally omitted -> should also be denied by the tag policy
}
```

```powershell
Set-Location "C:\projects\day21"
terraform init
terraform apply --auto-approve
```

Expect an error resembling:

```
Error: creating Resource Group: policy violation
RequestDisallowedByPolicy: Resource 'test-rg' was disallowed by policy.
```

**Adding compliant tags and a valid region:**
```hcl
resource "azurerm_resource_group" "test" {
  name     = "test-rg"
  location = "East US"

  tags = {
    Department = "IT"
    Project    = "Accelerator"
  }
}
```

```powershell
terraform apply --auto-approve
```

This time the resource group should create successfully.

---

## 16. The 24-Hour Compliance Evaluation Cycle

Something the video correctly identifies after some investigation: a
resource created *before* a policy assignment existed, or shortly
after, does not immediately show up as compliant or non-compliant in
the Azure Portal's compliance dashboard. Azure's standard compliance
evaluation cycle runs roughly every 24 hours — resource creation
attempts that *violate* a Deny-effect policy are blocked immediately
at creation time, but the *dashboard's* view of already-existing
resources' compliance status catches up on this slower cycle, not
instantly. If you want a faster compliance state check, Azure CLI
offers an on-demand trigger:

```powershell
az policy state trigger-scan --resource-group "day21-rg"
```

This forces an immediate re-evaluation rather than waiting for the
next scheduled cycle.

---

## 17. `-target` — What It Does and Why It's Not a Daily-Use Flag

The video used `terraform plan -target=azurerm_resource_group.rg` to
apply changes to just one resource while debugging the policy JSON.
Worth being direct about this, matching the "last resort" framing
Day 19 established for provisioners: **`-target` is intended for
exceptional, narrow circumstances** — recovering from a specific
error, or working around a state inconsistency — not as a routine way
to apply partial changes. Habitually using `-target` to apply subsets
of your configuration risks leaving your actual infrastructure and
your Terraform state quietly out of sync with the rest of your
declared configuration, since resources you didn't target aren't
reconciled during that run. Once you've got a working configuration,
prefer plain `terraform apply` over targeted applies for normal work.

---

## 18. Azure Policy vs Terraform Variable Validation — Not the Same Tool

Worth being explicit about this distinction, since the video's own
framing ("this is similar to what we did with variable validation")
slightly understates how different these two mechanisms actually are:

Terraform `validation` blocks (Day 12) run locally, at plan/apply
time, only within the specific Terraform configuration that declares
them. They have no effect whatsoever on resources created any other
way — manually in the Portal, via a different Terraform project, via
the CLI, or by another team entirely.

Azure Policy runs at the Azure Resource Manager level, evaluating
*every* creation and update request against the assigned rules,
regardless of what tool initiated the request. It's the only one of
the two that provides genuine, subscription-wide enforcement.

The practical takeaway: use Terraform variable validation to give
immediate, fast feedback to someone running your specific Terraform
code (a good developer-experience layer). Use Azure Policy as the
actual enforcement backstop that applies no matter how someone tries
to create a non-compliant resource. They're complementary layers, not
interchangeable choices — a mature setup typically uses both.

---

## 19. Parameterized Policies — A Design Choice Worth Knowing About

Everything built above bakes the allowed values (locations, tags, VM
sizes) directly into the policy's JSON rule at the time the Terraform
resource is created. This is simpler to write and understand, but it
has a real limitation: to change the allowed locations later, you have
to modify and redeploy the *policy definition itself* — you can't
reuse the same definition with different values per assignment.

True Azure Policy supports a `parameters` block *inside* the policy
definition, referenced in the rule via `[parameters('parameterName')]`
syntax, with actual values supplied separately at *assignment* time —
letting one definition be reused with different parameter values
across multiple assignments (for example, different allowed regions
per subscription, from the same shared policy definition). This
project's simplified, values-baked-in approach is a reasonable
starting point for learning, but if you're building this for a real
organization with multiple teams or subscriptions needing slightly
different values from a shared policy, look into the
`parameters`/`parameter_values` pattern in the AzureRM provider docs
rather than duplicating full policy definitions per variation.

---

## 20. Complete Corrected Working Code

**`provider.tf`**
```hcl
terraform {
  required_version = ">= 1.9.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}
```

**`variables.tf`**
```hcl
variable "allowed_locations" {
  type    = list(string)
  default = ["eastus", "westus"]
}

variable "allowed_vm_sizes" {
  type    = list(string)
  default = ["Standard_B2s", "Standard_B2ms"]
}

variable "mandatory_tags" {
  type    = list(string)
  default = ["Department", "Project"]
}
```

**`main.tf`**
```hcl
data "azurerm_subscription" "current" {}

resource "azurerm_policy_definition" "allowed_locations" {
  name         = "allowed-locations-policy"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Allowed Locations Policy"

  policy_rule = jsonencode({
    if = {
      field = "location"
      notIn = var.allowed_locations
    }
    then = {
      effect = "deny"
    }
  })
}

resource "azurerm_policy_definition" "allowed_vm_sizes" {
  name         = "allowed-vm-sizes-policy"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Allowed VM Sizes Policy"

  policy_rule = jsonencode({
    if = {
      field = "Microsoft.Compute/virtualMachines/sku.name"
      notIn = var.allowed_vm_sizes
    }
    then = {
      effect = "deny"
    }
  })
}

resource "azurerm_policy_definition" "mandatory_tags" {
  name         = "mandatory-tags-policy"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Mandatory Tags Policy"

  policy_rule = jsonencode({
    if = {
      anyOf = [
        for tag in var.mandatory_tags : {
          field  = "tags['${tag}']"
          exists = "false"
        }
      ]
    }
    then = {
      effect = "deny"
    }
  })
}

resource "azurerm_subscription_policy_assignment" "allowed_locations" {
  name                 = "allowed-locations-assignment"
  policy_definition_id = azurerm_policy_definition.allowed_locations.id
  subscription_id      = data.azurerm_subscription.current.id
}

resource "azurerm_subscription_policy_assignment" "allowed_vm_sizes" {
  name                 = "allowed-vm-sizes-assignment"
  policy_definition_id = azurerm_policy_definition.allowed_vm_sizes.id
  subscription_id      = data.azurerm_subscription.current.id
}

resource "azurerm_subscription_policy_assignment" "mandatory_tags" {
  name                 = "mandatory-tags-assignment"
  policy_definition_id = azurerm_policy_definition.mandatory_tags.id
  subscription_id      = data.azurerm_subscription.current.id
}
```

**`resource_group.tf`** (compliant test resource)
```hcl
resource "azurerm_resource_group" "test" {
  name     = "test-rg"
  location = "East US"

  tags = {
    Department = "IT"
    Project    = "Accelerator"
  }
}
```

**PowerShell — running it:**
```powershell
Set-Location "C:\projects\day21"

$env:ARM_CLIENT_ID       = "your-client-id"
$env:ARM_CLIENT_SECRET   = "your-client-secret"
$env:ARM_TENANT_ID       = "your-tenant-id"
$env:ARM_SUBSCRIPTION_ID = "your-subscription-id"

terraform init
terraform validate
terraform plan
terraform apply --auto-approve
```

---

## 21. Common Mistakes

**Mistake 1 — Hand-typing raw JSON strings inside HCL heredocs.**
Covered fully in Section 6. Build the rule as native HCL and wrap it
in `jsonencode()` instead.

**Mistake 2 — Using `set(string)` for anything you need to index or
iterate in a guaranteed order.** Sets have no index. Use `list(string)`
when order or positional access matters.

**Mistake 3 — Confusing `jsonencode()` with `jsondecode()`.**
`jsonencode` goes HCL to JSON (what `policy_rule` needs);
`jsondecode` goes JSON to HCL (for reading external JSON files, as in
Day 12).

**Mistake 4 — Using single quotes in HCL string literals.** Always
double quotes for HCL strings. Single quotes are only ever valid
*inside* a JSON string value (like `tags['Department']`), never as an
HCL string delimiter itself.

**Mistake 5 — Assuming the Azure Portal compliance dashboard reflects
real-time state.** It runs on roughly a 24-hour evaluation cycle for
already-existing resources; use
`az policy state trigger-scan` for an on-demand check instead of
assuming something is wrong with your policy if the dashboard hasn't
updated yet.

**Mistake 6 — Reaching for `-target` as a routine workflow habit.**
It's meant for exceptional recovery situations, not day-to-day partial
applies — see Section 17.

---

## 22. Practice Exercises

**Exercise 1** — Rewrite the mandatory-tags policy to require three
tags instead of two (`Department`, `Project`, `Environment`), without
duplicating any `anyOf` entries by hand.

*Answer:* No code changes needed beyond the variable's default value —
that's the entire point of the `for` expression in Section 7:
```hcl
variable "mandatory_tags" {
  type    = list(string)
  default = ["Department", "Project", "Environment"]
}
```
The `for tag in var.mandatory_tags : { ... }` expression automatically
generates a third `anyOf` entry with no other changes required.

**Exercise 2** — A resource group created five minutes ago with a
disallowed tag combination isn't showing as non-compliant in the
Portal. Is this evidence the policy assignment failed?

*Answer:* Not necessarily — see Section 16. The standard compliance
evaluation cycle runs roughly every 24 hours for reflecting
already-existing resources' status in the dashboard. Use
`az policy state trigger-scan` to force an immediate check rather than
assuming failure from dashboard lag alone. (Note: if the resource was
actually *created* in violation of a Deny policy, that creation itself
should have been blocked immediately — dashboard lag applies to
resources that predate the assignment or were created under a
different, less restrictive state.)

**Exercise 3** — Explain why a Terraform `variable` `validation` block
checking allowed VM sizes is not a substitute for the Azure Policy
built in this guide.

*Answer:* The `validation` block only stops *that specific Terraform
configuration's* `apply` run from proceeding with a bad value — it has
no effect on a VM created manually in the Portal, via a different
Terraform project, or by another team. Azure Policy enforces at the
Azure Resource Manager level, catching every creation attempt
regardless of the tool used, which is the genuine subscription-wide
guarantee the validation block cannot provide on its own.

---

## 23. Summary Reference

Azure Policy JSON structure: `if` (a condition using `field`, `notIn`,
`in`, `exists`, `anyOf`, `allOf`) paired with `then` (an `effect`, such
as `deny`).

Build policy rules as native HCL objects and wrap the whole thing in
`jsonencode()` — this avoids hand-counting brackets in a JSON heredoc
entirely, lets Terraform variables and `for` expressions work
naturally inside the rule, and is the approach this guide recommends
over the video's original hand-typed-JSON method.

`jsonencode()` converts HCL to JSON (what `policy_rule` needs);
`jsondecode()` does the reverse (for reading external JSON files).

Use `list(string)`, not `set(string)`, for any variable you need to
index or iterate in a defined order.

The current, non-deprecated way to assign a policy at subscription
scope is `azurerm_subscription_policy_assignment`, not the generic
`azurerm_policy_assignment` — matching the deprecated-generic-resource
pattern seen in Day 17 and Day 20.

Azure Policy and Terraform variable validation are complementary, not
redundant — one is a fast, local developer-experience check; the other
is genuine subscription-wide enforcement independent of tooling.

---

*Guide covers: Azure Policy fundamentals, policy as code, the
azurerm_subscription data source, correct Azure Policy JSON rule
syntax (if/then, field, notIn, in, exists, anyOf, allOf), why
hand-typed JSON inside HCL heredocs is fragile, building policy rules
as native HCL objects with jsonencode(), azurerm_policy_definition
resource fields (policy_type, mode, display_name), dynamic anyOf
generation with a for expression, azurerm_subscription_policy_assignment
versus the deprecated generic azurerm_policy_assignment, set versus
list type constraints revisited from Day 7/12, jsonencode versus
jsondecode clarified, HCL's double-quote-only string requirement,
testing policy violations by deliberately creating non-compliant
resources, the Azure Policy 24-hour compliance evaluation cycle and
az policy state trigger-scan for on-demand checks, terraform plan
-target and why it's a last-resort flag rather than routine workflow,
the practical distinction between Azure Policy enforcement and
Terraform variable validation, and parameterized Azure Policy
definitions as a design alternative to baking values directly into
the rule.*
