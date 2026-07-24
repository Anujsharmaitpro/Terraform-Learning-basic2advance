# Apex Industries — Cloud Infrastructure Training Series
## Multi-Tier Lab 1 — Web Tier + App Tier
**Project Code:** `APX-INFRA-007` | **Level:** Beginner+++ | **Frequency:** Used everywhere
**Environment:** Windows + VS Code + PowerShell | Fully self-contained | Cost: ~$0.15/session

---

> **From your Team Lead:** You built this exact architecture once
> in Meridian (MRB-006). This ticket reuses it deliberately — but
> this time you'll deploy real, tiny application code so you can
> actually SEE the Web Tier talk to the App Tier, not just infer
> it from Terraform state. One important correction from the
> original design: App Service networking splits inbound and
> outbound into two separate mechanisms. Get both halves right
> this time. — *Morgan Chen*

---

## 1. Overview

### The Concept to Understand First — Two Mechanisms, Not One

Azure App Service handles inbound and outbound traffic completely
separately. This trips up almost everyone building their first
multi-tier app, so read this before writing any code:

```
VNet Integration (swift_connection)
  → OUTBOUND only. Lets the App Service reach INTO the VNet.
  → Does NOT make the App Service reachable FROM the VNet.

Private Endpoint
  → INBOUND only. Gives the App Service a private IP inside
    the VNet, reachable from other things in that VNet.
```

The App Tier needs BOTH: VNet Integration (so it *could* reach
other things in the VNet later) and a Private Endpoint (so the
Web Tier can actually reach it now). Using only one of these two
mechanisms — which earlier guidance in this series mistakenly
did — leaves the App Tier either fully public or fully
unreachable, never genuinely private.

### What's Reused vs What's New

```
REUSED (build from memory, exactly as MRB-006):
  - web-subnet and app-subnet, each delegated to Microsoft.Web/serverFarms
  - B1 App Service Plan (VNet Integration requires this, not F1)
  - Two App Services, each VNet-integrated into its own subnet
  - App Tier: public_network_access_enabled = false

GENUINELY NEW THIS PROJECT:
  - A THIRD subnet, dedicated to Private Endpoints
  - A Private Endpoint on the App Tier — this is what actually
    makes it reachable from the Web Tier
  - dynamic "security_rule" block on the NSG, replacing static rules
  - Real application code deployed (tiny Flask apps)
```

### The New Concept — `dynamic` Reintroduced on NSG Rules

MRB-006 wrote its NSG with two hardcoded `security_rule` blocks.
This project rebuilds the same NSG using a `dynamic` block driven
by a map — reusing the exact mechanic from MRB-006's Action Group
email receivers and NCT-009's alerts, applied to a resource type
you haven't used `dynamic` on before.

```hcl
variable "nsg_rules" {
  type = map(object({
    priority = number
    access   = string
    port     = string
    source   = string
  }))
}
```

```hcl
# terraform.tfvars
nsg_rules = {
  "allow-from-web" = { priority = 100, access = "Allow", port = "*", source = "10.0.1.0/24" }
  "deny-all"         = { priority = 200, access = "Deny",  port = "*", source = "*" }
}
```

```hcl
resource "azurerm_network_security_group" "app_nsg" {
  name                = "${local.name_prefix}-app-nsg"
  location             = azurerm_resource_group.rg.location
  resource_group_name  = azurerm_resource_group.rg.name

  dynamic "security_rule" {
    for_each = var.nsg_rules
    content {
      name                        = security_rule.key
      priority                     = security_rule.value.priority
      direction                     = "Inbound"
      access                         = security_rule.value.access
      protocol                        = "Tcp"
      source_port_range                = "*"
      destination_port_range            = security_rule.value.port
      source_address_prefix              = security_rule.value.source
      destination_address_prefix          = "*"
    }
  }
  tags = local.common_tags
}
```

### Reused Without Guidance
`azurerm_resource_group`, both App Service Plan and App Services,
VNet Integration (`azurerm_app_service_virtual_network_swift_connection`)
— you built all of these in MRB-006. No step-by-step guidance for
those pieces.

---

## 2. Naming + Tags

| Resource | Name |
|---|---|
| Resource Group | `apx-dev-007-rg` |
| VNet | `apx-dev-007-vnet` |
| Web / App Subnets | `apx-dev-007-web-subnet` (10.0.1.0/24), `apx-dev-007-app-subnet` (10.0.2.0/24) |
| PE Subnet (new) | `apx-dev-007-pe-subnet` (10.0.3.0/24) |
| App Service Plan | `apx-dev-007-plan` |
| Web / App Tier | `apx-dev-007-web-jd`, `apx-dev-007-app-jd` |
| App Tier Private Endpoint | `apx-dev-007-app-pe` |

```hcl
# terraform.tfvars
org_prefix           = "apx"
environment          = "dev"
azure_location       = "East US"
resource_group_name  = "apx-dev-007-rg"
owner_name           = "sam-rivera"
```

---

## 3. Core Components

### Component 1 — Networking: Three Subnets (Build web/app From Memory, PE Subnet Is New)

```hcl
resource "azurerm_subnet" "pe_subnet" {
  name                 = "apx-dev-007-pe-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name  = azurerm_virtual_network.vnet.name
  address_prefixes        = ["10.0.3.0/24"]

  private_endpoint_network_policies_enabled = false
}
```

> This project has no data-tier subnet yet (that's what APX-008
> adds next), so this is a genuinely new subnet — there's nothing
> to reuse it from, unlike the Meridian capstone where a
> data-subnet already existed for SQL.

### Component 2 — Dynamic NSG (New — shown above in full)

### Component 3 — App Service Plan + Both Tiers (Build From Memory, MRB-006 Pattern)

`B1` plan, two `azurerm_linux_web_app` resources, both with
`azurerm_app_service_virtual_network_swift_connection`, App Tier
with `public_network_access_enabled = false`.

### Component 4 — App Tier Private Endpoint (New — The Piece That Makes It Actually Work)

```hcl
resource "azurerm_private_endpoint" "app_tier_pe" {
  name                = "apx-dev-007-app-pe"
  location             = azurerm_resource_group.rg.location
  resource_group_name  = azurerm_resource_group.rg.name
  subnet_id             = azurerm_subnet.pe_subnet.id

  private_service_connection {
    name                            = "app-tier-connection"
    private_connection_resource_id  = azurerm_linux_web_app.app_tier.id
    subresource_names                 = ["sites"]
    is_manual_connection                = false
  }
  tags = local.common_tags
}

resource "azurerm_private_dns_zone" "app_dns" {
  name                = "privatelink.azurewebsites.net"
  resource_group_name = azurerm_resource_group.rg.name
  tags                  = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "app_dns_link" {
  name                    = "apx-dev-007-app-dns-link"
  resource_group_name    = azurerm_resource_group.rg.name
  private_dns_zone_name   = azurerm_private_dns_zone.app_dns.name
  virtual_network_id       = azurerm_virtual_network.vnet.id
}

resource "azurerm_private_dns_a_record" "app_dns_record" {
  name                = azurerm_linux_web_app.app_tier.name
  zone_name           = azurerm_private_dns_zone.app_dns.name
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 300
  records              = [azurerm_private_endpoint.app_tier_pe.private_service_connection[0].private_ip_address]
}
```

> Same four-piece pattern as any Private Endpoint you'll build
> (SQL's, in APX-008): endpoint, DNS zone, VNet link, A record.
> `subresource_names = ["sites"]` is the App Service-specific
> value — different from SQL's `["sqlServer"]`.

### Component 5 — Real Application Code

**`app-tier/app.py`:**
```python
from flask import Flask, jsonify
app = Flask(__name__)

@app.route('/')
def home():
    return jsonify({"tier": "app", "status": "ok", "message": "Hello from App Tier"})
```

**`app-tier/requirements.txt`:**
```
flask
```

**`web-tier/app.py`:**
```python
from flask import Flask, jsonify
import requests
import os

app = Flask(__name__)
APP_TIER_URL = os.environ.get("APP_TIER_URL", "http://localhost:8000")

@app.route('/')
def home():
    try:
        app_response = requests.get(APP_TIER_URL, timeout=5).json()
    except Exception as e:
        app_response = {"error": str(e)}
    return jsonify({"web_says": "Hello from Web Tier", "app_tier_replied": app_response})
```

**`web-tier/requirements.txt`:**
```
flask
requests
```

**Wire the App Tier's private hostname into the Web Tier via
`app_settings`:**

```hcl
resource "azurerm_linux_web_app" "web_tier" {
  # ... existing config ...
  app_settings = {
    "APP_TIER_URL" = "https://${azurerm_linux_web_app.app_tier.default_hostname}"
  }
}
```

### Component 6 — Deploy the Code

```powershell
Compress-Archive -Path .\app-tier\* -DestinationPath app-tier.zip -Force
Compress-Archive -Path .\web-tier\* -DestinationPath web-tier.zip -Force
az webapp deploy --resource-group apx-dev-007-rg --name apx-dev-007-app-jd --src-path app-tier.zip --type zip
az webapp deploy --resource-group apx-dev-007-rg --name apx-dev-007-web-jd --src-path web-tier.zip --type zip
```

---

## 4. Hints

**Hint 1 — Give the deploy a minute or two to finish building:**
Azure installs `requirements.txt` dependencies on deploy — this
takes longer than the deploy command returning.

**Hint 2 — Test the negative case first, before the positive one:**
after applying, confirm your OWN laptop cannot reach
`https://apx-dev-007-app-jd.azurewebsites.net` directly. This is
the check that proves the App Tier is genuinely private, not just
assumed to be.

**Hint 3 — `subresource_names` differs by resource type:** App
Service uses `["sites"]`. You'll see `["sqlServer"]` for SQL in
APX-008 — always check which subresource name a given resource
type expects before building its Private Endpoint.

---

## 5. Workflow (PowerShell)

```powershell
cd C:\Projects\apx-infra-007

terraform init; terraform validate; terraform fmt
terraform plan -out=tfplan
terraform apply tfplan

Compress-Archive -Path .\app-tier\* -DestinationPath app-tier.zip -Force
Compress-Archive -Path .\web-tier\* -DestinationPath web-tier.zip -Force
az webapp deploy --resource-group apx-dev-007-rg --name apx-dev-007-app-jd --src-path app-tier.zip --type zip
az webapp deploy --resource-group apx-dev-007-rg --name apx-dev-007-web-jd --src-path web-tier.zip --type zip

# Verify App Tier is genuinely closed to the public
Invoke-WebRequest "https://apx-dev-007-app-jd.azurewebsites.net" -TimeoutSec 5
# Expected: FAILS

# THE ACTUAL TEST
$webUrl = terraform output -raw web_tier_url
Start-Process $webUrl
# Expected: JSON showing Web Tier's message AND App Tier's nested reply

terraform destroy
```

---

## 6. Checklist

```
[ ] pe_subnet added with private_endpoint_network_policies_enabled = false
[ ] nsg_rules variable declared as map(object({...}))
[ ] dynamic "security_rule" used, not static blocks
[ ] App Tier has public_network_access_enabled = false
[ ] App Tier Private Endpoint present, subresource_names = ["sites"]
[ ] privatelink.azurewebsites.net zone, link, and A record all present
[ ] Web Tier's app_settings references App Tier's default_hostname
[ ] Both zip files deployed via az webapp deploy after terraform apply
[ ] Direct request to App Tier's public hostname FAILS from your laptop
[ ] Opening the Web Tier URL shows the App Tier's nested response
[ ] terraform destroy completed
```

---

## 7. Cost
`B1` plan shared by both apps (~$0.018/hr) + Private Endpoint
(~$0.01/hr). **A 2-3 hour session: well under $0.15.**

## Downstream Impact
APX-008 builds directly on this project's foundation and reuses
this Private Endpoint pattern for SQL. Get this project fully
working and verified before moving to APX-008.

## Series Status
```
APX-006   ✅  Load Balancer + VMSS
APX-007   ✅  Multi-Tier Lab 1 — Web + App Tier, genuinely private  ← THIS PROJECT
APX-008   📋  Multi-Tier Lab 2 — Add Data Tier
```

*Apex Industries — Cloud Platform Engineering | Training Series*
