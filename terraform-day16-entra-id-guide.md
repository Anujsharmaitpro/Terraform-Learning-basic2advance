# Terraform + Azure Entra ID — Identity Management as Code
## Deep-Dive Learning Guide — Day 16 / 28 Days of Easy Terraform
### Beginner-First Edition | CSV-Driven User/Group Automation | PowerShell Throughout

---

## Before You Start

This is Day 16. By now you've covered:
- **Days 1-9:** Terraform fundamentals, providers, resources, state, variables,
  file structure, type constraints, count/for_each, lifecycle rules
- **Days 10-12:** Dynamic blocks, conditional/splat expressions, built-in functions
- **Day 13:** Data sources (reading existing infrastructure)
- **Days 14-15:** Mini projects (VMSS + Load Balancer, VNet Peering)

Today is a change of direction. Instead of provisioning compute or network
infrastructure, you're automating **identity management** — creating users
and groups in Azure Entra ID (formerly Azure Active Directory) directly
from a CSV file, entirely through Terraform.

This is one of the most practical, real-world applicable skills in the
entire series — most organisations need to onboard employees in bulk,
and doing it through code instead of manual portal clicks is exactly
the Infrastructure as Code mindset from Day 1.

---

## Table of Contents

1. What Is Azure Entra ID? (Formerly Azure Active Directory)
2. Why Manage Identity with Terraform Instead of the Portal?
3. The Azure AD Provider — A Different Provider for a Different Purpose
4. Step 1 — Reading Your Tenant's Domain with a Data Source
5. The `local.domain_name` Pattern — Storing a Data Source Value
6. Step 2 — Preparing the User Data (CSV File)
7. The `csvdecode()` Function — Turning CSV Text into Usable Data
8. Looping Over CSV Data with a `for` Expression
9. Step 3 — Creating Users with `azuread_user` and `for_each`
10. The `format()` Function — Building User Principal Names
11. Building the Password — Combining Functions
12. All Required and Optional User Fields Explained
13. Step 4 — Creating Groups with `azuread_group`
14. Group Membership — Conditional Association with `for_each` and `if`
15. Understanding the Three Groups Created
16. Service Principal Authentication for Azure AD (Your Assignment)
17. The Complete Working Code — All Files
18. Running the Deployment
19. Common Mistakes Beginners Make
20. Assignment Tasks
21. Practice Exercises
22. Complete Cheat Sheet

---

## 1. What Is Azure Entra ID? (Formerly Azure Active Directory)

### The rename you need to know about

Microsoft rebranded **Azure Active Directory (Azure AD)** to **Microsoft
Entra ID** in 2023. They are the same service — just a new name. You
will see both names used interchangeably in documentation, in the
Terraform provider (`azuread`), and in the Azure Portal navigation
(labelled "Microsoft Entra ID").

### What Entra ID actually is

Think of Entra ID as the company directory and security guard system
for your entire Azure environment. It stores:

```
Users        -> every person who can log in (employees, contractors)
Groups       -> collections of users for managing permissions together
Applications -> registered apps that can authenticate against Azure
Roles        -> what each user/group is allowed to do
```

Every time someone logs into the Azure Portal, runs `az login`, or your
Terraform Service Principal authenticates — Entra ID is the system
checking "who are you, and what are you allowed to do?"

### Connecting this to what you already know

Recall from **Day 3** (your first Azure authentication setup) and **Day 4**
(state file security) — you created a **Service Principal** using
`az ad sp create-for-rbac`. That command was creating an identity
INSIDE Entra ID. Today, you go one level deeper: managing the human
USERS and GROUPS that make up your organisation's identity structure,
using the exact same Infrastructure as Code approach.

---

## 2. Why Manage Identity with Terraform Instead of the Portal?

This connects directly to the **Day 1** lesson on why Infrastructure as
Code exists in the first place — the same six problems apply here:

```
Manual user creation in the Portal:
  - Click "New User" - fill in a form - click "Create" - repeat per person
  - For 50 new hires: 50 rounds of manual clicking (Time problem, Day 1)
  - Easy to mistype a name or department (Human Error problem, Day 1)
  - No record of WHO created WHICH user and WHY (Security problem, Day 1)
  - Different admins might set inconsistent naming conventions
    ("jsmith" vs "john.smith" vs "j.smith") - (Consistency problem, Day 1)

Terraform-managed users from a CSV:
  - One file, one command, all users created identically
  - Every user follows the exact same naming and password convention
  - The CSV file itself is a complete audit record (and can live in Git)
  - Onboarding 5 people or 500 people takes the same effort
```

### The real-world workflow this enables

```
HR adds a new employee to the company CSV
        |
        v
Pull request reviewed (just like any other code change)
        |
        v
terraform apply
        |
        v
New user account + correct group memberships exist in Entra ID
        |
        v
Employee receives their login credentials
```

This is genuinely how many companies provision employee accounts today.

---

## 3. The Azure AD Provider — A Different Provider for a Different Purpose

### Recap: what a provider is (from Day 2)

A provider is the plugin that translates your Terraform code into API
calls for a specific service. So far in this series you've used
`azurerm` — the provider for Azure RESOURCES (VMs, networks, storage).

Today introduces `azuread` — a SEPARATE provider specifically for Azure
Entra ID (identity) operations. It is maintained by HashiCorp, just like
`azurerm`, but it talks to a completely different Azure API surface.

```hcl
# versions.tf (or providers.tf)

terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"   # the instructor used v2; v3 also exists
    }
  }
}

provider "azuread" {
  # No 'features {}' block needed here - that's an azurerm-specific requirement
}
```

### Why no `azurerm` provider is needed today

Applying the **Day 2** lesson on choosing the right provider for the job:
since this video doesn't provision any VMs, storage, or networking — only
identity resources — there's no need to declare or configure `azurerm` at
all. Using only what you actually need keeps your configuration simpler
and your `terraform init` faster.

### Authentication for the `azuread` provider

Just like `azurerm` (covered in **Day 3**), the `azuread` provider needs
credentials. By default, it uses the same Azure CLI session
(`az login`) or the same `ARM_*` environment variables you've used
throughout this series. Section 16 covers setting up a dedicated Service
Principal specifically for Entra ID management (your assignment for
this video).

---

## 4. Step 1 — Reading Your Tenant's Domain with a Data Source

### Connecting to Day 13 — Data Sources

Recall **Day 13**: a data source READS existing information without
creating, modifying, or destroying anything. Today's first task is a
perfect data source use case — you need to know your organisation's
domain name (e.g., `yourcompany.onmicrosoft.com`) to build user email
addresses, but you didn't create that domain — Azure assigned it when
your tenant was set up.

### The data source

```hcl
data "azuread_domains" "aad_domains" {
  only_initial = true
  # "initial" = the default domain Azure automatically assigned
  #             to your tenant when it was created
  #             (e.g., "yourcompany.onmicrosoft.com")
}
```

### Understanding the arguments

The instructor explored two optional filtering arguments:

```hcl
data "azuread_domains" "aad_domains" {
  # Option 1: only return the tenant's DEFAULT domain
  only_default = true

  # Option 2: only return the tenant's INITIAL domain
  # (the one automatically created - usually what you want)
  only_initial = true

  # Leave both blank to get ALL domains associated with the tenant
}
```

### Why this returns a LIST, not a single value

A tenant can have multiple verified domains (e.g., a company might own
`company.com`, `company.onmicrosoft.com`, AND `company-dev.onmicrosoft.com`).
So `data.azuread_domains.aad_domains.domains` is always a LIST of domain
objects — even when you've filtered down to just one.

```hcl
# Accessing the list (returns an array):
data.azuread_domains.aad_domains.domains[*].domain_name
# Example result: ["yourcompany.onmicrosoft.com"]

# Accessing just the first item's name:
data.azuread_domains.aad_domains.domains[0].domain_name
# Example result: "yourcompany.onmicrosoft.com"
```

### Connecting to Day 10 — Splat Expressions

Recall **Day 10**'s splat expression `[*]` — it extracts one field from
every item in a list. That's exactly what's happening here:

```hcl
domains[*].domain_name
#       ^^^ splat: "give me the domain_name field from EVERY item"
```

Since the instructor filtered with `only_initial = true`, there's exactly
one domain in the resulting list — but the splat syntax works the same
whether there's one item or many.

---

## 5. The `local.domain_name` Pattern — Storing a Data Source Value

### Connecting to Day 5 and Day 6 — Locals

Recall **Day 5** (locals deep dive) and **Day 6** (file structure best
practices): when a value will be reused in multiple places, store it
in a `local` once rather than repeating the full data source reference
everywhere.

```hcl
locals {
  domain_name = data.azuread_domains.aad_domains.domains[*].domain_name
}
```

### Output to verify it's correct

```hcl
output "domain" {
  value = local.domain_name
}
```

**PowerShell:**
```powershell
terraform plan
# Outputs section will show:
# domain = tolist([
#   "yourcompany.onmicrosoft.com",
# ])
```

### Why the instructor switched from `[*]` to `[0]`

After confirming the data was correct, the instructor refined the local
to grab the SINGLE domain name string (not a one-item list) — because
every downstream usage (building user emails) needs a plain string, not
a list:

```hcl
locals {
  # [0] gets just the first (and only) domain as a plain string
  domain_name = data.azuread_domains.aad_domains.domains[0].domain_name
}
```

```powershell
terraform plan
# domain = "yourcompany.onmicrosoft.com"   <- now a plain string, not a list
```

This is a subtle but important lesson: choose `[*]` (splat, returns a list)
when you need ALL items, and `[0]` (index, returns a single item) when
you know there's exactly one value you care about.

---

## 6. Step 2 — Preparing the User Data (CSV File)

### The CSV file structure

**`users.csv`**
```csv
first_name,last_name,department,job_title
Michael,Scott,Education,Manager
Jim,Halpert,Education,Engineer
Pam,Beesly,Education,Engineer
```

### Why a CSV file instead of a Terraform variable?

This connects to **Day 5**'s lesson on variable precedence and **Day 11/12**'s
functions deep dive: CSV is a format that NON-TECHNICAL people (like HR)
can edit easily in Excel or Google Sheets, without needing to understand
HCL syntax. Terraform then reads and transforms that simple format into
the structured data it needs.

```
HR-friendly format:        Terraform-friendly format:
-------------------        --------------------------
users.csv (plain text,     A list of maps, ready for
opens in Excel)             for_each iteration
```

### What the columns map to

```
first_name  -> used in display name, user principal name, password
last_name   -> used in display name, user principal name, password
department  -> used to assign group membership (Education group)
job_title   -> used to assign group membership (Manager / Engineer groups)
```

---

## 7. The `csvdecode()` Function — Turning CSV Text into Usable Data

### Connecting to Day 11 — Functions

Recall **Day 11**'s deep dive into Terraform's built-in functions
(`lower`, `replace`, `merge`, `substr`, `split`). Today introduces a
new one: `csvdecode()` — a function specifically for parsing CSV-formatted
text into a list of maps.

### The function signature

```hcl
csvdecode(csv_string)
# Input:  raw CSV text (with a header row)
# Output: a list of maps, one map per data row,
#         using the header row as the map keys
```

### Combining with `file()` (also from Day 12)

```hcl
locals {
  users = csvdecode(file("${path.module}/users.csv"))
}
```

Breaking this down inside-out (the **function nesting** technique from
**Day 11**):
```
1. file("${path.module}/users.csv")
   -> reads the raw text content of the CSV file as a string

2. csvdecode( ...that string... )
   -> parses it into a list of maps
```

### What `local.users` looks like after decoding

```hcl
local.users = [
  {
    first_name = "Michael"
    last_name  = "Scott"
    department = "Education"
    job_title  = "Manager"
  },
  {
    first_name = "Jim"
    last_name  = "Halpert"
    department = "Education"
    job_title  = "Engineer"
  },
  {
    first_name = "Pam"
    last_name  = "Beesly"
    department = "Education"
    job_title  = "Engineer"
  }
]
```

Each row of the CSV becomes one map. The header row (`first_name,last_name,...`)
automatically becomes the keys of each map.

### Testing in `terraform console` (technique from Day 11)

**PowerShell:**
```powershell
terraform console
```
```
> csvdecode(file("./users.csv"))
[
  {
    "department" = "Education"
    "first_name" = "Michael"
    "job_title" = "Manager"
    "last_name" = "Scott"
  },
  ...
]

> exit
```

---

## 8. Looping Over CSV Data with a `for` Expression

### Connecting to Day 8 — The `for` Loop

Recall **Day 8**'s lesson: a `for` loop (different from `for_each` meta-argument)
is used to TRANSFORM a collection — most commonly inside output values or
locals — not to create resources directly.

### Printing all usernames (verification step)

```hcl
output "usernames" {
  value = [
    for user in local.users : "${user.first_name} ${user.last_name}"
  ]
}
```

### Tracing the iteration

```
Iteration 1: user = { first_name="Michael", last_name="Scott", ... }
             Result: "Michael Scott"

Iteration 2: user = { first_name="Jim", last_name="Halpert", ... }
             Result: "Jim Halpert"

Iteration 3: user = { first_name="Pam", last_name="Beesly", ... }
             Result: "Pam Beesly"

Final output: ["Michael Scott", "Jim Halpert", "Pam Beesly"]
```

### The instructor's exact error and fix

The instructor's first attempt forgot to reference the loop variable
correctly:

```hcl
# WRONG - "first_name" alone has no context; Terraform doesn't know
# which resource or variable this belongs to
output "usernames" {
  value = [for user in local.users : first_name]
}
# Error: a reference to a resource type must be followed by at least
# one attribute access

# CORRECT - must use the loop variable (user) to access its fields
output "usernames" {
  value = [for user in local.users : "${user.first_name} ${user.last_name}"]
}
```

This is the same class of mistake covered in **Day 8**'s common-mistakes
section — every field access inside a `for` expression must go through
the loop variable, not be referenced as a bare attribute name.

---

## 9. Step 3 — Creating Users with `azuread_user` and `for_each`

### Connecting to Day 8 — `for_each` for Resource Creation

Recall **Day 8**: `for_each` creates ONE resource per item in a map or
set, and tracks each by a stable KEY (not a numeric index like `count`).
This is exactly the right tool for creating one Entra ID user per row
in the CSV.

### Why `for_each`, not `count`, for users

Applying the **Day 8** decision framework:
```
- Each user has a meaningful identity (their name) - not just a number
- You might add/remove individual users later without disturbing others
- This matches the for_each use case perfectly
```

### The resource block

```hcl
resource "azuread_user" "users" {
  for_each = { for user in local.users : "${user.first_name}_${user.last_name}" => user }
  # Using a composite key (first_name_last_name) as the map key
  # ensures uniqueness even if two people share a first name

  user_principal_name = format(
    "%s%s@%s",
    lower(substr(each.value.first_name, 0, 1)),
    lower(each.value.last_name),
    local.domain_name
  )

  display_name = "${each.value.first_name} ${each.value.last_name}"

  password = format(
    "%s%s%d!",
    lower(each.value.last_name),
    lower(substr(each.value.first_name, 0, 1)),
    length(each.value.first_name)
  )

  force_password_change = true

  department = each.value.department
  job_title  = each.value.job_title
}
```

### Why `for_each` needs a MAP here, not the raw list

Connecting directly to **Day 8**'s critical rule: `for_each` does NOT
accept a list — it requires a map or a set, because list items can be
ambiguous/duplicated. `local.users` (from `csvdecode`) is a LIST of maps.
The fix is to transform it into a MAP using a `for` expression that
produces key-value pairs:

```hcl
{ for user in local.users : "${user.first_name}_${user.last_name}" => user }
#  the KEY (must be unique)                                    the VALUE (the whole user map)
```

This is the exact `for_each`-needs-a-map pattern from **Day 8**, applied
to CSV-sourced data.

---

## 10. The `format()` Function — Building User Principal Names

### Connecting to Day 11 — String Functions

Recall **Day 11**'s `format()` function — sprintf-style string templating.

### The format string breakdown

```hcl
format("%s%s@%s", first_letter, last_name, domain)
#        |  |   |
#        |  |   third %s -> domain
#        |  second %s -> last_name
#        first %s -> first_letter
```

`%s` is a placeholder meaning "insert a string value here, in order."

### Tracing the full expression for "Michael Scott"

```hcl
user_principal_name = format(
  "%s%s@%s",
  lower(substr(each.value.first_name, 0, 1)),   # "M" -> substr -> "M" -> lower -> "m"
  lower(each.value.last_name),                   # "Scott" -> lower -> "scott"
  local.domain_name                              # "yourcompany.onmicrosoft.com"
)

Step by step:
  substr("Michael", 0, 1)     -> "M"        (first character only)
  lower("M")                  -> "m"
  lower("Scott")               -> "scott"
  local.domain_name            -> "yourcompany.onmicrosoft.com"

  format("%s%s@%s", "m", "scott", "yourcompany.onmicrosoft.com")
  -> "mscott@yourcompany.onmicrosoft.com"
```

### Why `substr` + `lower` together (function nesting, from Day 11)

This is the exact **function nesting** pattern taught in Day 11:
inner function results feed into outer functions:

```hcl
lower(substr(each.value.first_name, 0, 1))
       inner: get 1st char  -> "M"
outer: lowercase it     -> "m"
```

---

## 11. Building the Password — Combining Functions

### The default password pattern

```hcl
password = format(
  "%s%s%d!",
  lower(each.value.last_name),                    # "scott"
  lower(substr(each.value.first_name, 0, 1)),      # "m"
  length(each.value.first_name)                    # 7 (length of "Michael")
)
```

### Tracing it for "Michael Scott"

```
lower("Scott")                  -> "scott"
lower(substr("Michael", 0, 1))  -> "m"
length("Michael")                -> 7

format("%s%s%d!", "scott", "m", 7)
-> "scottm7!"
```

### Why `%d` instead of `%s` for the length

```
%s  -> formats as a STRING
%d  -> formats as a DECIMAL (number)
```

`length()` returns a number, so `%d` is the correct placeholder. Using
`%s` would also technically work (Terraform auto-converts), but `%d` is
more precise and self-documenting about the expected type — connecting
back to **Day 7**'s emphasis on using the correct type constraints.

### Why `force_password_change = true` matters

```hcl
force_password_change = true
```

This means the auto-generated password is TEMPORARY — the user must set
their own password on first login. This is a security best practice:
nobody's real, long-term password should be a predictable
`lastnameF#!`-style pattern that's visible in your Terraform state file
or CSV. The generated password only needs to get them through their
FIRST login.

---

## 12. All Required and Optional User Fields Explained

### Required fields (Terraform errors without these)

```hcl
resource "azuread_user" "users" {
  user_principal_name = "..."   # REQUIRED - the unique login identity
  display_name         = "..."   # REQUIRED - how the name appears in the UI
  password              = "..."   # REQUIRED - initial password
}
```

The instructor hit both of these errors in sequence — first missing
`user_principal_name`, then after adding it, missing `display_name` —
each time Terraform's error message told him exactly which required
field was still missing.

### Optional fields used in this project

```hcl
resource "azuread_user" "users" {
  # ... required fields above ...

  force_password_change = true                  # require password reset on first login
  department             = each.value.department  # shown in the user's profile
  job_title              = each.value.job_title    # shown in the user's profile
}
```

### How to find the FULL list of available fields

Connecting to the **Day 3** lesson on reading Terraform documentation:
search the Terraform Registry for `azuread_user`, and check the
**Argument Reference** section — exactly the same workflow used for
every Azure resource throughout this series.

---

## 13. Step 4 — Creating Groups with `azuread_group`

### Why groups exist (RBAC simplification)

This connects to a fundamental cloud security principle: instead of
assigning permissions to each of your (potentially hundreds of) users
individually, you assign permissions ONCE to a GROUP, then simply add
or remove users from that group. This is **Role-Based Access Control (RBAC)**
applied at the identity layer.

```
WITHOUT groups:
  50 employees x individual permission assignments = 50 places to manage

WITH groups:
  3 groups x permission assignment = 3 places to manage
  50 employees just need group membership (much simpler to audit)
```

### The three groups this project creates

```
Group 1: "Education Department"  -> all users where department = "Education"
Group 2: "Managers"               -> all users where job_title = "Manager"
Group 3: "Engineers"               -> all users where job_title = "Engineer"
```

### The group resource

```hcl
resource "azuread_group" "education" {
  display_name     = "Education Department"
  security_enabled = true
}

resource "azuread_group" "managers" {
  display_name     = "Managers"
  security_enabled = true
}

resource "azuread_group" "engineers" {
  display_name     = "Engineers"
  security_enabled = true
}
```

`security_enabled = true` marks this as a security group (used for
access control), as opposed to a Microsoft 365 distribution group
(used for email lists).

---

## 14. Group Membership — Conditional Association with `for_each` and `if`

### The membership resource

```hcl
resource "azuread_group_member" "education_members" {
  for_each = {
    for key, user in azuread_user.users : key => user
    if user.department == "Education"
  }

  group_object_id  = azuread_group.education.object_id
  member_object_id = each.value.object_id
}
```

### Understanding the `for ... if ...` filter pattern

Connecting to **Day 8**'s `for` loop filtering technique:

```hcl
{
  for key, user in azuread_user.users : key => user
  if user.department == "Education"
}
#          base iteration                    FILTER condition
#                                       only include items where this is true
```

This produces a map containing ONLY the users whose department is
"Education" — everyone else is excluded from this particular `for_each`.

### Tracing through the three users

```
azuread_user.users contains:
  "Michael_Scott" -> { department="Education", job_title="Manager", ... }
  "Jim_Halpert"   -> { department="Education", job_title="Engineer", ... }
  "Pam_Beesly"    -> { department="Education", job_title="Engineer", ... }

Filter: department == "Education"
  Michael_Scott -> PASSES (Education) -> included
  Jim_Halpert   -> PASSES (Education) -> included
  Pam_Beesly    -> PASSES (Education) -> included

Result: all THREE users join the Education group
```

### The Managers group — different filter

```hcl
resource "azuread_group_member" "manager_members" {
  for_each = {
    for key, user in azuread_user.users : key => user
    if user.job_title == "Manager"
  }

  group_object_id  = azuread_group.managers.object_id
  member_object_id = each.value.object_id
}
```

```
Filter: job_title == "Manager"
  Michael_Scott -> PASSES (Manager) -> included
  Jim_Halpert   -> FAILS (Engineer) -> excluded
  Pam_Beesly    -> FAILS (Engineer) -> excluded

Result: only Michael Scott joins the Managers group
```

### The Engineers group

```hcl
resource "azuread_group_member" "engineer_members" {
  for_each = {
    for key, user in azuread_user.users : key => user
    if user.job_title == "Engineer"
  }

  group_object_id  = azuread_group.engineers.object_id
  member_object_id = each.value.object_id
}
```

```
Filter: job_title == "Engineer"
  Michael_Scott -> FAILS (Manager) -> excluded
  Jim_Halpert   -> PASSES (Engineer) -> included
  Pam_Beesly    -> PASSES (Engineer) -> included

Result: Jim and Pam join the Engineers group
```

### The implicit dependency this creates

Connecting to **Day 3**'s implicit dependency lesson: by referencing
`azuread_user.users` inside the `for_each`, Terraform automatically knows
all users must be created BEFORE any group membership resources are
created. No `depends_on` needed — the reference itself establishes the
correct order.

---

## 15. Understanding the Three Groups Created

### Visual summary

```
                    Education Department Group
                    - Michael Scott  (Manager)
                    - Jim Halpert    (Engineer)
                    - Pam Beesly     (Engineer)

                    Managers Group
                    - Michael Scott

                    Engineers Group
                    - Jim Halpert
                    - Pam Beesly
```

A single user can belong to MULTIPLE groups simultaneously — Michael
Scott is in both "Education Department" AND "Managers". This models
real organisational structure, where someone has both a department and
a role-based group membership.

### Total resources created

```
3 azuread_user                (Michael, Jim, Pam)
3 azuread_group               (Education, Managers, Engineers)
3 + 1 + 2 = 6 azuread_group_member  (3 in Education, 1 in Managers, 2 in Engineers)
-----------------------------------------------
12 total resources (matches "9 resources" the instructor mentioned for
                     the group-related portion alone: 3 groups + 6 memberships)
```

---

## 16. Service Principal Authentication for Azure AD (Your Assignment)

### Why this matters — connecting to Day 3 and Day 4

Recall **Day 3**: you created a Service Principal with `az ad sp create-for-rbac`
and a Contributor role for managing Azure RESOURCES. Recall **Day 4**:
why personal credentials should never be used for automated/production
Terraform runs.

The SAME principle applies here — but Entra ID operations need a
DIFFERENT permission set than resource management. A Service Principal
with "Contributor" on a subscription CANNOT manage users and groups —
Entra ID permissions are granted separately, at the **Microsoft Graph
API** level.

### The required API permissions

```
Domain.Read.All    -> allows reading tenant domains (the data source step)
User.ReadWrite.All  -> allows creating, updating, deleting users
Group.ReadWrite.All -> allows creating, updating, deleting groups
```

### Setting up the Service Principal (PowerShell)

```powershell
# Step 1: Create an App Registration (this becomes your Service Principal)
$app = az ad app create --display-name "terraform-entra-automation" | ConvertFrom-Json

# Step 2: Create the Service Principal for that app
$sp = az ad sp create --id $app.appId | ConvertFrom-Json

# Step 3: Create a client secret (password) for authentication
$secret = az ad app credential reset --id $app.appId --append | ConvertFrom-Json

# Step 4: Grant the required Microsoft Graph API permissions
# (Domain.Read.All, User.ReadWrite.All, Group.ReadWrite.All)
az ad app permission add `
  --id $app.appId `
  --api 00000003-0000-0000-c000-000000000000 `
  --api-permissions `
    'dbb9058a-0e50-45d7-ae91-66909b5d4664=Role' `
    '741f803b-c850-494e-b5df-cde7c675a1ca=Role' `
    '62a82d76-70ea-41e2-9197-370581804d09=Role'

# Step 5: Grant admin consent (requires Global Admin or Privileged Role Admin)
az ad app permission admin-consent --id $app.appId

# Step 6: Get your tenant ID
$tenantId = az account show --query tenantId -o tsv
```

### Setting the environment variables (never hardcode in `.tf` files)

This is the exact pattern from **Day 3** and **Day 5** — credentials go
in environment variables, never in version-controlled code:

```powershell
$env:ARM_CLIENT_ID       = $app.appId
$env:ARM_CLIENT_SECRET   = $secret.password
$env:ARM_TENANT_ID       = $tenantId

# Note: ARM_SUBSCRIPTION_ID is not required for azuread-only operations
# since there's no Azure RM subscription-scoped resource being created
```

### Verifying it works

```powershell
terraform plan
# Should authenticate using the Service Principal instead of your
# personal Azure CLI session
```

---

## 17. The Complete Working Code — All Files

**`versions.tf`**
```hcl
terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
  }
}

provider "azuread" {}
```

---

**`users.csv`**
```csv
first_name,last_name,department,job_title
Michael,Scott,Education,Manager
Jim,Halpert,Education,Engineer
Pam,Beesly,Education,Engineer
```

---

**`main.tf`**
```hcl
# Domain Data Source
data "azuread_domains" "aad_domains" {
  only_initial = true
}

# Read CSV Users
locals {
  domain_name = data.azuread_domains.aad_domains.domains[0].domain_name
  users       = csvdecode(file("${path.module}/users.csv"))
}

# Create Users
resource "azuread_user" "users" {
  for_each = { for user in local.users : "${user.first_name}_${user.last_name}" => user }

  user_principal_name = format(
    "%s%s@%s",
    lower(substr(each.value.first_name, 0, 1)),
    lower(each.value.last_name),
    local.domain_name
  )

  display_name = "${each.value.first_name} ${each.value.last_name}"

  password = format(
    "%s%s%d!",
    lower(each.value.last_name),
    lower(substr(each.value.first_name, 0, 1)),
    length(each.value.first_name)
  )

  force_password_change = true
  department             = each.value.department
  job_title              = each.value.job_title
}
```

---

**`groups.tf`**
```hcl
# Groups
resource "azuread_group" "education" {
  display_name     = "Education Department"
  security_enabled = true
}

resource "azuread_group" "managers" {
  display_name     = "Managers"
  security_enabled = true
}

resource "azuread_group" "engineers" {
  display_name     = "Engineers"
  security_enabled = true
}

# Group Memberships
resource "azuread_group_member" "education_members" {
  for_each = {
    for key, user in azuread_user.users : key => user
    if user.department == "Education"
  }
  group_object_id  = azuread_group.education.object_id
  member_object_id = each.value.object_id
}

resource "azuread_group_member" "manager_members" {
  for_each = {
    for key, user in azuread_user.users : key => user
    if user.job_title == "Manager"
  }
  group_object_id  = azuread_group.managers.object_id
  member_object_id = each.value.object_id
}

resource "azuread_group_member" "engineer_members" {
  for_each = {
    for key, user in azuread_user.users : key => user
    if user.job_title == "Engineer"
  }
  group_object_id  = azuread_group.engineers.object_id
  member_object_id = each.value.object_id
}
```

---

**`outputs.tf`**
```hcl
output "domain" {
  description = "Tenant's initial domain name"
  value       = local.domain_name
}

output "usernames" {
  description = "Full names of all users from the CSV"
  value       = [for user in local.users : "${user.first_name} ${user.last_name}"]
}

output "user_principal_names" {
  description = "Generated login identities for all created users"
  value       = { for key, user in azuread_user.users : key => user.user_principal_name }
}
```

---

## 18. Running the Deployment

**PowerShell — full workflow:**

```powershell
Set-Location "C:\projects\day16"

# Use your Service Principal credentials (Section 16) or az login
$env:ARM_CLIENT_ID     = "your-client-id"
$env:ARM_CLIENT_SECRET = "your-client-secret"
$env:ARM_TENANT_ID     = "your-tenant-id"

terraform init
terraform validate

# Verify domain and usernames look correct before creating anything
terraform plan

terraform apply --auto-approve

# Check what was created
terraform output

# Verify in the portal (Microsoft Entra ID -> Users / Groups)
az ad user list --query "[].displayName" -o table
az ad group list --query "[].displayName" -o table

# Clean up when done testing
terraform destroy --auto-approve

Remove-Item Env:ARM_CLIENT_ID
Remove-Item Env:ARM_CLIENT_SECRET
Remove-Item Env:ARM_TENANT_ID
```

---

## 19. Common Mistakes Beginners Make

### Mistake 1 — Trying to use `count` instead of `for_each` for CSV-driven users

Connecting to **Day 8**: since each user needs a stable, meaningful
identity (not a numeric index), `for_each` is correct here — using
`count` would risk the index-shift danger covered in Day 8 if the CSV
order ever changes.

### Mistake 2 — Forgetting `for_each` requires a map, not the raw CSV list

```hcl
# WRONG - local.users is a LIST (from csvdecode), for_each needs a map/set
resource "azuread_user" "users" {
  for_each = local.users   # Error: must be map or set
}

# CORRECT - transform the list into a map first
resource "azuread_user" "users" {
  for_each = { for user in local.users : "${user.first_name}_${user.last_name}" => user }
}
```

This is precisely the **Day 8** `for_each`-needs-a-map rule applied to CSV data.

### Mistake 3 — Referencing a bare field name inside a `for` loop

```hcl
# WRONG
[for user in local.users : first_name]

# CORRECT - must go through the loop variable
[for user in local.users : user.first_name]
```

### Mistake 4 — Missing required `user_principal_name` or `display_name`

Terraform's error messages name the exact missing field — always read
the full error text rather than guessing.

### Mistake 5 — Hardcoding the domain name instead of using the data source

```hcl
# FRAGILE - breaks if the tenant's domain ever changes
user_principal_name = "${first_letter}${last_name}@mycompany.onmicrosoft.com"

# ROBUST - always reflects the actual current tenant domain
user_principal_name = format("%s%s@%s", first_letter, last_name, local.domain_name)
```

### Mistake 6 — Using Contributor role Service Principal for Entra ID operations

A Service Principal with subscription-level "Contributor" role (from
Day 3) CANNOT manage users and groups. You need separate Microsoft
Graph API permissions (Section 16).

---

## 20. Assignment Tasks

The instructor gave two explicit assignments:

### Task 1 — Set Up Service Principal Authentication

Implement the full Service Principal setup from Section 16, replacing
your personal `az login` session with dedicated automation credentials.

### Task 2 — Expand the CSV with More Users

Add more rows to `users.csv` (the instructor suggested "Dwight Schrute,"
"Kevin Malone," and others), and either:
- Fit them into the existing three groups, OR
- Create a new group (e.g., "Sales") and adjust the filter conditions

**Example expanded CSV:**
```csv
first_name,last_name,department,job_title
Michael,Scott,Education,Manager
Jim,Halpert,Education,Engineer
Pam,Beesly,Education,Engineer
Dwight,Schrute,Sales,Manager
Kevin,Malone,Sales,Engineer
```

---

## 21. Practice Exercises

### Exercise 1 — Trace the User Principal Name

Given `first_name = "Dwight"`, `last_name = "Schrute"`,
`domain_name = "acmecorp.onmicrosoft.com"`, trace through the `format()`
expression and compute the resulting `user_principal_name`.

**Answer:**
```
substr("Dwight", 0, 1) -> "D"
lower("D")              -> "d"
lower("Schrute")        -> "schrute"

format("%s%s@%s", "d", "schrute", "acmecorp.onmicrosoft.com")
-> "dschrute@acmecorp.onmicrosoft.com"
```

### Exercise 2 — Trace the Password

Using the same user, compute the generated password.

**Answer:**
```
lower("Schrute")               -> "schrute"
lower(substr("Dwight", 0, 1))  -> "d"
length("Dwight")                 -> 6

format("%s%s%d!", "schrute", "d", 6)
-> "schruted6!"
```

### Exercise 3 — Write a New Group Filter

Write the `azuread_group_member` resource for a new "Sales" group that
includes any user where `department == "Sales"`.

**Answer:**
```hcl
resource "azuread_group" "sales" {
  display_name     = "Sales"
  security_enabled = true
}

resource "azuread_group_member" "sales_members" {
  for_each = {
    for key, user in azuread_user.users : key => user
    if user.department == "Sales"
  }
  group_object_id  = azuread_group.sales.object_id
  member_object_id = each.value.object_id
}
```

### Exercise 4 — Identify the Provider

For each task below, which provider (`azurerm` or `azuread`) would you use?

```
a) Create a Storage Account
b) Create a new Entra ID user
c) Create a Resource Group
d) Add a user to a security group
e) Read the tenant's verified domains
```

**Answer:**
```
a) azurerm
b) azuread
c) azurerm
d) azuread
e) azuread
```

---

## 22. Complete Cheat Sheet

```
================================================================================
        TERRAFORM + AZURE ENTRA ID - DAY 16 QUICK REFERENCE
================================================================================
  PROVIDER
  azuread (NOT azurerm) -> for Entra ID identity management
  No features {} block needed (that's azurerm-specific)
--------------------------------------------------------------------------------
  DATA SOURCE - READ TENANT DOMAIN
  data "azuread_domains" "aad_domains" { only_initial = true }
  Access: data.azuread_domains.aad_domains.domains[0].domain_name
--------------------------------------------------------------------------------
  CSV PARSING
  csvdecode(file("./users.csv"))
  -> list of maps, one per CSV row, header row = map keys
--------------------------------------------------------------------------------
  for_each NEEDS A MAP - CONVERT THE CSV LIST FIRST
  { for user in local.users : "${user.first_name}_${user.last_name}" => user }
  KEY (must be unique)                                          VALUE
--------------------------------------------------------------------------------
  CREATING A USER (required fields)
  resource "azuread_user" "users" {
    for_each              = { ...map... }
    user_principal_name   = "..."   <- REQUIRED
    display_name           = "..."   <- REQUIRED
    password                = "..."   <- REQUIRED
    force_password_change  = true   (optional, recommended)
    department              = each.value.department
    job_title                = each.value.job_title
  }
--------------------------------------------------------------------------------
  format() FOR STRING BUILDING
  format("%s%s@%s", first_letter, last_name, domain)
  %s = string placeholder    %d = number placeholder
--------------------------------------------------------------------------------
  FUNCTION NESTING (from Day 11) APPLIED HERE
  lower(substr(each.value.first_name, 0, 1))
        inner: get 1st char  ->  outer: lowercase it
--------------------------------------------------------------------------------
  GROUPS + FILTERED MEMBERSHIP
  resource "azuread_group" "name" {
    display_name     = "..."
    security_enabled = true
  }

  resource "azuread_group_member" "name" {
    for_each = {
      for key, user in azuread_user.users : key => user
      if user.department == "Education"   <- FILTER condition
    }
    group_object_id  = azuread_group.name.object_id
    member_object_id = each.value.object_id
  }
--------------------------------------------------------------------------------
  SERVICE PRINCIPAL FOR ENTRA ID (different permissions than azurerm SP)
  Required Graph API permissions:
    Domain.Read.All
    User.ReadWrite.All
    Group.ReadWrite.All
  (Subscription "Contributor" role from Day 3 does NOT grant these)
--------------------------------------------------------------------------------
  POWERSHELL
  $env:ARM_CLIENT_ID / ARM_CLIENT_SECRET / ARM_TENANT_ID
  terraform init / plan / apply --auto-approve / destroy --auto-approve
  az ad user list --query "[].displayName" -o table
  az ad group list --query "[].displayName" -o table
================================================================================
```

---

## How This Connects to the Whole Series So Far

```
Day 1  (IaC fundamentals)     -> why automate user onboarding at all
Day 2  (Providers)            -> azuread is a NEW provider, same concept
Day 3  (Resources, auth)      -> Service Principal pattern reused for Entra ID
Day 4  (State security)       -> the state file now holds user passwords - secure it!
Day 5  (Variables, locals)    -> local.domain_name, local.users patterns
Day 7  (Type constraints)     -> map(string) shape of CSV-decoded data
Day 8  (for_each, for loops)  -> the CORE mechanism for CSV-driven user creation
Day 10 (Splat expressions)    -> domains[*].domain_name
Day 11 (Functions)            -> format(), lower(), substr(), length()
Day 12 (Functions, sensitive) -> file(), csvdecode(), password handling
Day 13 (Data sources)         -> data "azuread_domains" for tenant info
```

Today's video is a direct synthesis of nearly every concept from the
first 13 days, applied to a completely new domain (identity instead of
infrastructure) — proof that the same Terraform patterns apply everywhere.

---

*Guide covers: Azure Entra ID (formerly Azure Active Directory), azuread
Terraform provider, azuread_domains data source, only_initial vs only_default
filtering, local.domain_name pattern, csvdecode function, file function for
CSV reading, for expression iteration over CSV data, for_each with CSV-derived
maps, azuread_user resource, user_principal_name construction, format function
sprintf-style placeholders %s and %d, function nesting with substr and lower,
auto-generated password patterns, force_password_change, azuread_group resource,
security_enabled groups, azuread_group_member resource, conditional for-if
filtering for group membership, RBAC simplification through groups, Service
Principal setup for Microsoft Graph API permissions, Domain.Read.All,
User.ReadWrite.All, Group.ReadWrite.All, az ad app create, az ad sp create,
az ad app permission add, az ad app permission admin-consent, PowerShell
environment variable credential management, cross-referencing prior days'
concepts (providers, data sources, for_each, functions, locals).*
