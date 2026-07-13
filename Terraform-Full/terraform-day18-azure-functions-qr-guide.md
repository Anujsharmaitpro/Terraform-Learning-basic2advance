# Terraform + Azure Functions — Serverless QR Code Generator
## Deep-Dive Learning Guide — Day 18 / 28 Days of Easy Terraform
### Beginner-First Edition | PowerShell Throughout

---

## Before You Start

This is Day 18. By now you've covered fundamentals (Days 1-9), expressions
and functions (Days 10-12), data sources (Day 13), mini projects on VMSS,
VNet peering, Entra ID, and App Service (Days 14-17).

Today's project deploys a small **Azure Function** — a QR code generator
— using Terraform for the infrastructure and the Azure Functions Core
Tools CLI for the code deployment. This guide walks through the working
parts, but it also spends real time on the instructor's four-hour
debugging saga, because the *cause* of that saga (forgetting `npm
install` before deploying) is a genuinely common mistake, and the
*process* of diagnosing it is worth learning from directly.

One thing to flag up front, since I'd rather tell you clearly than let
it slide: the configuration built in this video is **not actually a
serverless Consumption-plan function** — it uses a dedicated Basic (B1)
App Service Plan. That distinction matters for cost and behaviour, and
Section 3 explains exactly why.

---

## Table of Contents

1. What Is Azure Functions? (And a Correction on "Serverless")
2. The Four Resources You Need
3. Basic (B1) Plan vs Consumption Plan — Why This Matters
4. Building the Resource Group and Storage Account
5. Building the Service Plan
6. Building the Function App
7. The `site_config` / `application_stack` Block — Setting the Node Version
8. The Deprecated Resource Trail — Same Pattern as Day 17
9. Storage Account Naming — Global Uniqueness (Recap from Day 3)
10. Running the Deployment
11. What the QR Code Function Actually Does
12. Setting Up Local Credentials — `local.settings.json`
13. Installing Azure Functions Core Tools
14. Cloning and Preparing the Application Code
15. Publishing the Function Code — `func azure functionapp publish`
16. Publishing Application Settings Separately
17. The Debugging Saga — Diagnosing "Cannot Find Module"
18. Why `npm install` Was the Missing Step
19. Testing the Function — Browser, Postman, PowerShell
20. Verifying the Output in Blob Storage
21. Cold Start — What It Is and Why the Second Call Was Faster
22. The Complete Working Code — All Files
23. Common Mistakes Beginners Make
24. Practice Exercises
25. Summary Reference

---

## 1. What Is Azure Functions? (And a Correction on "Serverless")

### The plain-English definition

Azure Functions is Azure's Function-as-a-Service (FaaS) offering. You
write a small piece of code that responds to a trigger — an HTTP
request, a timer, a new file in storage — and Azure runs it for you
without you managing a server.

### The correction worth making now

The transcript and much marketing material use "serverless" loosely.
True serverless billing (pay only per execution, scale to zero) applies
to the **Consumption plan** (`Y1` SKU). This project instead provisions
a **Basic (B1) App Service Plan** — a dedicated, always-on compute tier
that happens to *host* a Function App, but bills by the hour regardless
of whether the function is invoked. This is a legitimate and common
setup (it avoids cold starts and gives predictable performance), but
it is not the same cost model as "serverless," and conflating the two
can lead to a surprise bill if you expected pay-per-execution pricing.

If you want the pay-per-execution model, you'd use:
```hcl
resource "azurerm_service_plan" "example" {
  # ...
  os_type  = "Linux"
  sku_name = "Y1"   # Consumption plan — true serverless billing
}
```

---

## 2. The Four Resources You Need

Every Azure Function deployment needs these four pieces, regardless
of which plan tier you choose:

1. **Resource Group** — the container for everything
2. **Storage Account** — Azure Functions requires this internally, to
   store function code, logs, and trigger/binding state. This is not
   optional even for the simplest function.
3. **App Service Plan** (or Consumption Plan) — defines the compute
   tier the function runs on
4. **Function App** — the actual Azure Functions resource, referencing
   the plan and the storage account

---

## 3. Basic (B1) Plan vs Consumption Plan — Why This Matters

| | Basic (B1) — used in this project | Consumption (Y1) |
|---|---|---|
| Billing | Per hour, continuously, whether invoked or not | Per execution + execution time |
| Cold start | Rare — instance stays warm | Common — instance may need to spin up |
| Scaling | Manual / fixed | Automatic, scales to zero |
| Cost for low-traffic function | Higher (fixed monthly cost) | Lower (near-zero if rarely called) |
| Cost for high-traffic function | Can be cheaper (predictable) | Can be more expensive at scale |

For a learning project like this QR code generator, Basic (B1) is a
reasonable choice since it avoids cold-start confusion during testing.
For a genuinely low-traffic production function, Consumption is
usually the more cost-effective and idiomatically "serverless" choice.

---

## 4. Building the Resource Group and Storage Account

**`variables.tf`**
```hcl
variable "prefix" {
  type        = string
  description = "Prefix for all resource names"
  default     = "day18"
}
```

**`main.tf`**
```hcl
resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-rg"
  location = "Canada Central"
}

resource "azurerm_storage_account" "sa" {
  name                     = "techtutorialswithp123"
  # Storage account names must be globally unique, 3-24 chars, lowercase
  # letters and numbers only — see Section 9 for the full recap
  resource_group_name     = azurerm_resource_group.rg.name
  location                = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}
```

---

## 5. Building the Service Plan

```hcl
resource "azurerm_service_plan" "asp" {
  name                = "${var.prefix}-asp"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "B1"
}
```

`os_type = "Linux"` matters — it must match the OS you configure on
the Function App resource below. Mismatching these two produces
deployment errors.

---

## 6. Building the Function App

```hcl
resource "azurerm_linux_function_app" "func" {
  name                       = "${var.prefix}-qr-func"
  resource_group_name       = azurerm_resource_group.rg.name
  location                   = azurerm_resource_group.rg.location
  service_plan_id             = azurerm_service_plan.asp.id
  storage_account_name       = azurerm_storage_account.sa.name
  storage_account_access_key = azurerm_storage_account.sa.primary_access_key

  site_config {
    application_stack {
      node_version = "18"
    }
  }
}
```

### Why `azurerm_linux_function_app`, not `azurerm_function_app`

`azurerm_function_app` is the older, deprecated resource type — the
provider now splits it into `azurerm_linux_function_app` and
`azurerm_windows_function_app` depending on your OS choice. This is
the exact same deprecation pattern you saw in **Day 17** with
`azurerm_app_service` splitting into Linux/Windows web app resources.
Unlike Day 17's story, though, there's no known compatibility bug
reported here — this newer resource type works as documented.

---

## 7. The `site_config` / `application_stack` Block — Setting the Node Version

This function is written in Node.js, so you must tell Azure which
Node.js runtime version to use. Without this, Azure defaults to an
older version that may not match what your application code expects.

```hcl
site_config {
  application_stack {
    node_version = "18"
  }
}
```

**A version-currency note worth flagging**: Node.js 18 reached its
own upstream end-of-life in 2025. By the time you're reading this,
Azure Functions' supported Node.js versions will likely have moved on
(commonly 20 or 22 at time of writing this guide). Always check the
current list of supported `node_version` values in the Azure Functions
documentation before hardcoding a version — don't assume "18" is still
current or even still supported.

The mistake the instructor initially made here was placing this value
under an `app_settings` block instead of `application_stack` — those
are two different blocks with different purposes, and Terraform will
not error loudly if you use the wrong one; it just won't have the
effect you expect.

---

## 8. The Deprecated Resource Trail — Same Pattern as Day 17

Connecting directly to **Day 17**'s central lesson: Terraform's Azure
provider periodically deprecates older resource types in favour of
more specific ones. You will keep encountering this pattern:

```
azurerm_app_service      -> azurerm_linux_web_app / azurerm_windows_web_app   (Day 17)
azurerm_function_app     -> azurerm_linux_function_app / azurerm_windows_function_app   (Day 18)
```

Unlike Day 17's App Service migration (which had a real provider bug
at the time), this Function App migration does not have a documented
equivalent issue — but the general lesson stands: **read the
deprecation warning's replacement suggestion, but verify the new
resource actually works for your specific application before
committing to it in a time-sensitive project.**

---

## 9. Storage Account Naming — Global Uniqueness (Recap from Day 3)

This is the exact same rule from **Day 3**: Storage Account names must
be globally unique across ALL of Azure, 3-24 characters, lowercase
letters and numbers only, no hyphens or special characters.

The instructor hit this directly during the demo:
```
Error: storage account name "techtutorialswithp" is already taken
```
followed by a second error after lengthening it:
```
Error: storage account name exceeds the 24 character limit
```

**PowerShell — check name availability before committing to Terraform code:**
```powershell
az storage account check-name --name "techtutorialswithp123"
```
This returns `{"nameAvailable": true/false, ...}` — checking this
before running `terraform apply` avoids exactly the trial-and-error
loop shown in the video.

---

## 10. Running the Deployment

```powershell
Set-Location "C:\projects\day18"

$env:ARM_CLIENT_ID       = "your-client-id"
$env:ARM_CLIENT_SECRET   = "your-client-secret"
$env:ARM_TENANT_ID       = "your-tenant-id"
$env:ARM_SUBSCRIPTION_ID = "your-subscription-id"

terraform init
terraform validate
terraform plan
# Expect: Plan: 4 to add (resource group, storage account, service plan, function app)

terraform apply --auto-approve
```

---

## 11. What the QR Code Function Actually Does

The application (a Node.js Azure Function, from a separate GitHub
repository referenced in the video) implements this flow:

1. A client sends an HTTP GET request with a `url` query parameter
2. The function generates a QR code image encoding that URL
3. The image is uploaded to a blob container in the Storage Account
4. The function returns a status code and the blob's download URL

This is a genuinely useful teaching example because it exercises HTTP
triggers, environment configuration, and blob storage output bindings
in one small project.

---

## 12. Setting Up Local Credentials — `local.settings.json`

Before publishing code, the Azure Functions Core Tools need to know
your storage account's connection string, both for local testing and
to correctly configure the function during publish.

**PowerShell — retrieve the connection string:**
```powershell
$connString = az storage account show-connection-string `
  --name "techtutorialswithp123" `
  --resource-group "day18-rg" `
  --query "connectionString" -o tsv

Write-Host $connString
```

**`local.settings.json`**
```json
{
  "IsEncrypted": false,
  "Values": {
    "AzureWebJobsStorage": "<paste-connection-string-here>",
    "FUNCTIONS_WORKER_RUNTIME": "node",
    "STORAGE_CONNECTION_STRING": "<paste-connection-string-here>"
  }
}
```

**Critical security note**: This file contains a live credential.
Add it to `.gitignore` immediately — never commit it:
```powershell
Add-Content -Path ".gitignore" -Value "local.settings.json"
```

The instructor mentions Azure Key Vault as a better long-term
alternative for storing this kind of secret — that's a fair point:
`local.settings.json` in plaintext on disk is acceptable for local
development and quick demos, but not appropriate for shared or
production environments.

---

## 13. Installing Azure Functions Core Tools

The `func` CLI is a separate tool from Terraform and the Azure CLI —
it specifically handles building and publishing Azure Functions code.

**PowerShell — install via npm (cross-platform) or via winget:**
```powershell
# Option A: via npm (requires Node.js installed)
npm install -g azure-functions-core-tools@4 --unsafe-perm true

# Option B: via winget (Windows)
winget install Microsoft.Azure.FunctionsCoreTools

# Verify installation
func --version
```

---

## 14. Cloning and Preparing the Application Code

```powershell
git clone https://github.com/<repo-owner>/azure-qr-code.git
Set-Location ".\azure-qr-code\QRCodeGenerator"

# Move your local.settings.json into this folder if you created it elsewhere
Move-Item -Path "..\..\local.settings.json" -Destination ".\local.settings.json"
```

---

## 15. Publishing the Function Code — `func azure functionapp publish`

```powershell
az login

func azure functionapp publish "day18-qr-func"
```

The `func` CLI zips your code, uploads it, and configures the runtime.
On success it prints the invoke URLs for each HTTP-triggered function
in your project.

---

## 16. Publishing Application Settings Separately

Publishing code does **not** automatically publish your
`local.settings.json` values as live Application Settings on the
Function App in Azure — that requires a separate explicit step:

```powershell
func azure functionapp publish "day18-qr-func" --publish-settings-only
```

This is a two-step process that catches a lot of beginners: pushing
code without also pushing settings leaves the deployed function
without the environment variables it needs (like the storage
connection string), which is precisely what caused part of the
instructor's debugging saga.

---

## 17. The Debugging Saga — Diagnosing "Cannot Find Module"

The function initially failed with a `500 Internal Server Error`. The
diagnostic path the instructor followed, worth learning from directly:

1. Checked the Activity Log in the Azure Portal — found a generic "bad
   request" / "internal server error from host runtime" entry, not
   immediately informative
2. Suspected the missing `local.settings.json` / storage connection
   string first — created and published it, restarted the app,
   re-tested — error persisted
3. Used **SSH into the App Service container** (available under
   Development Tools → SSH in the Portal) to inspect the raw log files
   directly, rather than relying solely on the Portal's summarised views
4. Found the specific error inside `/home/LogFiles/Application/Functions/Function/generate-qr-code`:
   ```
   Error: Cannot find module 'qrcode'
   Worker was unable to load function
   ```
5. Recognised this as a **missing dependency**, not a configuration or
   connectivity problem
6. Ran `npm install` locally, re-zipped/re-published the code, and the
   function started working

### Why SSH-ing into the container was the right move

The Portal's Activity Log and Deployment Center logs show
*deployment*-level success/failure (did the zip upload correctly?).
They do **not** show *runtime*-level errors (did the code actually run
correctly once deployed?). Those live in the function's own log files
inside the container. Knowing to go one level deeper — from "did the
deployment succeed" to "did the code that got deployed actually work"
— is the actual debugging skill here, not any specific command.

---

## 18. Why `npm install` Was the Missing Step

Node.js projects declare their dependencies in `package.json` but do
not include the actual dependency code in the repository (the
`node_modules` folder is conventionally excluded via `.gitignore`).
Running `npm install` downloads and populates `node_modules` locally.

If you clone a repository and publish it via `func azure functionapp
publish` **without** first running `npm install`, you are deploying
code that references a module (`qrcode`, in this case) that physically
does not exist anywhere in your published package. The function
crashes at load time with exactly the error seen above.

**PowerShell — the corrected sequence:**
```powershell
Set-Location ".\azure-qr-code\QRCodeGenerator"

npm install                              # <- the step that was missing
func azure functionapp publish "day18-qr-func"
func azure functionapp publish "day18-qr-func" --publish-settings-only
```

This is worth remembering as a general rule for **any** language
runtime, not just Node.js: always install/restore dependencies
(`npm install`, `pip install -r requirements.txt`, `dotnet restore`,
etc.) before packaging code for deployment, whether that packaging
happens manually or inside a CI/CD pipeline.

---

## 19. Testing the Function — Browser, Postman, PowerShell

**PowerShell — testing an HTTP-triggered function directly:**
```powershell
$functionUrl = "https://day18-qr-func.azurewebsites.net/api/generate-qr-code"

$response = Invoke-RestMethod -Uri $functionUrl -Method Get -Body @{
  url = "https://thecloudopscommunity.org"
}

$response
```

If the function requires a function-level access key (the default for
HTTP triggers unless set to `anonymous`), append it as a query parameter:
```powershell
$functionUrl = "https://day18-qr-func.azurewebsites.net/api/generate-qr-code?code=<your-function-key>"
```

You can retrieve the function key from the Portal (Function App →
Functions → your function → Function Keys) or via:
```powershell
az functionapp function keys list `
  --resource-group "day18-rg" `
  --name "day18-qr-func" `
  --function-name "generate-qr-code" `
  --query "default" -o tsv
```

---

## 20. Verifying the Output in Blob Storage

```powershell
az storage blob list `
  --account-name "techtutorialswithp123" `
  --container-name "qrcodes" `
  --output table

# Download a specific generated QR code image
az storage blob download `
  --account-name "techtutorialswithp123" `
  --container-name "qrcodes" `
  --name "<blob-name>.png" `
  --file ".\downloaded-qr.png"
```

---

## 21. Cold Start — What It Is and Why the Second Call Was Faster

**Cold start** is the delay caused when a function's hosting
infrastructure has to initialise from a stopped or scaled-down state
before it can process a request. The instructor's first call took
roughly 958ms; the second, immediately following, took roughly 228ms
— because the underlying instance was already warm from the first call.

Worth noting again from Section 3: since this project uses a Basic
(B1) dedicated plan rather than Consumption, cold starts should
generally be rarer than on a true Consumption plan (which can scale
fully to zero between invocations). The timing difference observed
here is more likely attributable to general request/connection
overhead on the first call than a full cold start — a nuance the
original walkthrough didn't distinguish clearly.

---

## 22. The Complete Working Code — All Files

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
variable "prefix" {
  type    = string
  default = "day18"
}

variable "location" {
  type    = string
  default = "Canada Central"
}
```

**`main.tf`**
```hcl
resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-rg"
  location = var.location
}

resource "azurerm_storage_account" "sa" {
  name                     = "techtutorialswithp123"
  resource_group_name     = azurerm_resource_group.rg.name
  location                = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_service_plan" "asp" {
  name                = "${var.prefix}-asp"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "B1"
}

resource "azurerm_linux_function_app" "func" {
  name                       = "${var.prefix}-qr-func"
  resource_group_name       = azurerm_resource_group.rg.name
  location                   = azurerm_resource_group.rg.location
  service_plan_id             = azurerm_service_plan.asp.id
  storage_account_name       = azurerm_storage_account.sa.name
  storage_account_access_key = azurerm_storage_account.sa.primary_access_key

  site_config {
    application_stack {
      node_version = "18"   # verify current supported versions before reuse
    }
  }
}
```

**`outputs.tf`**
```hcl
output "function_app_name" {
  value = azurerm_linux_function_app.func.name
}

output "function_app_default_hostname" {
  value = azurerm_linux_function_app.func.default_hostname
}

output "storage_account_name" {
  value = azurerm_storage_account.sa.name
}
```

---

## 23. Common Mistakes Beginners Make

**Mistake 1 — Using `azurerm_function_app` instead of the OS-specific resource**
```hcl
resource "azurerm_function_app" "func" { ... }         # deprecated
resource "azurerm_linux_function_app" "func" { ... }   # correct, current
```

**Mistake 2 — Setting `node_version` under `app_settings` instead of `application_stack`**
```hcl
# Wrong location — has no real effect on the runtime version
app_settings = { WEBSITE_NODE_DEFAULT_VERSION = "18" }

# Correct location
site_config {
  application_stack {
    node_version = "18"
  }
}
```

**Mistake 3 — Deploying code without running `npm install` first**
Covered fully in Sections 17-18. This is the single most time-costly
mistake in this entire video — always restore dependencies before
packaging for deployment.

**Mistake 4 — Publishing code but forgetting to publish settings**
```powershell
func azure functionapp publish "day18-qr-func"                          # code only
func azure functionapp publish "day18-qr-func" --publish-settings-only  # settings — separate step
```

**Mistake 5 — Committing `local.settings.json` to version control**
This file contains a live storage connection string. Add it to
`.gitignore` before your first commit, not after.

**Mistake 6 — Assuming Portal deployment logs prove the code runs correctly**
Deployment success only means the zip was uploaded and unpacked
correctly. Runtime errors (missing modules, bad connection strings)
only appear in the function's own execution logs — check those
separately when a deployed function returns 500 errors.

---

## 24. Practice Exercises

**Exercise 1** — Convert the plan in this guide's `main.tf` from Basic
(B1) to a true Consumption plan, and identify what field(s) change.

Answer: change `sku_name = "B1"` to `sku_name = "Y1"` on the
`azurerm_service_plan` resource. No other resource block needs to
change, though note that Consumption-plan functions have different
timeout and scaling defaults worth checking in the documentation.

**Exercise 2** — A colleague reports their freshly deployed Node.js
function returns `Cannot find module 'axios'`. Diagnose the likely
cause and the fix, based on Section 18.

Answer: `axios` is listed as a dependency in `package.json` but was
never installed (`node_modules/axios` doesn't exist) before the code
was packaged and published. Fix: run `npm install` in the project
directory, then republish.

**Exercise 3** — Why does deploying code with `func azure functionapp
publish` not also update environment variables set in
`local.settings.json`?

Answer: `func azure functionapp publish` by default only uploads the
application code/package. Application Settings (environment
variables visible to the running function) are a separate Azure
resource-level configuration, requiring the explicit
`--publish-settings-only` flag (or a separate Terraform
`app_settings` block) to push those values.

---

## 25. Summary Reference

Resources used in this project:
- `azurerm_resource_group`
- `azurerm_storage_account`
- `azurerm_service_plan` (Basic B1 in this project; Y1 for true Consumption billing)
- `azurerm_linux_function_app` (current, non-deprecated resource type)

Key `site_config` detail: Node.js runtime version goes in
`site_config { application_stack { node_version = "..." } }`, not in
`app_settings`.

External tooling required beyond Terraform: Azure Functions Core
Tools (`func` CLI), Node.js/npm, Git.

Deployment is a two-part process: publish code
(`func azure functionapp publish <name>`) and publish settings
separately (`func azure functionapp publish <name>
--publish-settings-only`).

The most consequential mistake demonstrated in the source video was
deploying Node.js code without first running `npm install` — a
missing-dependency error, not a Terraform or Azure configuration
error. Runtime-level errors like this are only visible in the
function's own application logs, not in Portal deployment/activity
logs.

Security note: `local.settings.json` holds a live credential and must
be excluded from version control; for anything beyond local
development or a short demo, storing that credential in Azure Key
Vault is the better long-term approach.

---

*Guide covers: Azure Functions, Function-as-a-Service vs true serverless
billing distinction, Basic B1 vs Consumption Y1 App Service Plan tiers,
azurerm_service_plan, azurerm_storage_account, azurerm_linux_function_app,
azurerm_function_app deprecation, site_config and application_stack blocks,
node_version configuration, storage account global naming uniqueness,
local.settings.json and connection string handling, Azure Functions Core
Tools installation and usage, func azure functionapp publish, the
--publish-settings-only flag, npm install as a required pre-deployment
step, diagnosing "Cannot find module" runtime errors, SSH access to App
Service containers for log inspection, distinguishing deployment-level
success from runtime-level success, cold start behaviour, testing HTTP
triggers via PowerShell Invoke-RestMethod and Azure CLI, function key
retrieval, blob storage verification commands, and cross-references to
Day 3 (storage naming), Day 9 (dependency-adjacent troubleshooting
mindset), and Day 17 (deprecated resource migration pattern).*
