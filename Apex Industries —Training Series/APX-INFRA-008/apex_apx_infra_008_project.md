# Apex Industries — Cloud Infrastructure Training Series
## Multi-Tier Lab 2 — Add Data Tier via Private Endpoint
**Project Code:** `APX-INFRA-008` | **Level:** Beginner+++ | **Frequency:** Common
**Environment:** Windows + VS Code + PowerShell | Fully self-contained | Cost: ~$1.00/session

---

> **From your Team Lead:** You built this exact SQL pattern once
> already in Meridian (MRB-007) — and it was correct there from
> the start, since SQL only has one access mode to worry about.
> The App Tier's private connectivity, which you fixed in
> APX-007, carries forward here unchanged — you're not fixing
> anything new for the App Tier in this ticket, only adding the
> Data Tier on top of an already-correct foundation.
> — *Morgan Chen*

---

## 1. Overview

### Zero New Terraform Concepts — By Design

This project deliberately introduces nothing new at the Terraform
level. Every resource here — `azurerm_mssql_server` with
`public_network_access_enabled = false`, `azurerm_private_endpoint`,
`azurerm_private_dns_zone` + VNet Link + A Record — is identical
to MRB-007, and you already built the equivalent pattern for the
App Tier in APX-007. The only genuinely new piece is wiring the
SQL connection into APX-007's real Flask app code so the browser
output shows live database content.

```
APX-007 gave you:  Web Tier -> App Tier (JSON response),
                    App Tier genuinely private via its own PE

APX-008 adds:       Web Tier -> App Tier -> Private SQL (JSON now
                     includes a real row pulled from the database)
```

### Prerequisite — Confirm Before Starting

This project assumes you're building on the CORRECTED version of
APX-007 — the one with `pe-subnet`, the App Tier's Private
Endpoint, and the `privatelink.azurewebsites.net` DNS chain
already in place. If you haven't applied that fix yet, do it first
and confirm the App Tier is genuinely reachable from the Web Tier
before adding the Data Tier on top.

### What You Are Building

```
Extends APX-007 exactly:

Web Tier (public) -> App Tier
                       OUTBOUND: VNet Integration into app-subnet
                       INBOUND:  Private Endpoint (from APX-007) ->
                                 pe-subnet
                          |
                          v
              NEW: SQL Private Endpoint -> data-subnet
                          |
              +-----------+------------+
              v                        v
      Azure SQL Server          Private DNS Zone
      (no public access)        privatelink.database.windows.net
```

### Reused Without Guidance (Build All of This From Memory)
- Everything from the corrected APX-007 (Web + App Tier, dynamic
  NSG, App Tier Private Endpoint + DNS chain in `pe-subnet`)
- Key Vault (RBAC model) + two SQL credential secrets [MRB-002/003]
- `azurerm_mssql_server` with `public_network_access_enabled = false`,
  NO firewall rules [MRB-007]
- `azurerm_mssql_database`, Basic SKU, 2GB [NCT-007]

---

## 2. Naming + Tags

| Resource | Name |
|---|---|
| Resource Group | `apx-dev-008-rg` |
| Data Subnet (new) | `apx-dev-008-data-subnet` (10.0.4.0/24) |
| SQL Server | `apx-dev-008-sql-jd` |
| SQL Database | `apx-dev-008-app-db` |
| SQL Private Endpoint | `apx-dev-008-sql-pe` |

```hcl
# terraform.tfvars — extends APX-007's shape
org_prefix           = "apx"
environment          = "dev"
azure_location       = "East US"
resource_group_name  = "apx-dev-008-rg"
key_vault_name        = "apx-dev-008-kv"
sql_server_name        = "apx-dev-008-sql-jd"
sql_database_name       = "apx-dev-008-app-db"
owner_name              = "sam-rivera"
```

---

## 3. Core Components

### Component 1 — Networking: Add a Fourth Subnet for SQL

```hcl
resource "azurerm_subnet" "data_subnet" {
  name                 = "apx-dev-008-data-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name  = azurerm_virtual_network.vnet.name
  address_prefixes        = ["10.0.4.0/24"]

  private_endpoint_network_policies_enabled = false
}
```

> This is a NEW subnet, separate from APX-007's `pe-subnet`
> (which hosts the App Tier's Private Endpoint). You could
> technically reuse `pe-subnet` for SQL's Private Endpoint too —
> a subnet can host multiple PEs of different types — but keeping
> them separate here mirrors the naming clarity of a genuine
> "data tier" subnet, matching MRB-007/010's pattern.

### Component 2 — Key Vault + SQL Credentials (Build From Memory)

Same pattern as MRB-002/003, MRB-007. RBAC Key Vault, two secrets
(`sql-admin-username`, `sql-admin-password`), data sources with
`depends_on`. No new guidance.

### Component 3 — SQL Server with Public Access Disabled (Build From Memory)

```hcl
resource "azurerm_mssql_server" "sql_srv" {
  # ... administrator_login/password from Key Vault ...
  public_network_access_enabled = false
}

resource "azurerm_mssql_database" "app_db" {
  server_id   = azurerm_mssql_server.sql_srv.id
  sku_name      = "Basic"
  max_size_gb     = 2
}
```

> No `azurerm_mssql_firewall_rule` resources — same as MRB-007.
> With no public access, there's nothing for a firewall rule to
> filter.

### Component 4 — SQL Private Endpoint + DNS Chain

```hcl
resource "azurerm_private_endpoint" "sql_pe" {
  name                = "apx-dev-008-sql-pe"
  location             = azurerm_resource_group.rg.location
  resource_group_name  = azurerm_resource_group.rg.name
  subnet_id             = azurerm_subnet.data_subnet.id

  private_service_connection {
    name                            = "sql-connection"
    private_connection_resource_id  = azurerm_mssql_server.sql_srv.id
    subresource_names                 = ["sqlServer"]
    is_manual_connection                = false
  }
}

resource "azurerm_private_dns_zone" "sql_dns" {
  name                = "privatelink.database.windows.net"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "sql_dns_link" {
  name                    = "apx-dev-008-sql-dns-link"
  resource_group_name    = azurerm_resource_group.rg.name
  private_dns_zone_name   = azurerm_private_dns_zone.sql_dns.name
  virtual_network_id       = azurerm_virtual_network.vnet.id
}

resource "azurerm_private_dns_a_record" "sql_dns_record" {
  name                = azurerm_mssql_server.sql_srv.name
  zone_name           = azurerm_private_dns_zone.sql_dns.name
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 300
  records              = [azurerm_private_endpoint.sql_pe.private_service_connection[0].private_ip_address]
}
```

> Compare this to APX-007's App Tier Private Endpoint — same
> four-piece pattern, different `subresource_names` (`["sqlServer"]`
> vs `["sites"]`) and different DNS zone name
> (`privatelink.database.windows.net` vs `privatelink.azurewebsites.net`).
> If you can build one, you can build the other from the same
> mental template.

### Component 5 — Application Code Update

**`app-tier/app.py`** — now queries the database:

```python
from flask import Flask, jsonify
import pyodbc
import os

app = Flask(__name__)
SQL_SERVER = os.environ.get("SQL_SERVER")
SQL_DATABASE = os.environ.get("SQL_DATABASE")
SQL_USER = os.environ.get("SQL_USER")
SQL_PASSWORD = os.environ.get("SQL_PASSWORD")

@app.route('/')
def home():
    try:
        conn_str = (
            f"DRIVER={{ODBC Driver 18 for SQL Server}};"
            f"SERVER={SQL_SERVER};DATABASE={SQL_DATABASE};"
            f"UID={SQL_USER};PWD={SQL_PASSWORD};Encrypt=yes;TrustServerCertificate=no;"
        )
        conn = pyodbc.connect(conn_str, timeout=5)
        cursor = conn.cursor()
        cursor.execute("SELECT 'Hello from the private database!' AS message")
        row = cursor.fetchone()
        db_message = row.message
        conn.close()
    except Exception as e:
        db_message = f"DB connection failed: {str(e)}"

    return jsonify({"tier": "app", "db_message": db_message})
```

**`app-tier/requirements.txt`:**
```
flask
pyodbc
```

**Wire the SQL credentials into the App Tier's `app_settings`:**

```hcl
resource "azurerm_linux_web_app" "app_tier" {
  # ... existing config from APX-007 ...
  app_settings = {
    "SQL_SERVER"    = azurerm_mssql_server.sql_srv.fully_qualified_domain_name
    "SQL_DATABASE"   = azurerm_mssql_database.app_db.name
    "SQL_USER"        = data.azurerm_key_vault_secret.sql_admin_username.value
    "SQL_PASSWORD"     = data.azurerm_key_vault_secret.sql_admin_password.value
  }
}
```

### Seed the Database With One Row

> **Honest note:** because this SQL Server has NO public access
> at all, connecting to it directly from your laptop to seed data
> is genuinely difficult. Use the Azure Portal's Query Editor,
> which connects via Azure's internal network rather than the
> public internet.

---

## 4. Hints

**Hint 1 — Confirm APX-007's App Tier fix is in place BEFORE
starting this project:** if the App Tier isn't already genuinely
reachable from the Web Tier, adding a database on top won't fix
that underlying issue — you'll just have two problems instead of
one.

**Hint 2 — Same DNS chain discipline as always:** zone + VNet link
+ A record, all three required. The A record is the one most
often forgotten — it's the piece that actually maps the hostname
to the private IP.

**Hint 3 — `pyodbc` connection strings are unforgiving about exact
syntax:** copy the connection string format in this spec exactly
rather than reconstructing it from memory.

---

## 5. Workflow (PowerShell)

```powershell
cd C:\Projects\apx-infra-008

terraform init; terraform validate; terraform fmt
terraform plan -out=tfplan
terraform apply tfplan

Compress-Archive -Path .\app-tier\* -DestinationPath app-tier.zip -Force
Compress-Archive -Path .\web-tier\* -DestinationPath web-tier.zip -Force
az webapp deploy --resource-group apx-dev-008-rg --name apx-dev-008-app-jd --src-path app-tier.zip --type zip
az webapp deploy --resource-group apx-dev-008-rg --name apx-dev-008-web-jd --src-path web-tier.zip --type zip

# Seed the database via Azure Portal Query Editor

# Verify App Tier still genuinely private
Invoke-WebRequest "https://apx-dev-008-app-jd.azurewebsites.net" -TimeoutSec 5
# Expected: FAILS

# Verify SQL has no public access
az sql server show --name apx-dev-008-sql-jd --resource-group apx-dev-008-rg `
  --query "publicNetworkAccess" --output tsv
# Expected: Disabled

# THE ACTUAL TEST
$webUrl = terraform output -raw web_tier_url
Start-Process $webUrl
# Expected: JSON showing real database content

terraform destroy
az keyvault purge --name apx-dev-008-kv --location "East US"
```

---

## 6. Checklist

```
[ ] Confirmed APX-007's App Tier Private Endpoint fix is already in place
[ ] data-subnet added for SQL, private_endpoint_network_policies_enabled = false
[ ] SQL Server: public_network_access_enabled = false, NO firewall rules
[ ] SQL Private Endpoint, subresource_names = ["sqlServer"]
[ ] privatelink.database.windows.net zone, link, and A record present
[ ] SQL_SERVER/SQL_DATABASE/SQL_USER/SQL_PASSWORD wired into app_settings
[ ] App Tier code updated to query SQL and return the result
[ ] Database seeded with at least one row before testing
[ ] Web Tier browser output shows real db_message content
[ ] terraform destroy + Key Vault purge completed
```

---

## 7. Cost
SQL Basic (~$5/month if left running — destroy same session) +
Private Endpoint (~$0.01/hr) + `B1` plan (~$0.018/hr). **A 3-4
hour lab session: comfortably under $1.**

## Series Status
```
APX-007   Multi-Tier Lab 1 — Web + App Tier, genuinely private
APX-008   Multi-Tier Lab 2 — Data Tier, real DB content shown  <- THIS PROJECT
APX-009   Traffic Manager + QR Generator
```

*Apex Industries — Cloud Platform Engineering | Training Series*
