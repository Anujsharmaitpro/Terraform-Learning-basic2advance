# Meridian Bank — Cloud Infrastructure Training Series
## Multi-Tier Design Part 2 — Add Data Tier via Private Endpoint
**Project Code:** `MRB-INFRA-007` | **Level:** Intermediate | **Frequency:** Common in orgs with a database
**Environment:** Windows + VS Code + PowerShell | Fully self-contained (no dependency on MRB-006)

---

> **From your Team Lead:** Back in NCT-007 you secured a SQL
> Database with firewall rules — an allow-list of IP addresses.
> That is fine for dev, but a determined attacker on an allowed
> network segment can still reach it. Private Endpoint removes
> the public entry point entirely. The database gets a private
> IP inside your VNet — full stop, no public IP exists at all.
> This is the bank-grade standard. — *Rohan Mehta*

---

## Org Context
`dev` | `East US` | `CC-CLOUD-001` | Fully standalone — builds its
own Web + App + Data tiers fresh, does not require MRB-006 to be
running

---

## 1. Overview

**Three tiers, this time all in one project: Web, App, and a SQL
Database reachable ONLY through a Private Endpoint inside the VNet.**

```
Web Tier (public) → App Tier (private, VNet-integrated)
                          │
                          ▼
              Private Endpoint (10.0.3.4)
                          │
              ┌───────────┴────────────┐
              ▼                        ▼
      Azure SQL Server          Private DNS Zone
      (no public access)        resolves the SQL hostname
                                 to the PRIVATE IP above
```

### The New Concept — Private Endpoint + Private DNS

**The old way (NCT-007):** SQL Server has a public IP. Firewall
rules decide WHO on the public internet can reach it. The server
is still, technically, on the internet.

**The new way (this project):** SQL Server has NO public access
at all. A Private Endpoint creates a network interface with a
PRIVATE IP address (like `10.0.3.4`) inside your VNet. Only
things inside that VNet can reach the database — there is
nothing to firewall because there is no public path to begin with.

**Why you also need a Private DNS Zone:** your application code
will try to connect using the SQL Server's normal hostname
(`mrb-dev-007-sql.database.windows.net`). Without any DNS
intervention, that hostname resolves to Azure's public IP —
which no longer accepts connections. The Private DNS Zone
intercepts that same hostname and resolves it to the PRIVATE IP
instead, so your existing connection string works unchanged.

```
App queries: mrb-dev-007-sql.database.windows.net
                          │
         Private DNS Zone intercepts this specific domain
                          │
                          ▼
              Resolves to: 10.0.3.4 (private IP)
                    NOT the public Azure IP
```

### New Terraform Resources

| Resource | Purpose |
|---|---|
| `azurerm_private_endpoint` | Gives SQL Server a private IP inside your VNet |
| `azurerm_private_dns_zone` | Custom DNS zone for `privatelink.database.windows.net` |
| `azurerm_private_dns_zone_virtual_network_link` | Connects that DNS zone to your VNet |

### Reused Without Guidance
`azurerm_resource_group`, `azurerm_virtual_network` + 3 subnets
(web, app, data), `azurerm_service_plan`, `azurerm_linux_web_app`
× 2 (web + app tier, with VNet Integration and delegation from
MRB-006), `azurerm_mssql_server`, `azurerm_mssql_database`,
Key Vault + secrets + data sources for SQL credentials.

---

## 2. Naming + Tags

| Resource | Name |
|---|---|
| Resource Group | `mrb-dev-007-rg` |
| VNet | `mrb-dev-007-vnet` |
| Web / App / Data Subnets | `mrb-dev-007-web-subnet` (10.0.1.0/24), `mrb-dev-007-app-subnet` (10.0.2.0/24), `mrb-dev-007-data-subnet` (10.0.3.0/24) |
| SQL Server | `mrb-dev-007-sql-jd` |
| SQL Database | `mrb-dev-007-app-db` |
| Private Endpoint | `mrb-dev-007-sql-pe` |
| Private DNS Zone | `privatelink.database.windows.net` (fixed name, Azure standard) |

Same 8 MRB tags. `DataClassification = "confidential"` (database
holds application data — higher sensitivity than networking
config from MRB-006).

```hcl
# terraform.tfvars
org_prefix           = "mrb"
environment          = "dev"
azure_location       = "East US"
resource_group_name  = "mrb-dev-007-rg"
key_vault_name       = "mrb-dev-007-kv"
sql_server_name      = "mrb-dev-007-sql-jd"
sql_database_name    = "mrb-dev-007-app-db"
owner_name           = "alex-morgan"
cost_centre          = "CC-CLOUD-001"
data_classification  = "confidential"
compliance_scope     = "internal-audit"
```

---

## 3. Core Components

### Component 1 — Networking: Three Subnets

Build web-subnet and app-subnet exactly as in MRB-006 (with the
`delegation` block for App Service integration). Add a THIRD
subnet for the data tier — this one does NOT need delegation,
but it does need one special setting:

```hcl
resource "azurerm_subnet" "data_subnet" {
  name                 = "mrb-dev-007-data-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.3.0/24"]

  private_endpoint_network_policies_enabled = false
}
```

> `private_endpoint_network_policies_enabled = false` is required
> on any subnet that will host a Private Endpoint. Without this,
> `terraform apply` will reject the Private Endpoint creation
> with a policy conflict error.

### Component 2 — Key Vault + SQL Credentials

Same pattern as NCT-007/MRB-002/003 — RBAC Key Vault, two secrets
(`sql-admin-username`, `sql-admin-password`), data sources with
`depends_on`. Build from memory.

### Component 3 — SQL Server with Public Access DISABLED

```hcl
resource "azurerm_mssql_server" "sql_srv" {
  name                         = "mrb-dev-007-sql-jd"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0"
  administrator_login          = data.azurerm_key_vault_secret.sql_admin_username.value
  administrator_login_password = data.azurerm_key_vault_secret.sql_admin_password.value

  public_network_access_enabled = false   # NEW — no public path exists at all

  tags = local.common_tags
}

resource "azurerm_mssql_database" "app_db" {
  name        = "mrb-dev-007-app-db"
  server_id   = azurerm_mssql_server.sql_srv.id
  sku_name    = "Basic"
  max_size_gb = 2
  tags        = local.common_tags
}
```

> Notice: **no `azurerm_mssql_firewall_rule` resources at all**
> in this project. With `public_network_access_enabled = false`,
> firewall rules become meaningless — there is no public entry
> point for them to filter. This is the actual proof that
> Private Endpoint is a stronger security model than NCT-007's
> approach, not just a different one.

### Component 4 — Private Endpoint

```hcl
resource "azurerm_private_endpoint" "sql_pe" {
  name                = "mrb-dev-007-sql-pe"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.data_subnet.id

  private_service_connection {
    name                           = "mrb-dev-007-sql-connection"
    private_connection_resource_id = azurerm_mssql_server.sql_srv.id
    subresource_names               = ["sqlServer"]
    is_manual_connection             = false
  }

  tags = local.common_tags
}
```

> `subresource_names = ["sqlServer"]` tells Azure specifically
> WHICH capability of the SQL Server to expose through this
> endpoint — SQL Server has only one relevant subresource, but
> other services (like Storage Accounts) have several (blob,
> file, queue, table), so this argument matters more elsewhere.

### Component 5 — Private DNS Zone + VNet Link

```hcl
resource "azurerm_private_dns_zone" "sql_dns" {
  name                = "privatelink.database.windows.net"
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "sql_dns_link" {
  name                  = "mrb-dev-007-dns-link"
  resource_group_name  = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.sql_dns.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}
```

> `privatelink.database.windows.net` is NOT a name you invent —
> it is a fixed, Azure-mandated zone name specifically for SQL
> Private Endpoints. Every Azure service that supports Private
> Endpoints has its own specific `privatelink.*` zone name
> (Storage uses `privatelink.blob.core.windows.net`, Key Vault
> uses `privatelink.vaultcore.azure.net`, etc.) — you must use
> the exact name Azure expects or DNS resolution will silently
> fail.

**One more piece — actually registering the DNS record:**

```hcl
resource "azurerm_private_dns_a_record" "sql_dns_record" {
  name                = "mrb-dev-007-sql-jd"
  zone_name           = azurerm_private_dns_zone.sql_dns.name
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 300
  records              = [azurerm_private_endpoint.sql_pe.private_service_connection[0].private_ip_address]
}
```

> This is the resource that actually writes "this hostname → this
> private IP" into the DNS zone. Without it, the zone and the link
> exist, but nothing is actually resolved through them.

### Component 6 — Web + App Tier (reuse MRB-006 pattern)

Build both App Services with VNet Integration exactly as in
MRB-006. The App Tier's `app_settings` should include the SQL
connection string, built with `format()` using
`azurerm_mssql_server.sql_srv.fully_qualified_domain_name` — same
as always. Because of the Private DNS Zone, this hostname now
resolves privately without any special code changes.

### Component 7 — Variables + Outputs

Outputs:
```
sql_server_fqdn
private_endpoint_ip     ← azurerm_private_endpoint.sql_pe.private_service_connection[0].private_ip_address
web_tier_url
resource_group_name
```

---

## 4. Hints

**Hint 1 — Forgetting `private_endpoint_network_policies_enabled =
false` on the data subnet is the most common failure:** without
it, Azure blocks the Private Endpoint from being created in that
subnet entirely, with an error about network policies conflicting.

**Hint 2 — The DNS zone name must be EXACT:** `privatelink.database.windows.net`
— not `private.database.windows.net`, not
`privatelink.sql.windows.net`. A typo here means DNS resolution
silently fails and your App Tier cannot reach the database, with
no obvious error pointing at the DNS zone as the cause.

**Hint 3 — Three separate pieces are needed for DNS to actually
work, not just the zone:** the Private DNS Zone (the container),
the VNet Link (connects it to your network), AND the A Record
(the actual hostname-to-IP mapping). Missing any one of these
three means the chain is incomplete — the most common oversight
is forgetting the A Record, since the zone and link alone "look"
complete in a `terraform plan`.

---

## 5. Workflow (PowerShell)

```powershell
cd C:\Projects\mrb-infra-007
terraform init; terraform validate; terraform fmt; terraform plan
terraform apply    # type: yes — this is your longest apply yet, 5-8 minutes

terraform output private_endpoint_ip
# Should print something like 10.0.3.4

terraform output sql_server_fqdn

# Verify SQL has no public access
az sql server show `
  --name mrb-dev-007-sql-jd `
  --resource-group mrb-dev-007-rg `
  --query "publicNetworkAccess" `
  --output tsv
# Expected: Disabled

# Verify the private endpoint exists and is approved
az network private-endpoint show `
  --name mrb-dev-007-sql-pe `
  --resource-group mrb-dev-007-rg `
  --query "privateLinkServiceConnections[0].privateLinkServiceConnectionState.status" `
  --output tsv
# Expected: Approved

# Verify DNS record exists
az network private-dns record-set a list `
  --zone-name privatelink.database.windows.net `
  --resource-group mrb-dev-007-rg `
  --output table

terraform destroy    # type: yes
az keyvault purge --name mrb-dev-007-kv --location "East US"
```

---

## 6. Checklist

```
[ ] Data subnet has private_endpoint_network_policies_enabled = false
[ ] SQL Server has public_network_access_enabled = false
[ ] NO azurerm_mssql_firewall_rule resources present (not needed anymore)
[ ] Private Endpoint subresource_names = ["sqlServer"]
[ ] DNS zone name is EXACTLY "privatelink.database.windows.net"
[ ] VNet link connects the DNS zone to your VNet
[ ] A record present, pointing to the private endpoint's IP
[ ] Web + App tiers reuse MRB-006's VNet Integration pattern correctly
[ ] Azure CLI confirms publicNetworkAccess = Disabled
[ ] Azure CLI confirms private endpoint connection status = Approved
[ ] terraform destroy + Key Vault purge completed
```

---

## 7. Cost
SQL Basic (~$5/month if left running — destroy same session) +
Private Endpoint (~$0.01/hr) + B1 App Service Plan (from MRB-006
pattern, ~$0.018/hr). **A 3-4 hour lab session: comfortably under
$1.** Well inside your monthly budget even run multiple times.

## Series Status
```
MRB-001 to 005   ✅  Foundations
MRB-006          ✅  Multi-Tier Part 1 — Web + App Tier
MRB-007          ✅  Multi-Tier Part 2 — Data Tier via Private Endpoint  ← THIS PROJECT
MRB-008          📋  Azure Policy — enforce compliance automatically
MRB-009          📋  Application Gateway ⚠️ (cost exception)
MRB-010          📋  Full Capstone
```

*Meridian Bank — Cloud Platform Engineering | CONFIDENTIAL*
