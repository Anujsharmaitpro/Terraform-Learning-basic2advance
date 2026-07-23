# Apex Industries — Cloud Infrastructure Training Series
## Azure AD Fundamentals — Users, Groups, App Registrations
**Project Code:** `APX-INFRA-001` | **Level:** Beginner+ | **Frequency:** Used everywhere
**Environment:** Windows + VS Code + PowerShell | Fully self-contained | Cost: Free

---

> **From your Team Lead:** Every project you've built so far has
> managed Azure RESOURCES — VMs, storage, databases. This ticket
> is different — you're managing IDENTITY objects instead. Users,
> groups, and app registrations live in Azure AD (now called
> Microsoft Entra ID), a completely separate system from the
> Azure resources you've been provisioning. Nearly every corporate
> IT team manages this, regardless of what the company does.
> — *Morgan Chen, Cloud Platform Lead, Apex Industries*

---

## Org Context
`dev` | `East US` | No dependencies — standalone | Cost: Free

---

## 1. Overview — A Genuinely Different Provider

Every project across NexaCore and Meridian used the `azurerm`
provider — it manages Azure RESOURCES (things that cost money,
run in a region, belong to a resource group).

This project introduces the `azuread` provider — it manages
Azure AD OBJECTS (users, groups, app registrations). These are
NOT regional, NOT tied to a resource group, and mostly free.
Different provider, different mental model, same Terraform syntax
you already know.

```
azurerm provider  → manages things IN Azure (VMs, storage, networks)
azuread provider   → manages WHO/WHAT can access Azure (identity objects)
```

### What You Are Building

```
Azure AD Group: "apx-dev-engineers"
   │
   ├── Member: Azure AD User "jane.doe@apexindustries.onmicrosoft.com"
   │
App Registration: "apx-dev-internal-tool"
   │
   └── Service Principal (the "identity" the app registration
       actually uses to authenticate — created automatically
       alongside the registration)
```

### New Terraform Resources

| Resource | Purpose |
|---|---|
| `azuread_user` | Creates a user object in Azure AD |
| `azuread_group` | Creates a group, can contain users |
| `azuread_application` | An App Registration — represents an app that will authenticate |
| `azuread_service_principal` | The actual identity an app registration uses |

### The Concept — App Registration vs Service Principal

This distinction confuses almost everyone the first time:

```
App Registration (azuread_application)
  → the DEFINITION of an application — its name, what permissions
    it's allowed to request, metadata

Service Principal (azuread_service_principal)
  → the actual IDENTITY that application uses to authenticate
    and access resources — created FROM the App Registration
```

Think of App Registration like a job posting describing a role,
and Service Principal like the actual employee hired into that
role. The posting describes what's needed; the employee is the
one who actually shows up and does the work (authenticates,
gets assigned permissions).

---

## 2. Best Practices Applied

### `.gitignore`
Same standard set as every previous project — no changes needed.

### README.md Template

```markdown
# APX-INFRA-001 — Azure AD Fundamentals

## What This Provisions
An Azure AD group with a user member, and an App Registration
with its associated Service Principal.

## Prerequisites
- Azure CLI logged in with sufficient Azure AD permissions
  (see Hint 1 — regular users often CANNOT create AD objects)
- Terraform v1.6+

## How to Run
​```powershell
terraform init
terraform plan -out=tfplan
terraform apply tfplan
​```

## How to Destroy
​```powershell
terraform destroy
​```

## Estimated Cost
Free. Azure AD object management has no cost.
```

---

## 3. Naming Convention

Apex uses a simpler naming pattern than Meridian's compliance-heavy
one — reflecting a generic corporate IT team rather than a
regulated bank:

```
Pattern: apx-{env}-{purpose}
```

| Resource | Name |
|---|---|
| Group | `apx-dev-engineers` |
| User | `jane.doe@apexindustries.onmicrosoft.com` |
| App Registration | `apx-dev-internal-tool` |

> **No mandatory 8-tag system this series** — Azure AD objects
> don't support Azure resource tags at all (a good early lesson:
> tags are an `azurerm` concept, not something that exists for
> `azuread` objects).

```hcl
# terraform.tfvars
group_name         = "apx-dev-engineers"
user_display_name  = "Jane Doe"
user_mail_nickname = "jane.doe"
app_display_name   = "apx-dev-internal-tool"
```

---

## 4. Core Components

### Component 0 — Provider Setup (New)

```hcl
# providers.tf
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
  }
}

provider "azuread" {}
```

> Notice: **no `features {}` block** — that's an `azurerm`-specific
> requirement. `azuread` doesn't need it. Also notice there's no
> `location` or `resource_group_name` anywhere in this entire
> project — Azure AD objects are tenant-wide, not regional.

### Component 1 — Azure AD User

```hcl
resource "azuread_user" "engineer" {
  user_principal_name = "${var.user_mail_nickname}@${data.azuread_domains.current.domains[0].domain_name}"
  display_name         = var.user_display_name
  mail_nickname         = var.user_mail_nickname
  password              = "ApxTemp@Password2024!"   # temp password, user resets on first login

  force_password_change = true
}
```

**You need a data source first** to get your tenant's actual
domain name (you can't hardcode `apexindustries.onmicrosoft.com`
— that's not a real domain, you need YOUR tenant's real one):

```hcl
data "azuread_domains" "current" {
  only_initial = true
}
```

> `only_initial = true` filters to just your tenant's default
> `.onmicrosoft.com` domain — the one every Azure AD tenant has
> automatically, without needing a custom domain configured.

### Component 2 — Azure AD Group with the User as a Member

```hcl
resource "azuread_group" "engineers" {
  display_name     = var.group_name
  security_enabled = true

  members = [
    azuread_user.engineer.object_id
  ]
}
```

> `security_enabled = true` makes this a security group (can be
> used for RBAC role assignments) rather than a Microsoft 365
> distribution group (email-only, no access control purpose).
> For anything infrastructure-related, always use security groups.

### Component 3 — App Registration + Service Principal

```hcl
resource "azuread_application" "internal_tool" {
  display_name = var.app_display_name
}

resource "azuread_service_principal" "internal_tool_sp" {
  client_id = azuread_application.internal_tool.client_id
}
```

> Notice the relationship: the Service Principal references the
> Application's `client_id` — proving the Service Principal is
> genuinely CREATED FROM the App Registration, not independent of
> it. You cannot create a Service Principal without first having
> an Application to base it on.

### Component 4 — Variables + Outputs (with validation)

```hcl
variable "user_mail_nickname" {
  description = "Mail nickname portion of the user's UPN (before the @)"
  type        = string

  validation {
    condition     = can(regex("^[a-z]+\\.[a-z]+$", var.user_mail_nickname))
    error_message = "user_mail_nickname must be lowercase, format: firstname.lastname"
  }
}
```

Outputs:
```
user_object_id
user_principal_name
group_object_id
app_registration_client_id
service_principal_object_id
```

---

## 5. Hints

**Hint 1 — You likely need elevated permissions to run this at
all:** creating Azure AD users, groups, and app registrations
requires specific Azure AD roles (`User Administrator`, `Groups
Administrator`, or `Application Administrator` at minimum — often
just being a Global Administrator on a personal/learning tenant).
If your regular Azure account is a standard member with no admin
roles, `terraform apply` will fail with a `403 Forbidden` or
`Insufficient privileges` error. On a personal learning tenant
(the Microsoft account you signed up with), you are almost always
already the Global Administrator by default — this is usually
only an issue on a work/organizational tenant.

**Hint 2 — The temporary password has real complexity
requirements:** Azure AD enforces the same kind of password
complexity rules you saw for SQL admin passwords back in
NCT-INFRA-007 — minimum length, mixed case, number, special
character. `force_password_change = true` means this password is
genuinely temporary — the user is required to set their own on
first login, so the value in your `.tf` file is not a long-term
secret (still don't commit it — treat it with the same hygiene
as any other credential).

**Hint 3 — `azuread_group.members` expects a SET of object IDs,
not a list of email addresses or display names:** this is a very
common mistake — you must reference `azuread_user.engineer.object_id`
(the actual GUID Azure AD assigns), not the email or display name
string. If you type the email address directly into `members`,
Terraform will reject it as not being a valid object ID format.

---

## 6. Workflow (PowerShell)

```powershell
cd C:\Projects\apx-infra-001

terraform init
terraform fmt -check -recursive
terraform validate
terraform plan -out=tfplan
terraform apply tfplan

terraform state list
# Should show: azuread_user, azuread_group, azuread_application,
# azuread_service_principal, data.azuread_domains

# Verify via Azure CLI (az ad commands, different from az resource commands)
az ad user show --id (terraform output -raw user_principal_name) --output table
az ad group show --group (terraform output -raw group_object_id) --output table
az ad app show --id (terraform output -raw app_registration_client_id) --output table

# Verify group membership
az ad group member list `
  --group (terraform output -raw group_object_id) `
  --output table

terraform destroy
```

---

## 7. Checklist

```
[ ] azuread provider used — NOT azurerm — for every resource
[ ] No features{} block (that's azurerm-only)
[ ] No location or resource_group_name anywhere (AD is tenant-wide)
[ ] data.azuread_domains used to get real tenant domain, not hardcoded
[ ] Group uses security_enabled = true
[ ] Group members reference .object_id, not email strings
[ ] Service Principal references the Application's client_id
[ ] user_mail_nickname has a validation{} block
[ ] terraform state list confirms all 4 resource types created
[ ] terraform destroy completed
```

---

## 8. Cost
**Free.** Azure AD object management (users, groups, app
registrations, service principals) has zero cost regardless of
how many objects you create, on any tenant tier.

## Series Status
```
APX-001   ✅  Azure AD Fundamentals — Users, Groups, App Registrations  ← THIS PROJECT
APX-002   📋  Conditional Access + RBAC Fundamentals
```

*Apex Industries — Cloud Platform Engineering | Training Series*
