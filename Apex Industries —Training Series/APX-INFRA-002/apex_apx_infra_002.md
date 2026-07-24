# Apex Industries — Cloud Infrastructure Training Series (**for DynamicMembership you need to have Microsoft Entra ID P1 or P2 or else tf plan will going to end with error. Custom RBAC Roles +  API Permissions will work fine.**********
## Custom RBAC Roles + Dynamic Groups + API Permissions
**Project Code:** `APX-INFRA-002` | **Level:** Intermediate++ | **Frequency:** Common in mature orgs
**Environment:** Windows + VS Code + PowerShell | Fully self-contained | Cost: Free

---

> ## Note on Scope Change
> The original roadmap listed "Conditional Access" for this
> project. Conditional Access Policies require Azure AD Premium
> P1 — a real licensing cost, not free tier. Per the standing
> budget rule, this project swaps that for three concepts that
> are genuinely harder than APX-001 AND completely free: custom
> RBAC role definitions, dynamic group membership rules, and API
> permission grants on an App Registration.

---

> **From your Team Lead:** APX-001 taught you the basic identity
> objects. This ticket goes deeper on THREE fronts at once, with
> less hand-holding than before — you've done enough Terraform now
> that I expect you to figure out some of the wiring yourself.
> Custom roles instead of built-ins. Groups that populate
> themselves based on rules instead of manual membership. An app
> that actually requests real permissions instead of just
> existing. — *Morgan Chen, Cloud Platform Lead, Apex Industries*

---

## Org Context
`dev` | No dependencies — standalone | Cost: Free

---

## 1. Overview — Three Genuinely Harder Concepts

```
1. CUSTOM RBAC ROLE DEFINITION
   Every role you've used so far ("Key Vault Secrets User",
   "Contributor") was Azure-BUILT-IN. This project writes a
   CUSTOM role from scratch — you define exactly which actions
   it can and cannot perform.

2. DYNAMIC GROUP MEMBERSHIP
   APX-001's group had membership added MANUALLY — you listed
   object_ids. A dynamic group instead uses a RULE — anyone
   matching that rule is automatically a member, no manual
   management required. Add a new user matching the rule later,
   they auto-join. Remove them from matching, they auto-leave.

3. API PERMISSIONS ON AN APP REGISTRATION
   APX-001's App Registration existed but requested nothing. Real
   apps need PERMISSIONS — the ability to read user profiles,
   access Microsoft Graph data, etc. This project grants a real
   Microsoft Graph permission and shows you the admin consent
   step that real permissions require.
```

### What You Are Building

```
Custom Role: "Apex VM Operator"
  Can: start/stop/restart VMs
  Cannot: delete VMs, create new ones, modify networking
         │
         ▼
   Assigned to →  Dynamic Group: "apx-dev-engineering-dept"
                   Rule: auto-includes any user whose
                   department attribute = "Engineering"
                         │
App Registration: "apx-dev-reporting-tool"
  Requests: User.Read.All (Microsoft Graph permission)
  Requires: Admin consent (you grant it yourself, simulating
            what a tenant admin would approve)
```

### Reused Without Guidance
`azuread_user`, `azuread_application`, `azuread_service_principal`,
`data.azuread_domains` — you built all of these in APX-001. Build
the base user and app registration from memory this time. This
spec focuses only on the three new concepts.

---

## 2. Best Practices Applied

Same `.gitignore`, same README template pattern as every project
since MRB-008. Add `validation{}` on any variable with a
constrained set of valid values (see Component 1).

---

## 3. Naming Convention

```hcl
# terraform.tfvars
custom_role_name       = "Apex VM Operator"
dynamic_group_name     = "apx-dev-engineering-dept"
app_display_name       = "apx-dev-reporting-tool"
user_department        = "Engineering"
user_mail_nickname     = "sam.rivera"
user_display_name      = "Sam Rivera"
```

---

## 4. Core Components

### Component 1 — Custom RBAC Role Definition (New)

**This resource uses `azurerm`, not `azuread`** — RBAC role
definitions are an Azure resource concept, even though they
control access TO Azure resources by identity. Worth noticing:
this project actually needs BOTH providers together, unlike
APX-001 which was pure `azuread`.

```hcl
resource "azurerm_role_definition" "vm_operator" {
  name        = var.custom_role_name
  scope       = data.azurerm_subscription.current.id
  description = "Can start, stop, and restart VMs. Cannot delete, create, or modify networking."

  permissions {
    actions = [
      "Microsoft.Compute/virtualMachines/start/action",
      "Microsoft.Compute/virtualMachines/restart/action",
      "Microsoft.Compute/virtualMachines/deallocate/action",
      "Microsoft.Compute/virtualMachines/read"
    ]
    not_actions = []
  }

  assignable_scopes = [
    data.azurerm_subscription.current.id
  ]
}

data "azurerm_subscription" "current" {}
```

**You are expected to figure out, without step-by-step guidance,
what goes in `actions` vs `not_actions`:**

```
actions      → the specific list of things this role IS allowed to do
not_actions  → explicit exclusions carved OUT of a broader actions
               list (e.g. if actions included a wildcard, not_actions
               could exclude one specific dangerous action from it)
```

For this project, `actions` lists ONLY the specific start/stop/
restart/read permissions — nothing broader — so `not_actions`
stays empty. This is the SAFER pattern: an explicit allow-list is
always more secure than a broad allow with exclusions carved out.

> **Where do these exact action strings come from?** They are
> Azure's own permission strings, documented at:
> `https://learn.microsoft.com/en-us/azure/role-based-access-control/permissions/compute`
> Real RBAC role authoring always involves looking up the exact
> action strings for the resource types you're scoping — the same
> "check the documentation for the exact schema" skill from the
> `dynamic` block addendum applies here too.

### Component 2 — Dynamic Group Membership

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

**Break down the new pieces:**

- `types = ["DynamicMembership"]` — without this, the group
  defaults to static (manual) membership, exactly like APX-001.
  This single line is what makes the group "smart."
- `dynamic_membership.rule` — written in Azure AD's own rule
  syntax, NOT Terraform HCL. It's a string that Azure AD parses
  and evaluates against every user in the tenant. This particular
  rule says: *"include any user whose `department` attribute
  exactly equals whatever `var.user_department` is."*

**You still need a user with that department attribute set, for
the rule to actually match anyone:**

```hcl
resource "azuread_user" "engineer" {
  user_principal_name = "${var.user_mail_nickname}@${data.azuread_domains.current.domains[0].domain_name}"
  display_name          = var.user_display_name
  mail_nickname          = var.user_mail_nickname
  password               = "ApxTemp@Password2024!"
  force_password_change  = true

  department = var.user_department    # ← must match the rule exactly
}
```

> **Critical detail easy to miss:** dynamic groups require an
> Azure AD Premium P1 license to actually EVALUATE membership
> rules — same licensing tier as Conditional Access. **However**,
> you CAN still create the dynamic group resource itself and
> define the rule for free — Terraform will apply successfully.
> What you may NOT be able to do on a free/basic tenant is see the
> rule actually populate real membership, since rule evaluation
> is the licensed feature, not group creation itself. This is
> worth understanding honestly rather than discovering it
> confused: the Terraform code applies fine either way; the LIVE
> BEHAVIOR (auto-membership evaluation) may be licensing-gated on
> your specific tenant.

### Component 3 — API Permissions on App Registration

```hcl
resource "azuread_application" "reporting_tool" {
  display_name = var.app_display_name

  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000"   # Microsoft Graph's fixed app ID

    resource_access {
      id   = "df021288-bdef-4463-88db-98f22de89214"    # User.Read.All permission ID
      type = "Role"                                      # "Role" = application permission (not delegated)
    }
  }
}

resource "azuread_service_principal" "reporting_tool_sp" {
  client_id = azuread_application.reporting_tool.client_id
}
```

**You are expected to recognize the pattern here without full
explanation:** `resource_app_id` is a FIXED, universal GUID —
`00000003-0000-0000-c000-000000000000` is Microsoft Graph's
application ID across every Azure tenant in the world, not
something you generate. The permission ID
(`df021288-bdef-4463-88db-98f22de89214`) is similarly fixed —
it specifically identifies the `User.Read.All` application
permission within Graph's own permission catalog.

> Real engineers look these specific GUIDs up rather than
> memorizing them — Microsoft publishes a full reference at
> `https://learn.microsoft.com/en-us/graph/permissions-reference`.
> This is genuinely how this work happens day to day: you know
> the PATTERN (resource_app_id + resource_access block with a
> permission ID + type), and you look up the specific IDs each
> time you need a different permission.

**Admin consent — the step that makes the permission actually
active:**

```hcl
resource "azuread_service_principal_delegated_permission_grant" "consent" {
  # NOTE: only needed for DELEGATED permissions (type = "Scope").
  # Since this project uses an APPLICATION permission (type =
  # "Role"), admin consent is instead granted via app_role_assignment:
}

resource "azuread_app_role_assignment" "grant_consent" {
  app_role_id         = "df021288-bdef-4463-88db-98f22de89214"
  principal_object_id = azuread_service_principal.reporting_tool_sp.object_id
  resource_object_id  = data.azuread_service_principal.msgraph.object_id
}

data "azuread_service_principal" "msgraph" {
  client_id = "00000003-0000-0000-c000-000000000000"
}
```

> Requesting a permission (Component 3's first half) and
> GRANTING/CONSENTING to it (this piece) are two separate steps
> — in a real org, a regular developer can REQUEST a permission
> in their app registration, but only a tenant ADMIN can actually
> CONSENT to it being active. This Terraform code performs both
> steps because your learning tenant makes you the admin — in a
> real corporate environment, the consent step would often be a
> separate approval process outside Terraform entirely.

### Component 4 — Variables + Outputs

Add validation on the department field:
```hcl
variable "user_department" {
  type = string
  validation {
    condition     = contains(["Engineering", "Sales", "Finance", "Operations"], var.user_department)
    error_message = "user_department must be one of: Engineering, Sales, Finance, Operations."
  }
}
```

Outputs:
```
custom_role_id
dynamic_group_object_id
app_client_id
app_role_assignment_id
```

---

## 5. Hints

**Hint 1 — `azurerm_role_definition` needs subscription-level
scope, which means it's tenant-wide in effect, not resource-group
scoped:** unlike every previous `azurerm` resource you've built,
this one doesn't live inside a Resource Group at all — it's
defined at the SUBSCRIPTION level via
`data.azurerm_subscription.current.id`. Custom roles are meant to
be reusable across many resource groups, so this makes sense once
you see it, but it's a genuinely different scoping pattern from
everything before.

**Hint 2 — Deleting a custom role that's still assigned to
someone will fail:** if you had actually assigned
`azurerm_role_definition.vm_operator` to a user via
`azurerm_role_assignment` (not included in this project's scope,
but a natural next step), `terraform destroy` would need to
remove the assignment BEFORE the role definition — same
dependency direction as everything else you've learned, just
worth flagging since role definitions feel more abstract than a
VM or storage account.

**Hint 3 — Mixing `azurerm` and `azuread` providers in one project
means you need BOTH provider blocks:** don't forget
`providers.tf` needs entries for both — a mistake here shows up
as a "provider not configured" error that can be confusing since
you've mostly worked with one provider at a time until now.

---

## 6. Workflow (PowerShell)

```powershell
cd C:\Projects\apx-infra-002

terraform init
terraform fmt -check -recursive
terraform validate
terraform plan -out=tfplan
terraform apply tfplan

terraform state list

# Verify custom role
az role definition list --custom-role-only true --output table

# Verify dynamic group (membership rule, not live membership if unlicensed)
az ad group show --group (terraform output -raw dynamic_group_object_id) `
  --query "{Name:displayName, MembershipType:groupTypes}" --output table

# Verify app permission was granted
az ad app permission list --id (terraform output -raw app_client_id) --output table

terraform destroy
```

---

## 7. Checklist

```
[ ] Custom role uses explicit actions list, not_actions left empty
[ ] Role scoped at subscription level via data.azurerm_subscription
[ ] Dynamic group has types = ["DynamicMembership"] AND dynamic_membership block
[ ] User's department attribute matches the dynamic group's rule exactly
[ ] App registration requests User.Read.All via required_resource_access
[ ] resource_app_id uses Microsoft Graph's fixed GUID (not invented)
[ ] app_role_assignment grants consent for the requested permission
[ ] Both azurerm AND azuread providers configured in providers.tf
[ ] terraform destroy completed
```

---

## 8. Cost
**Free.** Custom role definitions, dynamic group creation (code
level), and API permission grants have zero direct cost. Live
dynamic membership EVALUATION may require Premium P1 licensing on
some tenants — the Terraform code itself remains free regardless.

## Series Status
```
APX-001   ✅  Azure AD Fundamentals
APX-002   ✅  Custom RBAC + Dynamic Groups + API Permissions  ← THIS PROJECT (++ level)
APX-003   📋  Storage + Lifecycle Management Policies
```

*Apex Industries — Cloud Platform Engineering | Training Series*
