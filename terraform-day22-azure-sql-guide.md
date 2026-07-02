# Terraform + Azure SQL Database — Provisioning a Managed SQL Server
## Deep-Dive Learning Guide — Day 22 / 28 Days of Easy Terraform
### Beginner-First Edition | PowerShell Throughout

---

## Before You Start

This is Day 22. The source video is a collaborative, guest-hosted
session — a second presenter builds an Azure SQL Server, a database
inside it, and a firewall rule live, working through several genuine
mistakes along the way (a hardcoded provider version, a hardcoded
password, a location-format false alarm, a global-uniqueness naming
collision, a missing environment variable). That's actually useful
material to learn from, because production debugging looks exactly
like this — but I'm not going to reproduce the guesswork uncritically.
This guide explains the concepts clearly, flags each mistake plainly
as a mistake with the correct fix, and gives you a cleaned-up final
configuration rather than a transcript of trial and error.

Two things worth flagging before you build anything from this guide:
the demo explicitly acknowledges (its own presenters say so on camera)
that hardcoding a database password and exposing a SQL Server to a
public IP are bad practices done only for demo convenience. I'm
treating that acknowledgment as license to show you the *correct*
approach directly, rather than the intentionally-flawed one.

---

## Table of Contents

1. What Is Azure SQL Database? (Managed vs Self-Managed)
2. The Architecture — Server, Database, Firewall Rule
3. Provider Version — A Correction on Hardcoding
4. The Provider Block, Done Correctly
5. Clearing Up the "East US" Location Confusion
6. The Resource Group — Familiar Ground
7. A Deprecated Resource You Should Know About
8. Building the SQL Server Resource
9. The Hardcoded Password Problem — And the Correct Fix
10. Building the Database Resource
11. Why "Resource Already Exists" Happened — Global Uniqueness Revisited
12. The `ARM_SUBSCRIPTION_ID` Requirement — A Provider Behavior Worth Understanding
13. The Firewall Rule — And Why "My Public IP Only" Still Isn't Production-Safe
14. A Stronger Alternative: Azure AD-Only Authentication
15. Connecting with a SQL Client
16. The Missing Output Block — Fixed
17. Complete Corrected Working Code
18. The Assignment Left as Homework — VNet-Scoped Access
19. Common Mistakes
20. Practice Exercises
21. Summary Reference

---

## 1. What Is Azure SQL Database? (Managed vs Self-Managed)

Azure SQL Database is a **Platform-as-a-Service (PaaS)** offering —
Microsoft manages the underlying operating system, SQL Server engine
patching, backups, and high-availability infrastructure. You interact
with two logical objects: a **SQL Server** (a logical management
container — despite the name, it isn't literally "a server" you patch
or reboot) and one or more **databases** created inside that server.

This is the same PaaS-vs-IaaS distinction Day 17 established for App
Service versus a self-managed VM: with a VM-hosted SQL Server (an
IaaS approach), you'd own OS patching, SQL Server version upgrades,
and backup configuration yourself. With Azure SQL Database, Microsoft
owns all of that — you own the schema, the data, and access control.

---

## 2. The Architecture — Server, Database, Firewall Rule

Three resources, in dependency order:

1. **Resource Group** — the container, as in every prior project
2. **SQL Server** (a logical container for one or more databases,
   plus the authentication and networking boundary)
3. **Database** — created inside the SQL Server, referencing it by ID
4. **Firewall Rule** — a SQL-Server-level rule permitting a specific
   IP range to connect; without one, all external connections are
   blocked by default, which is the correct secure default, not a bug

---

## 3. Provider Version — A Correction on Hardcoding

The video sets `version = "4.8.0"` — an exact pin, with no operator.
The presenter himself calls this out as something he wouldn't
recommend and frames it as an exercise for viewers to fix. Worth
resolving that directly here rather than leaving it as an open
question: this is exactly the **Day 2** version-constraint lesson.
An exact pin (`= "4.8.0"`) blocks every future patch release,
including security fixes, until you manually bump the number. The
correct approach for most projects is the pessimistic constraint
operator:

```hcl
required_providers {
  azurerm = {
    source  = "hashicorp/azurerm"
    version = "~> 4.8"
  }
}
```

`~> 4.8` allows any `4.8.x` patch release automatically, while still
blocking a jump to `4.9` or `5.0` without a deliberate version bump —
covered fully in Day 2's version-operator breakdown.

---

## 4. The Provider Block, Done Correctly

```hcl
terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.8"
    }
  }
}

provider "azurerm" {
  features {}
}
```

---

## 5. Clearing Up the "East US" Location Confusion

A meaningful chunk of the video is spent debugging what turned out to
be a non-issue: the editor showed a wavy underline beneath `"East US"`,
and both presenters spent time investigating whether Terraform
required a different regional-name format. The underline was later
confirmed, by the presenters' own admission, to be the editor's
**spell-checker** flagging "East US" as an unrecognized word — not a
Terraform or HCL syntax problem at all.

Worth being precise here rather than leaving this ambiguous: `azurerm`
resources generally accept Azure region names written either with
spaces and capitals (`"East US"`) or in the canonical lowercase,
no-space form (`"eastus"`) — the provider normalizes this
internally for most resource types. That said, I'd recommend
defaulting to the canonical lowercase form (`"eastus"`), matching
exactly what `az account list-locations` and most Azure documentation
use, simply to avoid any ambiguity across provider versions or
resource types where normalization behavior might differ:

```hcl
location = "eastus"
```

**PowerShell — listing valid region names directly from Azure, so you
never have to guess the format:**
```powershell
az account list-locations --query "[].{Name:name, DisplayName:displayName}" -o table
```
The `Name` column (e.g., `eastus`) is the canonical form to use in
Terraform.

---

## 6. The Resource Group — Familiar Ground

```hcl
resource "azurerm_resource_group" "rg" {
  name     = "my-sql-server-rg"
  location = "eastus"
}
```

Nothing new here relative to every prior day in this series — included
for completeness of the working configuration.

---

## 7. A Deprecated Resource You Should Know About

The video correctly identifies that `azurerm_sql_server` is deprecated
in provider version 3.0 and above, in favor of `azurerm_mssql_server`.
This is the same deprecation pattern flagged repeatedly across this
series (Day 17's App Service resources, Day 20's AKS-related
resources, Day 21's policy assignment resource) — the AzureRM provider
periodically renames or splits resource types, and the old names stop
working (or start warning, then eventually error) in newer major
versions.

The current, correct resource family for this project:

- `azurerm_mssql_server` (the logical server)
- `azurerm_mssql_database` (a database inside that server)
- `azurerm_mssql_firewall_rule` (an IP-based access rule)

---

## 8. Building the SQL Server Resource

```hcl
resource "azurerm_mssql_server" "sql_server" {
  name                         = "my-terraform-sql-srv"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0"
  administrator_login          = "sqladmin"
  administrator_login_password = var.sql_admin_password
}
```

`version = "12.0"` is the current SQL Server engine version string
Azure SQL Database uses — this isn't a Terraform/provider version, it's
the Microsoft SQL Server engine version identifier, and "12.0" has
been the stable value for Azure SQL Database for a long time now
(distinct from on-premises SQL Server's own numbered releases).

`administrator_login` — the video used a fixed literal `"sqladmin"`,
which works but isn't unique in any way; unlike the server *name*
itself (Section 11), the admin login name has no global-uniqueness
requirement, so a fixed value here is fine.

`administrator_login_password` references `var.sql_admin_password` —
Section 9 covers this properly instead of hardcoding it.

---

## 9. The Hardcoded Password Problem — And the Correct Fix

The video hardcodes a literal password string directly in the
resource block, with both presenters explicitly acknowledging on
camera that this is bad practice done only for demo speed. That
acknowledgment is exactly right, and it's worth actually implementing
the fix rather than leaving it as a stated-but-unaddressed caveat.

This connects directly to two earlier days: Day 4's warning that the
Terraform *state file* itself will contain this password in plaintext
regardless of how carefully you avoid hardcoding it in your `.tf`
files (so state file security matters here too, not just source code
hygiene), and Day 12's `sensitive` variable pattern.

**The corrected variable declaration:**
```hcl
variable "sql_admin_password" {
  type        = string
  description = "SQL Server administrator password"
  sensitive   = true
  # Deliberately no default — force it to be supplied at apply time
}
```

**Supplying it without ever writing it into a committed file:**

```powershell
$env:TF_VAR_sql_admin_password = "Your-Strong-P@ssw0rd-Here"
terraform apply --auto-approve
```

Using the `TF_VAR_` environment-variable naming convention (covered
back in Day 5) means the actual password value never appears in any
file that could accidentally get committed to Git — it exists only in
your current shell session's memory.

**A stronger option still — generate it randomly instead of choosing
it yourself:**
```hcl
resource "random_password" "sql_admin" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "azurerm_mssql_server" "sql_server" {
  # ...
  administrator_login_password = random_password.sql_admin.result
}
```

This requires declaring the `random` provider (already introduced in
Day 14's `random_pet` example — same provider family, different
resource type):
```hcl
required_providers {
  random = {
    source  = "hashicorp/random"
    version = "~> 3.0"
  }
}
```

And — connecting directly to **Day 20**'s Key Vault pattern — the
generated password should then be stored in Key Vault rather than left
only in Terraform state:
```hcl
resource "azurerm_key_vault_secret" "sql_admin_password" {
  name         = "sql-admin-password"
  value        = random_password.sql_admin.result
  key_vault_id = azurerm_key_vault.kv.id
}
```

---

## 10. Building the Database Resource

```hcl
resource "azurerm_mssql_database" "sample_db" {
  name      = "sampledb"
  server_id = azurerm_mssql_server.sql_server.id
}
```

Only two arguments were used in the video, and this does work — but
it's worth flagging what's silently defaulted as a result: leaving
`sku_name` unset means Azure applies its own default pricing/performance
tier, which may not be the cheapest available option. For anything
beyond a quick throwaway demo, set it explicitly:

```hcl
resource "azurerm_mssql_database" "sample_db" {
  name      = "sampledb"
  server_id = azurerm_mssql_server.sql_server.id
  sku_name  = "Basic"   # or "GP_S_Gen5_1" for General Purpose Serverless, etc.
}
```

Checking the current default and the full list of valid `sku_name`
values in the AzureRM provider documentation before deploying anything
you intend to keep running is worth the two minutes it takes — Azure
SQL pricing tiers vary substantially in cost, and an unset SKU
defaulting to something more expensive than intended is a genuinely
common source of surprise billing.

---

## 11. Why "Resource Already Exists" Happened — Global Uniqueness Revisited

Partway through the video, applying the configuration fails with a
"resource ID already exists" error, resolved by adding a distinguishing
suffix to a resource name. This is exactly the **Day 3** and **Day 18**
lesson resurfacing in a new context: certain Azure resource types
require **globally unique names** across the entire Azure platform,
not just within your own subscription or resource group.

Worth being precise about which resource this applied to, since the
video itself doesn't fully pin it down: SQL Server names
(`azurerm_mssql_server.name`) are globally unique across all of Azure
— exactly like Storage Account names covered in Day 3 and Day 18.
Resource Group names, by contrast, only need to be unique *within a
single subscription*, not globally. Since the video mentions this was
a *shared* subscription (used by multiple people), a collision on
either the Resource Group name or the SQL Server name was plausible —
but the SQL Server name is the one with a genuine platform-wide
uniqueness requirement regardless of subscription sharing.

**PowerShell — checking SQL Server name availability before you commit
to it in Terraform code:**
```powershell
az sql server list --query "[].name" -o table
```
This only shows names *within your own subscription* — it can't tell
you whether a name is taken globally by someone else's subscription,
which is exactly why unpredictable "name already exists" errors happen
even when the name doesn't appear anywhere you can see. Building a
naming convention with a project-specific or randomly generated suffix
(as Day 14's `random_pet` pattern demonstrated) avoids this class of
collision entirely.

---

## 12. The `ARM_SUBSCRIPTION_ID` Requirement — A Provider Behavior Worth Understanding

The video hits an error stating the subscription ID is a required
provider property, despite the presenter already being authenticated
via `az login`. This surprised both presenters, and it's worth
explaining precisely rather than treating it as an unexplained quirk:
newer versions of the AzureRM provider require the subscription
context to be **explicitly** supplied — either via the `subscription_id`
argument in the `provider "azurerm"` block, or via the
`ARM_SUBSCRIPTION_ID` environment variable — rather than silently
inferring it from whichever subscription happens to be currently
selected in your Azure CLI session. This is a deliberate safety change:
implicitly trusting "whatever subscription the CLI currently has
selected" is exactly the kind of ambiguity that can lead to
accidentally deploying (or destroying) resources in the wrong
subscription in an environment where a user might have several
subscriptions available.

**PowerShell — setting it explicitly, matching the pattern used
throughout this entire series:**
```powershell
az account list --output table
$env:ARM_SUBSCRIPTION_ID = "your-subscription-id-here"
terraform plan
```

Alternatively, set it directly in the provider block if your project
is always scoped to one specific subscription:
```hcl
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}
```

---

## 13. The Firewall Rule — And Why "My Public IP Only" Still Isn't Production-Safe

```hcl
resource "azurerm_mssql_firewall_rule" "allow_my_ip" {
  name             = "allow-my-public-ip"
  server_id        = azurerm_mssql_server.sql_server.id
  start_ip_address = var.my_public_ip
  end_ip_address   = var.my_public_ip
}
```

Both presenters explicitly flag, correctly, that exposing a SQL Server
to any public IP address — even scoped to a single specific IP rather
than left wide open — is not the recommended production pattern.
Worth being concrete about *why*, since "not recommended" alone isn't
very actionable: a single-IP firewall rule still means the database
has a publicly routable endpoint, reachable over the internet in
principle by anyone who discovers or guesses that endpoint address,
with the IP restriction as the only barrier — and residential/office
public IPs are not static in most setups, meaning this exact rule
would silently stop working the next time your ISP reassigns your
address, as actually happened live in the video when the presenter's
public IP had changed between recording sessions.

**The genuinely production-appropriate alternatives:**

- **Private Endpoint** — attaches the SQL Server to a private IP
  address inside your own VNet, with no public endpoint existing at
  all. This is the strongest option and Microsoft's current
  recommendation for production database access.
- **VNet Service Endpoint / VNet Rule** — restricts SQL Server access
  to traffic originating from a specific subnet inside your VNet,
  without requiring a fully private endpoint.
- If a public endpoint is genuinely required (rare, and worth
  questioning), scope firewall rules to your actual application's
  outbound IP ranges, not a developer's personal machine's IP — which
  is precisely the distinction the video's own diagram called out
  between "testing convenience" and "real application access."

This is the connective thread with the assignment left as homework in
Section 18 — building VNet-restricted access instead of public-IP
access is exactly closing this gap.

---

## 14. A Stronger Alternative: Azure AD-Only Authentication

The entire video uses **SQL Authentication** (a username and password
stored on the server itself) — the pattern this whole guide has been
tightening up around password handling for. Worth mentioning as a more
current alternative, connecting to Day 16's and Day 20's identity
material: Azure SQL supports **Azure AD-only authentication**, where
you disable SQL-native logins entirely and require every connection to
authenticate through Entra ID instead.

```hcl
resource "azurerm_mssql_server" "sql_server" {
  name                         = "my-terraform-sql-srv"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0"

  azuread_administrator {
    login_username = "sql-admins-group"
    object_id       = data.azuread_group.sql_admins.object_id
  }

  # When true, disables SQL-native login entirely — Azure AD only
  azuread_authentication_only = true
}
```

This removes the `administrator_login`/`administrator_login_password`
attack surface entirely — there is no static password to leak, rotate,
or accidentally hardcode, because access is governed by the same Entra
ID identities and groups covered in Day 16. I'm presenting this as the
stronger option to be aware of, not rewriting the whole guide around
it, since SQL Authentication is still extremely common in existing
production environments and worth understanding on its own terms too.

---

## 15. Connecting with a SQL Client

The video used Azure Data Studio (a free, cross-platform GUI SQL
client from Microsoft) to verify connectivity. A command-line
alternative that fits better into a scripted or CI/CD context:

**PowerShell — using `sqlcmd` (Microsoft's command-line SQL client) to
test connectivity directly:**
```powershell
sqlcmd -S "my-terraform-sql-srv.database.windows.net" -d "sampledb" -U "sqladmin" -P $env:TF_VAR_sql_admin_password -Q "SELECT @@VERSION"
```

If `sqlcmd` isn't installed:
```powershell
winget install Microsoft.SqlServerManagementStudio
# or, for just the command-line tool
winget install Microsoft.SqlServer.Cmd
```

A successful connection confirms both the firewall rule and the
credentials are working end-to-end — a useful automated check to run
right after `terraform apply` completes, rather than only checking
manually through a GUI client.

---

## 16. The Missing Output Block — Fixed

Partway through the video, the presenter realizes there's no output
exposing the server's fully qualified domain name, and has to look it
up manually in the Portal instead. Easily avoided:

```hcl
output "sql_server_fqdn" {
  description = "Fully qualified domain name of the SQL Server"
  value       = azurerm_mssql_server.sql_server.fully_qualified_domain_name
}

output "database_name" {
  description = "Name of the created database"
  value       = azurerm_mssql_database.sample_db.name
}

output "admin_login" {
  description = "SQL Server administrator username"
  value       = azurerm_mssql_server.sql_server.administrator_login
}

# Deliberately NOT outputting the password in plaintext, matching Day 12's
# sensitive-value handling. If you need it accessible programmatically,
# retrieve it from Key Vault (Section 9) rather than a Terraform output.
```

---

## 17. Complete Corrected Working Code

**`provider.tf`**
```hcl
terraform {
  required_version = ">= 1.9.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.8"
    }
    random = {
      source  = "hashicorp/random"
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
variable "resource_group_name" {
  type    = string
  default = "day22-sql-rg"
}

variable "location" {
  type    = string
  default = "eastus"
}

variable "sql_server_name" {
  type        = string
  description = "Must be globally unique across all of Azure"
  default     = "day22-sql-srv"
}

variable "my_public_ip" {
  type        = string
  description = "Your current public IP, for the firewall rule"
}
```

**`main.tf`**
```hcl
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "random_password" "sql_admin" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "azurerm_mssql_server" "sql_server" {
  name                         = var.sql_server_name
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0"
  administrator_login          = "sqladmin"
  administrator_login_password = random_password.sql_admin.result
}

resource "azurerm_mssql_database" "sample_db" {
  name      = "sampledb"
  server_id = azurerm_mssql_server.sql_server.id
  sku_name  = "Basic"
}

resource "azurerm_mssql_firewall_rule" "allow_my_ip" {
  name             = "allow-my-public-ip"
  server_id        = azurerm_mssql_server.sql_server.id
  start_ip_address = var.my_public_ip
  end_ip_address   = var.my_public_ip
}
```

**`outputs.tf`**
```hcl
output "sql_server_fqdn" {
  value = azurerm_mssql_server.sql_server.fully_qualified_domain_name
}

output "database_name" {
  value = azurerm_mssql_database.sample_db.name
}
```

**PowerShell — running it:**
```powershell
Set-Location "C:\projects\day22"

az login
az account list --output table
$env:ARM_SUBSCRIPTION_ID = "your-subscription-id"

$myIp = (Invoke-WebRequest -Uri "https://api.ipify.org").Content

terraform init
terraform validate
terraform plan -var="my_public_ip=$myIp"
terraform apply -var="my_public_ip=$myIp" --auto-approve

terraform output sql_server_fqdn
```

---

## 18. The Assignment Left as Homework — VNet-Scoped Access

The presenter explicitly leaves this as a task rather than
demonstrating it: build a Virtual Network, a subnet, and a Virtual
Machine, then restrict the SQL Server's access to that subnet instead
of a public IP — testing connectivity from inside the VNet rather than
from a personal machine's internet connection.

This directly implements the "genuinely production-appropriate
alternative" flagged in Section 13. A minimal sketch of what that
looks like, combining patterns already fully covered in Day 14 and
Day 15:

```hcl
resource "azurerm_virtual_network" "vnet" {
  name                = "day22-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "sql_subnet" {
  name                 = "sql-access-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]

  service_endpoints = ["Microsoft.Sql"]
}

resource "azurerm_mssql_virtual_network_rule" "vnet_rule" {
  name      = "allow-app-subnet"
  server_id = azurerm_mssql_server.sql_server.id
  subnet_id = azurerm_subnet.sql_subnet.id
}
```

A VM created inside `sql_subnet` (following the exact
`azurerm_linux_virtual_machine` pattern from Day 3 and Day 19) would
then have SQL Server access without any public IP or public firewall
rule involved at all.

---

## 19. Common Mistakes

**Mistake 1 — Exact-pinning a provider version instead of using `~>`.**
Blocks security patches unnecessarily. Covered in Section 3.

**Mistake 2 — Hardcoding a database password in a `.tf` file.**
Covered fully in Section 9 — use a `sensitive` variable supplied via
`TF_VAR_`, or better, `random_password` combined with Key Vault storage.

**Mistake 3 — Using the deprecated `azurerm_sql_server` /
`azurerm_sql_database` resource names.** Use `azurerm_mssql_server` and
`azurerm_mssql_database` instead (Section 7).

**Mistake 4 — Leaving `sku_name` unset on the database.** May default
to a pricing tier you didn't intend — always set it explicitly for
anything beyond a throwaway test (Section 10).

**Mistake 5 — Treating "restricted to my IP" as production-safe.**
It's better than wide-open, but still a public endpoint with a
brittle, non-static IP restriction. See Section 13 for the actual
production-appropriate alternatives.

**Mistake 6 — Assuming `az login` alone supplies subscription context
to the AzureRM provider.** Newer provider versions require it
explicitly via `ARM_SUBSCRIPTION_ID` or the `subscription_id` provider
argument (Section 12).

---

## 20. Practice Exercises

**Exercise 1** — A colleague's `terraform apply` fails with "a
resource with this ID already exists" while creating an
`azurerm_mssql_server`, even though they've never created a resource
with that name in their own subscription. Explain why this can happen.

*Answer:* SQL Server names are globally unique across all of Azure,
not just within one subscription — someone else's completely unrelated
subscription can already be using that exact name. Section 11 covers
this, mirroring the same rule that applies to Storage Account names
(Day 3, Day 18).

**Exercise 2** — Rewrite the firewall rule from Section 13 to allow
access from an entire VNet subnet instead of a single public IP,
without writing any new resource types beyond what Section 18 already introduces.

*Answer:* Replace `azurerm_mssql_firewall_rule` with
`azurerm_mssql_virtual_network_rule`, referencing a subnet's ID (with
`service_endpoints = ["Microsoft.Sql"]` enabled on that subnet) instead
of a start/end IP address pair — exactly the code shown in Section 18.

**Exercise 3** — Why does marking a Terraform variable `sensitive =
true` not fully solve the "don't leak the database password" problem
on its own?

*Answer:* `sensitive = true` only suppresses the value from terminal
and log output during `plan`/`apply`. The value is still stored in
plaintext in the Terraform state file (Day 4), so the state backend
itself must also be secured (remote backend with access controls) —
marking a variable sensitive is one layer of protection, not a
complete solution by itself.

---

## 21. Summary Reference

Azure SQL Database is PaaS — Microsoft manages the underlying engine
and infrastructure; you manage schema, data, and access control.

Current (non-deprecated) resource names: `azurerm_mssql_server`,
`azurerm_mssql_database`, `azurerm_mssql_firewall_rule`,
`azurerm_mssql_virtual_network_rule`.

Never hardcode the admin password — use a `sensitive` variable
supplied via `TF_VAR_`, or generate one with `random_password` and
store it in Key Vault (Day 20).

SQL Server names require global uniqueness across all of Azure, the
same rule that applies to Storage Account names.

Newer AzureRM provider versions require an explicit subscription
context (`ARM_SUBSCRIPTION_ID` or the provider's `subscription_id`
argument) — logging in via `az login` alone is not sufficient.

A single-public-IP firewall rule is a meaningful improvement over
"open to everyone," but is still not the production-recommended
pattern — Private Endpoints or VNet-scoped rules (Section 18) are the
stronger approach, and Azure AD-only authentication (Section 14)
removes the SQL-password attack surface entirely.

---

*Guide covers: Azure SQL Database as a PaaS offering, the SQL
Server/database/firewall-rule resource relationship, Terraform
provider version pinning with the ~> operator (Day 2 callback),
resolving an editor spell-check false alarm versus a genuine HCL
error, azurerm_mssql_server as the current non-deprecated resource
(replacing azurerm_sql_server), administrator_login and
administrator_login_password, avoiding hardcoded secrets with
sensitive variables and TF_VAR_ environment variables, the
random_password resource, storing generated secrets in Key Vault (Day
20 callback), azurerm_mssql_database and the sku_name cost
consideration, global uniqueness of SQL Server names (Day 3/Day 18
callback), the ARM_SUBSCRIPTION_ID requirement in newer AzureRM
provider versions, azurerm_mssql_firewall_rule and its production
limitations, azurerm_mssql_virtual_network_rule as a stronger
alternative, Azure AD-only authentication for SQL Server as a
password-free access model, sqlcmd for command-line connectivity
testing, proper output block design that avoids leaking sensitive
values, and PowerShell equivalents throughout for az login, region
listing, public IP lookup, and the full terraform init/plan/apply
workflow.*
