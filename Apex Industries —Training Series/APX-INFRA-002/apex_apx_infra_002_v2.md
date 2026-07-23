# Apex Industries — Cloud Infrastructure Training Series
## Dynamic Group Membership (Rebuilt at Beginner+++)
**Project Code:** `APX-INFRA-002` | **Level:** Beginner+++ | **Frequency:** Common in most orgs
**Environment:** Windows + VS Code + PowerShell | Fully self-contained | Cost: Free

---

> **Note on this version:** The previous draft of this project
> tried to teach THREE new things at once (custom RBAC roles,
> dynamic groups, and Graph API permissions) while mixing two
> providers — too much, too fast, for 25 days into learning
> Terraform. This version does ONE new thing well: dynamic group
> membership. Single provider, full guidance, same care as
> APX-001.

---

> **From your Team Lead:** In APX-001 you added a user to a group
> manually — you listed their exact ID. This ticket teaches you
> the alternative: a group that fills itself based on a rule. Add
> a matching user later, they join automatically. This is
> genuinely how most real corporate IT teams manage large groups
> — nobody manually maintains a list of 500 engineers. — *Morgan Chen*

---

## Org Context
`dev` | No dependencies — standalone | Cost: Free

---

## 1. Overview

### The One New Concept — Dynamic vs Static Groups

**Static group (what you built in APX-001):**
```
You manually list who belongs → Terraform adds exactly those people
Add someone new later? You must edit the Terraform code again.
```

**Dynamic group (what you're building now):**
```
You write a RULE describing who should belong
  → e.g. "anyone whose department = Engineering"
Azure AD automatically finds everyone matching that rule
Add a new Engineering employee later, ANYWHERE, ANY TIME
  → they join the group automatically, with zero Terraform
    changes needed
```

Think of a static group like a hand-written guest list for a
party. A dynamic group is more like a sign at the door saying
"Engineering badge holders only" — anyone with the right badge
gets in automatically, no list needed, no one has to remember to
update anything.

### What You Are Building

```
Azure AD User: "sam.rivera@yourtenant.onmicrosoft.com"
   department attribute = "Engineering"

Dynamic Group: "apx-dev-engineering-dept"
   Rule: "anyone whose department attribute equals Engineering"
   → sam.rivera automatically qualifies
```

### Reused Without Guidance
`azuread_user`, `data.azuread_domains` — you built both of these
in APX-001. Build the user resource from memory. This spec adds
guidance ONLY for the new group configuration.

### One Provider Only This Time
Just `azuread` — same as APX-001. No `azurerm` mixed in. That
complexity is deferred to a later project, once you're more
comfortable.

---

## 2. Naming Convention

```hcl
# terraform.tfvars
dynamic_group_name  = "apx-dev-engineering-dept"
user_department      = "Engineering"
user_mail_nickname   = "sam.rivera"
user_display_name    = "Sam Rivera"
```

---

## 3. Core Components

### Component 1 — The User (Build From Memory, Same as APX-001)

The only addition compared to APX-001 is one new argument:
`department`. This is what the dynamic group's rule will check
against.

```hcl
resource "azuread_user" "engineer" {
  user_principal_name    = "${var.user_mail_nickname}@${data.azuread_domains.current.domains[0].domain_name}"
  display_name            = var.user_display_name
  mail_nickname            = var.user_mail_nickname
  password                 = "ApxTemp@Password2024!"
  force_password_change   = true

  department = var.user_department    # ← new — must match the group's rule exactly
}

data "azuread_domains" "current" {
  only_initial = true
}
```

### Component 2 — The Dynamic Group

```hcl
resource "azuread_group" "engineering_dept" {
  display_name     = var.dynamic_group_name
  security_enabled = true

  types = ["DynamicMembership"]

  dynamic_membership {
    enabled = true
    rule    = "user.department -eq \"${var.user_department}\""
  }
}
```

**Every line explained slowly:**

```hcl
types = ["DynamicMembership"]
```
Without this line, the group defaults to a normal STATIC group —
exactly like APX-001. This one line is the entire switch that
turns membership from "manual list" into "automatic rule."

```hcl
dynamic_membership {
  enabled = true
```
Turns the rule-checking ON. You could set this to `false` to
temporarily pause automatic membership evaluation without
deleting the rule itself — not needed for this exercise, but
worth knowing it exists.

```hcl
  rule = "user.department -eq \"${var.user_department}\""
}
```
This is the actual rule, written as a STRING — not Terraform
code, but Azure AD's own rule language that Azure evaluates
internally. Read it exactly like a sentence:

```
user.department  -eq  "Engineering"
     ↑              ↑         ↑
  which field    equals    what value
  to check       (-eq)     to match
```

`-eq` means "equals exactly." Azure AD supports other operators
too (`-contains`, `-startsWith`, `-ne` for "not equals") but
`-eq` is the simplest and most common starting point.

**Why is the rule wrapped in escaped quotes (`\"`)?** Because the
whole rule is ALREADY inside one set of double quotes (it's a
Terraform string). The `\"` tells Terraform "this is a literal
quote character, part of the string content, not the end of the
string." Without the backslash, Terraform would think the string
ended right after `department -eq `, and everything after would
be a syntax error.

### Component 3 — Variables

```hcl
variable "dynamic_group_name" {
  description = "Display name for the dynamic group"
  type        = string
}

variable "user_department" {
  description = "Department value — must match exactly between user and group rule"
  type        = string
}

variable "user_mail_nickname" {
  description = "Mail nickname portion of the user's UPN"
  type        = string
}

variable "user_display_name" {
  description = "User's display name"
  type        = string
}
```

### Component 4 — Outputs

```hcl
output "dynamic_group_object_id" {
  description = "Object ID of the dynamic group"
  value       = azuread_group.engineering_dept.object_id
}

output "user_object_id" {
  description = "Object ID of the created user"
  value       = azuread_user.engineer.object_id
}

output "user_principal_name" {
  description = "Full sign-in name of the created user"
  value       = azuread_user.engineer.user_principal_name
}
```

---

## 4. Hints

**Hint 1 — The department value must match EXACTLY, including
capitalization:** `"Engineering"` and `"engineering"` (lowercase)
are treated as different values by the `-eq` operator. If your
user's `department` argument and your group's rule don't match
character-for-character, the user will never show up as a member,
and there will be no error telling you why — it will just silently
not work. Double-check both values in `terraform.tfvars` are
spelled and capitalized identically.

**Hint 2 — You may not see live membership even with correct
code, depending on your tenant's license:** dynamic group RULE
EVALUATION (Azure actually checking the rule and adding matching
users) requires an Azure AD Premium P1 license on some tenants.
The good news: **the Terraform code itself applies successfully
regardless of licensing** — you're not paying for anything by
running this project. If you check group membership afterward and
it shows zero members despite your user matching the rule, this
is very likely a licensing limitation on your specific tenant, not
a mistake in your code. This is worth knowing upfront so you don't
spend an hour debugging something that was never going to
populate on a free tier.

**Hint 3 — This is still just ONE resource type you haven't fully
used before:** `azuread_group` itself is identical to APX-001.
The ONLY new pieces are the `types` argument and the
`dynamic_membership` block. If this project feels manageable,
that's the correct feeling — it genuinely is a small, focused
addition on top of something you already know.

---

## 5. Workflow (PowerShell)

```powershell
cd C:\Projects\apx-infra-002

terraform init
terraform validate
terraform fmt
terraform plan
# Should show: 1 user, 1 group, 1 data source — small, easy to read

terraform apply
# Type: yes

terraform output dynamic_group_object_id
terraform output user_principal_name

# Verify the group's rule is set correctly
az ad group show `
  --group (terraform output -raw dynamic_group_object_id) `
  --query "{Name:displayName, MembershipType:groupTypes, Rule:membershipRule}" `
  --output table

# Check membership (may show 0 members if Premium P1 isn't licensed — see Hint 2)
az ad group member list `
  --group (terraform output -raw dynamic_group_object_id) `
  --output table

terraform destroy
```

---

## 6. Checklist

```
[ ] User has department attribute set — matches group rule value exactly
[ ] Group has types = ["DynamicMembership"]
[ ] Group has dynamic_membership block with enabled = true
[ ] Rule syntax uses -eq with escaped quotes around the value
[ ] Only azuread provider used — no azurerm mixed in
[ ] terraform plan shows a small, readable set of changes (3 items)
[ ] terraform destroy completed
```

---

## 7. Cost
**Free.** No charge for group creation or rule definition,
regardless of licensing tier.

## Series Status
```
APX-001   ✅  Azure AD Fundamentals — Users, Groups, App Registrations
APX-002   ✅  Dynamic Group Membership              ← THIS PROJECT (Beginner+++)
APX-003   📋  Storage + Lifecycle Management Policies
```

*Apex Industries — Cloud Platform Engineering | Training Series*
