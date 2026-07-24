# Apex Industries — Cloud Infrastructure Training Series
## Traffic Manager + A Real QR Code Generator App
**Project Code:** `APX-INFRA-009` | **Level:** Beginner+++ | **Frequency:** Common
**Environment:** Windows + VS Code + PowerShell | Fully self-contained | Cost: ~$0.01

---

> **From your Team Lead:** Every project so far proved
> infrastructure works using JSON responses — technically correct,
> not very satisfying. This ticket is different: you're deploying
> a genuinely useful little app — a QR code generator — to TWO
> Function Apps, fronted by Traffic Manager. By the end, you'll
> have a real URL you can text to a friend that turns any text
> into a scannable QR code. — *Morgan Chen*

---

## 1. Overview

### The Terraform Lesson (Unchanged From the Roadmap)

Traffic Manager, Priority routing, two endpoints — identical
structure to MRB-005. Build the `azurerm_traffic_manager_profile`
and `azurerm_traffic_manager_azure_endpoint` resources exactly as
you did there (for_each on `map(object({name, priority}))`, same
pattern). No new Terraform concepts.

### The Part That's Actually New — A Real, Fun App

Instead of two placeholder App Services, you're deploying the SAME
small Python Function App to two Function Apps — a genuine QR
code generator, using the `qrcode` Python library, that takes text
via a URL parameter and returns an actual scannable QR code image.

```
https://your-traffic-manager-url.trafficmanager.net/api/generate?text=HelloWorld
   → returns a real PNG image of a QR code encoding "HelloWorld"
   → open it in a browser, or scan it with your phone camera
```

### What You Are Building

```
Traffic Manager (apx-dev-009-tm)
  Priority routing
     |                    |
Priority 1              Priority 2
(Primary)                (Failover)
     v                    v
Function App: qr-primary   Function App: qr-secondary
  Both run IDENTICAL code — the QR generator
```

### Reused Without Guidance
`azurerm_resource_group`, `azurerm_service_plan` (`Y1`
Consumption — same as NCT-008), `azurerm_linux_function_app` x2
via `for_each` — same `map(object)` pattern as MRB-005's App
Services, just pointed at Function Apps instead.

---

## 2. Naming + Tags

| Resource | Name |
|---|---|
| Resource Group | `apx-dev-009-rg` |
| Traffic Manager Profile | `apx-dev-009-tm` |
| Storage Account (Function App requirement) | `apxdev009sajd` |
| Function App Plan | `apx-dev-009-plan` |
| Function Apps | `apx-dev-009-qr-primary-jd`, `apx-dev-009-qr-secondary-jd` |

```hcl
# terraform.tfvars
org_prefix           = "apx"
environment          = "dev"
azure_location       = "East US"
resource_group_name  = "apx-dev-009-rg"
storage_account_name  = "apxdev009sajd"
owner_name              = "sam-rivera"

func_endpoints = {
  "qr-primary"   = { name = "apx-dev-009-qr-primary-jd",   priority = 1 }
  "qr-secondary" = { name = "apx-dev-009-qr-secondary-jd", priority = 2 }
}
```

---

## 3. Core Components

### Component 1 — Storage + Function App Plan (Build From Memory, NCT-008 Pattern)

`Y1` Consumption plan, Storage Account with `primary_connection_string`
wired into `AzureWebJobsStorage`. Exact NCT-008 pattern.

### Component 2 — Two Function Apps via `for_each`

```hcl
resource "azurerm_linux_function_app" "qr_func" {
  for_each                    = var.func_endpoints
  name                          = each.value.name
  resource_group_name         = azurerm_resource_group.rg.name
  location                      = azurerm_resource_group.rg.location
  service_plan_id                = azurerm_service_plan.plan.id
  storage_account_name            = azurerm_storage_account.sa.name
  storage_account_access_key       = azurerm_storage_account.sa.primary_access_key

  site_config {
    application_stack {
      python_version = "3.11"
    }
  }

  app_settings = {
    "AzureWebJobsStorage"       = azurerm_storage_account.sa.primary_connection_string
    "FUNCTIONS_WORKER_RUNTIME"    = "python"
  }

  lifecycle {
    ignore_changes = [
      app_settings["WEBSITE_CONTENTSHARE"]
    ]
  }
  tags = local.common_tags
}
```

> Same `for_each` on `map(object)` pattern from MRB-005, applied
> to Function Apps instead of standard App Services — a good
> example of the same mechanic transferring cleanly to a new
> resource type.

### Component 3 — Traffic Manager (Build From Memory, MRB-005 Pattern)

```hcl
resource "azurerm_traffic_manager_profile" "tm" {
  name                        = "apx-dev-009-tm-jd"
  resource_group_name         = azurerm_resource_group.rg.name
  traffic_routing_method       = "Priority"

  dns_config {
    relative_name = "apx-dev-009-jd"
    ttl             = 30
  }

  monitor_config {
    protocol                       = "HTTPS"
    port                             = 443
    path                              = "/api/generate?text=healthcheck"
    interval_in_seconds                = 30
    timeout_in_seconds                  = 10
    tolerated_number_of_failures         = 3
  }
  tags = local.common_tags
}

resource "azurerm_traffic_manager_azure_endpoint" "endpoints" {
  for_each             = var.func_endpoints
  name                   = "${each.key}-endpoint"
  profile_id              = azurerm_traffic_manager_profile.tm.id
  target_resource_id       = azurerm_linux_function_app.qr_func[each.key].id
  priority                  = each.value.priority
}
```

> Notice `monitor_config.path` points AT your actual QR endpoint
> — Traffic Manager's health check literally generates a test QR
> code every 30 seconds to confirm the Function App is alive. A
> nice small detail: your health check IS a real use of the app,
> not a separate dummy endpoint.

### Component 4 — The Actual QR Code Generator Code (New)

**`qr-function/function_app.py`:**

```python
import azure.functions as func
import qrcode
import io

app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)

@app.route(route="generate")
def generate(req: func.HttpRequest) -> func.HttpResponse:
    text = req.params.get('text')
    if not text:
        return func.HttpResponse(
            "Pass a 'text' parameter in the URL, e.g. ?text=HelloWorld",
            status_code=400
        )

    qr = qrcode.QRCode(version=1, box_size=10, border=4)
    qr.add_data(text)
    qr.make(fit=True)
    img = qr.make_image(fill_color="black", back_color="white")

    buf = io.BytesIO()
    img.save(buf, format="PNG")
    buf.seek(0)

    return func.HttpResponse(
        buf.getvalue(),
        mimetype="image/png",
        status_code=200
    )
```

**`qr-function/requirements.txt`:**
```
azure-functions
qrcode[pil]
```

**`qr-function/host.json`:**
```json
{
  "version": "2.0",
  "logging": {
    "applicationInsights": {
      "samplingSettings": {
        "isEnabled": true
      }
    }
  }
}
```

> **The honest debugging note, same spirit as your reference
> guide's `npm install` saga:** `qrcode[pil]` is important — plain
> `qrcode` without `[pil]` will install but FAIL at runtime when
> you actually try to generate an image, because the Pillow
> imaging library isn't pulled in automatically. This is exactly
> the kind of "looks fine, fails at the worst moment" dependency
> trap that guide warned about. Get the `[pil]` extra right the
> first time and save yourself the debugging loop.

### Component 5 — Deploy the Same Code to BOTH Function Apps

```powershell
# Zip the function code once
Compress-Archive -Path .\qr-function\* -DestinationPath qr-function.zip -Force

# Deploy the SAME zip to both — identical code, different endpoints
az functionapp deployment source config-zip `
  --resource-group apx-dev-009-rg `
  --name apx-dev-009-qr-primary-jd `
  --src qr-function.zip

az functionapp deployment source config-zip `
  --resource-group apx-dev-009-rg `
  --name apx-dev-009-qr-secondary-jd `
  --src qr-function.zip
```

---

## 4. Hints

**Hint 1 — First request after Consumption plan cold start is
slow:** Y1 Function Apps "sleep" after inactivity, same as APX
Function Apps built earlier. First request can take 10-30 seconds
to wake up — this is normal, not a bug.

**Hint 2 — `qrcode[pil]`, not just `qrcode`** — see the debugging
note above. This is the single most likely thing to trip you up
on this project.

**Hint 3 — Test each Function App directly BEFORE testing through
Traffic Manager:** isolate problems by hitting each Function App's
own URL first
(`https://apx-dev-009-qr-primary-jd.azurewebsites.net/api/generate?text=test`)
before testing the Traffic Manager FQDN. If the direct URL fails,
the problem is in your Function App code/deploy, not in Traffic
Manager — fix that layer first.

---

## 5. Workflow (PowerShell) — Including the Real Test

```powershell
cd C:\Projects\apx-infra-009

terraform init; terraform validate; terraform fmt
terraform plan -out=tfplan
terraform apply tfplan

# Deploy the SAME QR generator code to both Function Apps
Compress-Archive -Path .\qr-function\* -DestinationPath qr-function.zip -Force
az functionapp deployment source config-zip --resource-group apx-dev-009-rg --name apx-dev-009-qr-primary-jd --src qr-function.zip
az functionapp deployment source config-zip --resource-group apx-dev-009-rg --name apx-dev-009-qr-secondary-jd --src qr-function.zip

# Test each Function App directly first
Start-Process "https://apx-dev-009-qr-primary-jd.azurewebsites.net/api/generate?text=DirectTestPrimary"

# THE ACTUAL TEST — through Traffic Manager
$tmUrl = terraform output -raw traffic_manager_fqdn
Start-Process "https://$tmUrl/api/generate?text=HelloFromApexIndustries"
```

**What you should see:** a real, scannable QR code image opens in
your browser. Scan it with your phone — it decodes back to
"HelloFromApexIndustries." This is genuinely deployed, genuinely
working, genuinely yours.

**Try the failover, same as MRB-005:**
```powershell
az functionapp stop --name apx-dev-009-qr-primary-jd --resource-group apx-dev-009-rg
# Wait ~1-2 minutes for Traffic Manager's health check to notice
Start-Process "https://$tmUrl/api/generate?text=FailoverTest"
# Should still work — routed to secondary automatically
az functionapp start --name apx-dev-009-qr-primary-jd --resource-group apx-dev-009-rg
```

```powershell
terraform destroy
```

---

## 6. Checklist

```
[ ] func_endpoints declared as map(object({name, priority}))
[ ] for_each used for both Function Apps AND Traffic Manager endpoints
[ ] requirements.txt uses "qrcode[pil]" not just "qrcode"
[ ] monitor_config.path points at a real, working endpoint
[ ] Same zip deployed to BOTH Function Apps
[ ] Direct Function App URL tested and working before Traffic Manager test
[ ] Traffic Manager URL produces a real, scannable QR code
[ ] Failover tested — stopping primary still returns a working QR code
[ ] terraform destroy completed
```

---

## 7. Cost
Traffic Manager: fractions of a cent per session. Two `Y1`
Consumption Function Apps: free tier covers this easily (1M
executions/month free). **Total: essentially $0.00.**

## Series Status
```
APX-008   ✅  Multi-Tier Lab 2 — Data Tier
APX-009   ✅  Traffic Manager + Real QR Code Generator App     ← THIS PROJECT
APX-010   📋  Capstone — Full Corporate Stack
```

---

## A Note on This Project's Design

This is the project that most directly answers your "I want to
feel like I've deployed something" request. Every previous
project proved connectivity through JSON. This one gives you an
actual URL, a real image, something you could genuinely text to
a friend right now and say "I built this." That feeling is worth
protecting — if a future project in this series ever drifts back
toward pure JSON-proof-of-concept territory, flag it and this
pattern (a small, real, fun, useful app) is the one to fall back on.

*Apex Industries — Cloud Platform Engineering | Training Series*
