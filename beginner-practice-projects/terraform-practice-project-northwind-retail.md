# Terraform Practice Project — NorthWind Retail Azure Expansion
## A Self-Guided Exercise Brief (No Solution Included)

---

## How to Use This Document

This is a project brief, not a tutorial. It describes a realistic
business scenario, gives you sample data to work with, and lists
requirements — the same way a real infrastructure ticket or a take-home
technical assessment would. It does **not** contain resource blocks,
module code, or a finished configuration. Where a specific Terraform
function is clearly the right tool for a requirement, I've named the
function so you're not guessing blindly across the entire standard
library — but working out *how* to apply it, in what order, and with
what surrounding logic, is the actual exercise.

Treat ambiguity in this brief as intentional. Real infrastructure
requests rarely spell out every detail — deciding what's reasonable to
assume, and documenting that assumption in a comment or a variable
description, is part of what's being tested.

---

## The Scenario

NorthWind Retail is expanding its e-commerce platform onto Azure. You've
been given a set of requirements from three different stakeholders
(networking/security, application, and finance) and a CSV export of
their current store locations. Your job is to build the Terraform
configuration for two environments — `dev` and `prod` — from scratch.

You are expected to use: input variables with validation, locals,
`count` and/or `for_each` (chosen appropriately, not interchangeably),
at least one dynamic block, at least one lifecycle rule beyond the
default behavior, and a meaningful number of built-in functions rather
than hardcoded values. A short function-hint table is provided per
section, but you decide the actual implementation.

---

## Provided Sample Data

### Store locations CSV

Save this as `stores.csv` in your project directory. You'll need to
read and process this file as part of Part 6.

```csv
store_id,store_name,region,is_active
101,Downtown Flagship,eastus,true
102,Riverside Mall,eastus,true
103,Old Town Outlet,eastus,false
104,Harbor Point,westus2,true
105,North Ridge,westus2,false
106,Lakeside Commons,centralus,true
107,Metro Center,centralus,true
108,East Gate Plaza,eastus,true
```

Note: two stores are marked inactive. Part 6 requires you to correctly
exclude them from whatever you build against this data — decide for
yourself which Terraform feature actually filters a collection like
this rather than just iterating over all of it.

### Environment configuration reference

Use these values as inputs to variables you design — the shape (a map
keyed by environment name) is a hint; the exact variable type
constraint and defaults are yours to define.

```
dev:
  instance_count: 1
  vm_size: Standard_B1s
  address_space: 10.0.0.0/16
  allowed_ports: 22, 80, 443, 8080

prod:
  instance_count: 3
  vm_size: Standard_D2s_v3
  address_space: 10.1.0.0/16
  allowed_ports: 80, 443
```

Note that `dev` allows an extra port (`8080`, presumably for
debugging/testing) that `prod` deliberately does not. Whatever
generates your NSG rules needs to reflect that difference correctly
per environment, not apply the same rule set to both.

### A third-party API key (treat as a real secret)

```
THIRD_PARTY_API_KEY = "sk_live_51NxYzABCDEF1234567890abcdefGHIJ"
```

This value must never appear in plaintext in any `.tf` file you commit,
must never appear unmasked in `terraform plan`/`apply` output, and
should end up stored in a Key Vault secret rather than only living in a
Terraform variable. Decide how it gets from "you have it locally" to
"it's in Key Vault" without ever hardcoding it into version-controlled
configuration.

### Mandatory tag policy (from Finance)

Every resource must carry these four tags:
```
Environment  (dev or prod)
CostCenter   (a string, provided per environment — you decide the input mechanism)
ManagedBy    (always "Terraform")
CreatedOn    (the actual date/time the resource was created)
```

---

## Part 1 — Foundation

Build the Resource Group(s) and the variable/locals scaffold everything
else depends on.

Requirements:
- One Resource Group per environment, named using a consistent,
  derived convention — not two independently hardcoded strings
- A `locals` block producing the common tag map described above,
  combining a per-environment value with fixed constants
- The `CreatedOn` tag must reflect the actual creation moment, not a
  value you type by hand

Function hints: `merge()`, `formatdate()`, `timestamp()`

Something to decide for yourself: should the Resource Group names and
the common tags be defined once and reused everywhere, or recomputed
per resource? What happens to `CreatedOn` if you re-run `apply` on an
already-existing resource — is that actually the behavior Finance
wants, or a subtle bug you need to design around?

---

## Part 2 — Networking

Requirements:
- One Virtual Network per environment, using the address space from
  the environment configuration reference above
- A **variable number** of subnets — driven by data, not a fixed count
  you hardcode. Come up with your own subnet list (at least three per
  environment) rather than assuming exactly one
- Each subnet's address prefix should be derived, not manually typed
  out for each one — think about what happens if someone adds a fourth
  subnet to your list later; should that require editing more than one
  place?

Function hints: `length()`, `cidrsubnet()` (a function not covered in
earlier material in this series — look up its signature yourself; it's
directly relevant here)

Something to decide for yourself: `count` or `for_each`? Both could
technically work here. Which one is more resilient if someone removes
a subnet from the middle of your list later, and why does that matter?

---

## Part 3 — Security (NSG Rules from Data)

Requirements:
- One Network Security Group per environment
- Inbound allow rules generated from the `allowed_ports` list in the
  environment configuration reference — not written out as individual
  hardcoded `security_rule` blocks
- Rule priorities must not collide, and should be computed rather than
  manually assigned one at a time
- The `dev` and `prod` rule sets must genuinely differ, driven by the
  same underlying logic operating on different input data — not two
  separately hand-written rule sets

Function hints: a dynamic block (this is close to a textbook use case
for one), `index()` for computing priorities without collision

Something to decide for yourself: should the priority increment be
tied to the port's position in the list, or to the port number itself?
What happens to existing rule priorities if someone inserts a new port
in the middle of the list later — does your approach cause unrelated
rules to silently change priority on the next apply?

---

## Part 4 — Storage and Naming Constraints

Requirements:
- One Storage Account per environment, holding a container named
  `product-images`
- The Storage Account name must be programmatically derived from your
  project/environment naming convention, then transformed to satisfy
  Azure's actual naming rules (you'll need to recall or look up exactly
  what those rules are) — not manually typed to "happen" to fit
- Add a `validation` block on whatever variable feeds the base name,
  rejecting obviously invalid input before Terraform ever attempts to
  create the resource

Function hints: `lower()`, `replace()`, `substr()`

Something to decide for yourself: if your derived name is over the
character limit after combining a prefix, environment, and suffix,
does your configuration silently truncate it (potentially causing a
naming collision with a similarly-truncated different name), or does
it fail loudly? Which is the safer default, and how would you
implement whichever you choose?

---

## Part 5 — Secrets Handling

Requirements:
- A Key Vault per environment
- The third-party API key from the sample data must end up as a Key
  Vault secret, sourced from a variable that is never given a literal
  default value in a committed file
- Any Terraform output that could conceivably expose this value must be
  handled correctly — decide what "correctly" means here and implement it

Function hints: none specifically required, but revisit how
`sensitive` behaves differently at the variable level, the output
level, and inside the state file — this section is really testing
whether you understand that distinction, not whether you can call a function.

Something to decide for yourself: is a Key Vault access policy or an
RBAC role assignment more appropriate for granting your deploying
identity permission to write this secret? What's the minimum
permission that actually accomplishes the task?

---

## Part 6 — Data-Driven Store Resources

Requirements:
- Read `stores.csv` and parse it into usable Terraform data
- Create exactly one resource (your choice of resource type — a
  Storage Container per store is a reasonable option, but justify your
  choice) for every **active** store only — the two inactive stores
  must not produce any resource at all
- Each created resource's name or tag must incorporate the store's
  actual name and region from the CSV, not a generic placeholder

Function hints: `file()`, `csvdecode()`, a filtered `for` expression
(the `if` clause matters here), `for_each` (not `count` — think about why)

Something to decide for yourself: if a store's `is_active` flag flips
from `true` to `false` in a future CSV update and you re-run `apply`,
what should happen to the resource that store previously had? Does
your current design handle that gracefully, or does it require manual
cleanup?

---

## Part 7 — Guardrails and Validation

Requirements:
- Variable validation ensuring the environment value is only ever
  `dev` or `prod` (and rejecting anything else with a clear error
  message)
- Variable validation ensuring instance count stays within a sane
  bound (you decide the bound, document why you chose it)
- A `precondition` inside a `lifecycle` block on at least one resource,
  checking something that genuinely can't be validated at the variable
  level alone (think about what that might be, given this project's data)
- A `prevent_destroy` lifecycle rule on exactly one resource that
  genuinely warrants it in this scenario — and a short written
  justification (a comment in your code is fine) for why you picked
  that specific resource and not another

Function hints: `contains()`, whatever comparison logic your
precondition actually needs — this depends entirely on what you chose
to check

Something to decide for yourself: is `prevent_destroy` something you'd
want on every environment equally, or does it make more sense applied
conditionally, only for `prod`? If conditionally, how would you even
express a lifecycle argument conditionally, given that lifecycle blocks
don't accept ordinary variable-driven expressions the way resource
arguments do? (This one is a genuine, non-obvious constraint — spend
real time on it rather than assuming there's an easy answer.)

---

## Part 8 — Outputs

Requirements:
- An output providing a map of active store name to whatever resource
  you created for it in Part 6 — not a flat list, a map keyed by store name
- An output summarizing the tag set actually applied to resources in
  this environment
- Confirm, deliberately, that nothing related to the API key from Part
  5 leaks through any output unmasked — verify this by actually running
  a plan/apply and reading the output, not just assuming your code is correct

Function hints: a `for` expression producing a map (not a list)

---

## Stretch Goals (Optional, Genuinely Harder)

- Refactor the networking (Part 2) and security (Part 3) sections into
  a reusable child module, accepting the subnet list and port list as
  module inputs, so the same module could be called for a third
  environment without copy-pasting resource blocks
- Add a second, explicitly named `dynamic` block nested inside another,
  and use the `iterator` argument to avoid a naming collision between
  the outer and inner loop variables
- Use `try()` or `coalesce()` somewhere a value might reasonably be
  missing from your environment configuration map, providing a sane
  fallback instead of letting Terraform error on a missing key
- Render a VM startup script using `templatefile()`, injecting at
  least one value that differs between `dev` and `prod`
- Set up a remote backend with genuinely separate state per
  environment (not just separate `.tfvars` files pointed at the same
  state) — and verify, by deliberately trying, that a mistake made
  while working on `dev`'s state cannot touch `prod`'s

---

## Self-Review Checklist

Before considering this done, check your own work against these —
each one maps back to a specific requirement above, and each one is
something a code reviewer would actually look for:

- Does `terraform validate` pass cleanly?
- Does `terraform plan` ever print the API key value anywhere, even
  partially?
- If you delete one entry from your subnet list or port list, does
  `terraform plan` show a minimal, sensible diff — or does it show
  unrelated resources being destroyed and recreated because of an
  indexing choice you made?
- Does re-running `apply` a second time with no changes report zero
  changes, or does something (a timestamp, an unstable ordering)
  needlessly show a diff every time?
- If you intentionally set `environment = "qa"` (a value not in your
  allowed list), does `plan` fail immediately with your custom error
  message, or does it proceed and fail later with a confusing
  Azure-side error instead?
- If you intentionally mark a store `is_active = false` in the CSV and
  re-apply, does exactly one resource get removed, and nothing else?
- Can you explain, out loud, why you chose `count` in some places and
  `for_each` in others — for every place you used either?

---

## What This Exercise Is Actually Testing

Not whether you can write valid HCL syntax — an autocomplete tool can
do that. It's testing whether you can take an underspecified, slightly
messy real-world request (inconsistent stakeholder requirements, dirty
sample data with inactive records mixed in, a security constraint that
has to survive contact with a naming constraint) and make deliberate,
defensible engineering decisions where the brief doesn't spell out the
answer — and then verify your own work rather than assuming it's
correct because it applied without an error.

---

*No solution file accompanies this brief, by design. If you get stuck
on a specific function's exact syntax or argument order, the
consolidated Terraform functions reference and the expressions/
lifecycle/validation reference already built for this series cover
every function and language feature named above in detail — the
gap you're meant to close yourself is deciding which one to reach for
and how to combine them, not memorizing syntax.*
