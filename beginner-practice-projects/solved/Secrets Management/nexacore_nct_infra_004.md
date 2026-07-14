# NexaCore Technologies — Internal DevOps Training Project
## Secrets Management with Azure Key Vault + Terraform
**Project Code:** `NCT-INFRA-004` | **Track:** Junior DevOps Engineer | **Level:** Intermediate

---

> **A message from your Tech Lead:**
> I reviewed NCT-INFRA-003. The module structure is clean and the remote
> state is working correctly. Good.
>
> Now we have a problem to fix. Look at your terraform.tfvars from the
> last project — your SSH IP, your admin username, everything is sitting
> in a plain text file. In a real team, those files get committed to Git
> by accident. It happens more than you'd think.
>
> This ticket is about secrets management. You will provision an
> Azure Key Vault, store sensitive values in it, and learn how to
> pull those secrets INTO your Terraform config without ever writing
> them in plain text files again.
>
> This is not optional knowledge. Every production environment at
> NexaCore uses Key Vault. Learn it properly now.
> — *Priya Menon, Lead DevOps, NexaCore Technologies*

---

## Org Context

| Field | Detail |
|---|---|
| **Organisation** | NexaCore Technologies Pvt. Ltd. |
| **Department** | Platform Engineering |
| **Team** | DevOps – Infrastructure |
| **Your Role** | Junior DevOps Engineer (Trainee) |
| **Reporting To** | Priya Menon (Lead DevOps) |
| **Ticket ID** | `NCT-INFRA-004` |
| **Depends On** | NCT-INFRA-003 concepts (modules, remote state) |
| **Environment** | `dev` only |
| **Cloud** | Microsoft Azure |
| **IaC Tool** | Terraform `v1.6+` |
| **Azure Region** | `East US` |
| **Cost Centre** | `CC-DEVOPS-007` |

---

## 1. Project Overview

### What You're Building

**An Azure Key Vault that stores sensitive configuration values, consumed
by a Linux VM — all provisioned and wired together with Terraform.**

You are building two things that talk to each other:

```
┌─────────────────────────────────────────────────────┐
│  Azure Key Vault (nct-dev-secrets-kv)               │
│                                                     │
│  Secret: vm-admin-username  → "nctadmin"            │
│  Secret: vm-admin-password  → "Nct@Secure2024!"     │
│  Secret: allowed-ssh-ip     → "YOUR_IP/32"          │
└───────────────────┬─────────────────────────────────┘
                    │ Terraform reads secrets
                    │ using data sources
                    ▼
┌─────────────────────────────────────────────────────┐
│  Linux VM (nct-dev-app-vm)                          │
│                                                     │
│  Uses admin_username from Key Vault                 │
│  Uses admin_password from Key Vault                 │
│  NSG uses allowed_ssh_ip from Key Vault             │
└─────────────────────────────────────────────────────┘
```

### What Is New in This Project

| Concept | What You'll Learn |
|---|---|
| `data` sources | How to READ existing Azure resources into Terraform |
| Key Vault + secrets | Storing and retrieving sensitive values securely |
| `sensitive = true` | Telling Terraform to hide a value from terminal output |
| Password auth on VM | Using password instead of SSH key (Key Vault manages it) |
| `depends_on` | Explicitly telling Terraform about dependencies it cannot detect |

### Why This Is Different from 001–003

In the previous three projects, all values flowed from `.tfvars` into resources.
In this project, some values flow from `.tfvars` and some are **pulled from
Azure Key Vault at apply time using `data` sources**. You are reading from
Azure, not just writing to it. This is a fundamental shift in how you think
about Terraform.

```
NCT-INFRA-001/002/003:
  tfvars → variables → resources

NCT-INFRA-004:
  tfvars → variables → resources
  Azure Key Vault → data sources → resources    ← NEW direction
```

### Scope Boundaries

- `dev` environment only — no module, no remote state this time
  (focus is on Key Vault concepts, not folder structure)
- Password authentication on the VM instead of SSH key
  (so the password itself comes from Key Vault — teaches the pattern clearly)
- No RBAC custom roles — uses built-in `Key Vault Secrets Officer` role
- No Key Vault private endpoints — public access with IP restrictions only
- One Key Vault, three secrets, one VM

---

## 2. Naming Conventions

### NexaCore Key Vault Naming Standard

Key Vault names follow the org pattern but with a special constraint:
**3–24 characters, alphanumeric and hyphens only, must start with a letter.**

```
Pattern:  {org-prefix}-{env}-secrets-kv
Example:  nct-dev-secrets-kv
```

### Secret Naming Inside Key Vault → `kebab-case`

Secrets are named with kebab-case. No underscores — Azure Key Vault
does not allow underscores in secret names.

```
vm-admin-username
vm-admin-password
allowed-ssh-ip
```

### Full Resource Naming for This Project

| Resource | Name |
|---|---|
| Resource Group | `nct-dev-secrets-rg` |
| Key Vault | `nct-dev-secrets-kv` |
| Virtual Network | `nct-dev-app-vnet` |
| Subnet | `nct-dev-app-subnet` |
| NSG | `nct-dev-app-nsg` |
| Public IP | `nct-dev-app-pip` |
| NIC | `nct-dev-app-nic` |
| Virtual Machine | `nct-dev-app-vm` |

### File Structure (flat — no modules this time)

```
nct-infra-004/
├── providers.tf
├── main.tf           ← Key Vault + VM resources
├── data.tf           ← NEW: all data source blocks live here
├── variables.tf
├── outputs.tf
└── terraform.tfvars
```

> `data.tf` is a new file. NexaCore separates `data` source blocks from
> `resource` blocks to make it immediately clear what Terraform is
> creating vs what it is only reading.

### NexaCore Mandatory Tags

| Tag Key | Value |
|---|---|
| `Project` | `NCT-INFRA-004` |
| `Environment` | `dev` |
| `Owner` | `jane-doe` |
| `ManagedBy` | `terraform` |
| `CostCentre` | `CC-DEVOPS-007` |
| `Team` | `platform-engineering` |

### Sample Data to Use

```hcl
# terraform.tfvars

org_prefix          = "nct"
environment         = "dev"
azure_location      = "East US"
vm_size             = "Standard_B1s"
key_vault_name      = "nct-dev-secrets-kv"
resource_group_name = "nct-dev-secrets-rg"
owner_name          = "jane-doe"
cost_centre         = "CC-DEVOPS-007"
```

> Notice what is NOT in tfvars: no admin username, no password, no IP.
> Those sensitive values live only in Key Vault.
> That is the entire point of this project.

---

## 3. Core Components to Build

### Component 1 — Current User Data Source + Resource Group

**File:** `data.tf` and `main.tf`

Before you can give Terraform permission to read from Key Vault,
you need to know WHO is running Terraform — your Azure identity.
This is done with a `data` source, not a `resource`.

A `data` source reads existing information from Azure.
It does not create anything. It just fetches and makes data available.

**In `data.tf` you must define:**

```
data "azurerm_client_config" "current" { }
```

This single data source gives you access to three critical values:
- `data.azurerm_client_config.current.tenant_id`
- `data.azurerm_client_config.current.subscription_id`
- `data.azurerm_client_config.current.object_id`  ← your identity's ID in Azure AD

You will use `object_id` to grant yourself access to Key Vault.

**In `main.tf` you must define:**

- `azurerm_resource_group` with all six org tags

---

### Component 2 — Azure Key Vault

**File:** `main.tf`

The Key Vault is the secure store. Think of it as a safe that Azure manages.
Only identities you explicitly grant access to can read from it.

**You must define `azurerm_key_vault` with these specific settings:**

- `name` — from variable
- `location` and `resource_group_name` — from the RG resource attributes
- `sku_name` = `"standard"` — standard tier is sufficient for dev
- `tenant_id` = `data.azurerm_client_config.current.tenant_id`
  This ties the vault to your Azure AD tenant.
- `soft_delete_retention_days` = `7`
  Azure keeps deleted secrets for 7 days before permanent deletion.
  This is a safety net. Minimum is 7 days.
- `purge_protection_enabled` = `false`
  In production this would be `true`. For dev/learning, `false` lets you
  destroy and recreate cleanly without waiting for purge delays.
- One `network_acls` block:
  - `bypass` = `"AzureServices"`
  - `default_action` = `"Allow"`
  (for dev, we allow all access. Production would restrict by IP.)
- One `access_policy` block:
  - `tenant_id` = same as above
  - `object_id` = `data.azurerm_client_config.current.object_id`
  - `secret_permissions` = `["Get", "List", "Set", "Delete", "Purge"]`
  This grants YOUR Azure identity full secret management rights.
  Without this, Terraform cannot create secrets inside the vault.
- All six org tags

---

### Component 3 — Key Vault Secrets

**File:** `main.tf`

Now you populate the vault with the three secrets the VM will use.
Each secret is its own Terraform resource.

**You must define three `azurerm_key_vault_secret` resources:**

Secret 1 — VM admin username:
```
name         = "vm-admin-username"
value        = "nctadmin"
key_vault_id = (reference to the Key Vault resource)
```

Secret 2 — VM admin password:
```
name         = "vm-admin-password"
value        = "Nct@Secure2024!"
key_vault_id = (reference to the Key Vault resource)
```

Secret 3 — Allowed SSH IP:
```
name         = "allowed-ssh-ip"
value        = "YOUR_PUBLIC_IP/32"
key_vault_id = (reference to the Key Vault resource)
```

> You are setting the secret values here in `main.tf` — not in `tfvars`.
> In a real team, these would come from a separate secrets pipeline or be
> pre-populated in Key Vault manually by a security team.
> For this learning project, defining them in Terraform teaches the
> full workflow end-to-end.

**Add `sensitive` content tagging:**

Each secret resource should have:
```hcl
tags = merge(var.tags, { SecretType = "infrastructure" })
```

---

### Component 4 — Data Sources to READ the Secrets Back

**File:** `data.tf`

Here is where the concept shift happens. You created the secrets
(writing). Now you read them back using `data` sources (reading).

Why read back what you just wrote? Because in a real scenario,
the secrets already exist in Key Vault — created by a security team,
not by your Terraform. Your job is only to READ them. This teaches
that real pattern.

**You must define three data sources in `data.tf`:**

```
data "azurerm_key_vault_secret" "vm_admin_username" { }
data "azurerm_key_vault_secret" "vm_admin_password" { }
data "azurerm_key_vault_secret" "allowed_ssh_ip"    { }
```

Each needs two arguments:
- `name` — the secret name in Key Vault (e.g. `"vm-admin-username"`)
- `key_vault_id` — reference to the Key Vault resource

You then use the secret value in other resources like this:
```
data.azurerm_key_vault_secret.vm_admin_username.value
```

**Critical:** You must use `depends_on` on each data source to tell
Terraform it must wait for the secrets to be created before reading them.
Terraform cannot detect this dependency automatically because the
data source only knows the secret name, not which resource creates it.

```hcl
depends_on = [azurerm_key_vault_secret.vm_admin_username]
```

This is one of the few valid use cases for `depends_on` in Terraform.

---

### Component 5 — Linux VM Using Key Vault Values

**File:** `main.tf`

This is the same VM stack from NCT-INFRA-002, with one key difference:
the sensitive values come from Key Vault data sources, not from variables.

**Networking resources to define** (same pattern as NCT-INFRA-002):
- `azurerm_virtual_network`
- `azurerm_subnet`
- `azurerm_network_security_group`
  - SSH rule where `source_address_prefix` =
    `data.azurerm_key_vault_secret.allowed_ssh_ip.value`
- `azurerm_subnet_network_security_group_association`
- `azurerm_public_ip`
- `azurerm_network_interface`

**VM resource to define** (`azurerm_linux_virtual_machine`):

This time use **password authentication** instead of SSH key:
```
disable_password_authentication = false
admin_username = data.azurerm_key_vault_secret.vm_admin_username.value
admin_password = data.azurerm_key_vault_secret.vm_admin_password.value
```

The `admin_password` must meet Azure's password requirements:
- Minimum 12 characters
- Must include uppercase, lowercase, digit, and special character
- Cannot contain the username

Use the sample password: `"Nct@Secure2024!"`

---

### Component 6 — Variables and Outputs

**Files:** `variables.tf` and `outputs.tf`

**Variables to declare** — notice what is NOT here:

```
org_prefix
environment
azure_location
vm_size
key_vault_name
resource_group_name
owner_name
cost_centre
```

No `admin_username`, no `admin_password`, no `allowed_ssh_ip` as variables.
Those are secrets. They belong in Key Vault, not in variable files.

**Outputs to expose — with `sensitive` flag:**

```
key_vault_id           ← the vault's resource ID
key_vault_uri          ← the vault's URL (e.g. https://nct-dev-secrets-kv.vault.azure.net/)
vm_name                ← the VM name
vm_public_ip           ← the public IP
ssh_command            ← formatted SSH connection string
```

For any output that exposes a sensitive value, you must add:
```hcl
sensitive = true
```

This prevents Terraform from printing the value in the terminal.
The value still exists — you access it with:
```bash
terraform output -raw <output_name>
```

---

## 4. Hints & Pitfalls

### Hint 1 — Key Vault Access Policy Must Exist BEFORE Secrets Can Be Created

Terraform may try to create the Key Vault and the secrets simultaneously
because it sees them as parallel resources (no obvious dependency).
But the secrets require the access policy to be active first, or Azure
will reject the write with a `403 Forbidden` error.

The fix is to ensure your secret resources reference the Key Vault
using its resource attribute (`azurerm_key_vault.secrets_kv.id`).
This creates an implicit dependency — Terraform will wait for the
full Key Vault resource (including its access policy) to be ready
before creating any secrets.

If you see a `403` error on secret creation, this ordering is the cause.

---

### Hint 2 — `sensitive = true` Hides Values in Plan Output, But Not in State

When you mark a variable or output as `sensitive = true`, Terraform
replaces the value with `(sensitive value)` in terminal output.
This is good practice and required for passwords at NexaCore.

However, understand its limits clearly:

```
terraform plan  → shows "(sensitive value)"    ← protected
terraform apply → shows "(sensitive value)"    ← protected
terraform.tfstate → contains the ACTUAL value  ← NOT protected
```

The state file on disk contains all secret values in plain text.
This is why remote state (NCT-INFRA-003) matters — Azure Blob Storage
encrypts state at rest, unlike a local file sitting on your laptop.

This is not a flaw to fix in this project. It is a fact to understand.

---

### Hint 3 — Key Vault Names Cannot Be Reused Immediately After Deletion

If your `terraform destroy` runs successfully and you then try to
`terraform apply` again immediately, Key Vault creation may fail with:

```
VaultAlreadyExists: A vault with the same name already exists in deleted state.
```

This happens because of `soft_delete_retention_days = 7`.
Azure keeps a "soft-deleted" version of the vault for 7 days even after
destroy. During that window, the name is reserved.

Two ways to handle this:
- Change the Key Vault name slightly (add a suffix)
- Purge the soft-deleted vault manually:
```bash
az keyvault purge --name nct-dev-secrets-kv --location "East US"
```

This is why `purge_protection_enabled = false` is set in this project —
it allows you to purge immediately during learning without waiting 7 days.

---

## 5. Real Environment Requirements

### Tools

```
Terraform CLI     v1.6+
Azure CLI         v2.50+
```

### Azure Authentication

```bash
# Confirm you are logged in
az account show --output table

# Get your Object ID (you'll see this referenced in Key Vault access policy)
az ad signed-in-user show --query id --output tsv
# This is the same value Terraform gets from:
# data.azurerm_client_config.current.object_id
```

### Find Your Public IP for the Secret Value

```bash
curl -s https://api.ipify.org
# Use this as the value for the "allowed-ssh-ip" secret
# Format: YOUR_IP/32  (e.g. "103.56.78.90/32")
```

### Azure Password Requirements for the VM

The `vm-admin-password` secret must meet all of these:

```
Minimum length:        12 characters
Must contain:          Uppercase letter (A-Z)
                       Lowercase letter (a-z)
                       Number (0-9)
                       Special character (!@#$%^&*)
Must NOT contain:      The admin username
Must NOT contain:      Common patterns (123, abc, password)

Sample password:       Nct@Secure2024!   ✓ (meets all requirements)
```

---

## 6. Workflow

```bash
# Navigate to your project folder
cd nct-infra-004/

# 1. Initialise
terraform init

# 2. Validate syntax
terraform validate

# 3. Format code
terraform fmt

# 4. Preview (read this carefully — spot the Key Vault and secrets)
terraform plan

# 5. Apply
terraform apply

# 6. Verify Key Vault secrets were created
az keyvault secret list \
  --vault-name nct-dev-secrets-kv \
  --output table
# Expected: vm-admin-username, vm-admin-password, allowed-ssh-ip

# 7. Read a secret value via CLI (proves it's stored correctly)
az keyvault secret show \
  --vault-name nct-dev-secrets-kv \
  --name vm-admin-username \
  --query value \
  --output tsv

# 8. SSH into VM using the password from Key Vault
ssh nctadmin@$(terraform output -raw vm_public_ip)
# When prompted for password, retrieve it:
az keyvault secret show \
  --vault-name nct-dev-secrets-kv \
  --name vm-admin-password \
  --query value \
  --output tsv

# 9. Destroy when done
terraform destroy

# 10. Purge the soft-deleted Key Vault
az keyvault purge --name nct-dev-secrets-kv --location "East US"
```

---

## 7. NexaCore Code Review Checklist

```
[ ] data.tf is separate from main.tf — data sources are not mixed with resources
[ ] azurerm_client_config.current is declared in data.tf
[ ] Key Vault access_policy uses object_id from azurerm_client_config.current
[ ] All three secrets created with correct kebab-case names
[ ] All three data sources declared with depends_on pointing to their secret resource
[ ] VM admin_username and admin_password come from data sources — NOT from variables
[ ] NSG allowed_ssh_ip comes from data source — NOT from variables or tfvars
[ ] sensitive = true applied to password output (if exposed)
[ ] No passwords or usernames present anywhere in tfvars
[ ] terraform plan reviewed — sensitive values show as "(sensitive value)"
[ ] terraform validate passes
[ ] terraform fmt run
[ ] terraform destroy + az keyvault purge confirmed working
```

---

## 8. What You Now Know After Completing This Ticket

```
NCT-INFRA-001   Storage, Provider config, basic resources
NCT-INFRA-002   Networking, NSG, Compute, dependency chains
NCT-INFRA-003   Modules, Remote State, multi-environment structure
NCT-INFRA-004   Key Vault, data sources, sensitive values, depends_on
                ↑ You now understand reading FROM Azure, not just writing TO it
────────────────────────────────────────────────────────────────────────────
NCT-INFRA-005   (Next) → Azure App Service: deploying a real web application,
                         environment variables, deployment slots
```

### The Core Mental Model You Should Have After 004

```
resource "..." "..." { }    → CREATE or MANAGE something in Azure
data    "..." "..." { }     → READ something that already exists in Azure

Both can be used together in the same config.
Most real Terraform projects use both heavily.
```

---

*NexaCore Technologies — Platform Engineering | Internal Training Material*
*NCT-INFRA-004 | Prerequisite: NCT-INFRA-003 concepts understood*
*Do not distribute outside the DevOps team*
