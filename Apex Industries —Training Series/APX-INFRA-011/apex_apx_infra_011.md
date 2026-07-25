# Apex Industries — Cloud Infrastructure Training Series
## Azure Files + NAT Gateway
**Project Code:** `APX-INFRA-011` | **Level:** Beginner+++ | **Frequency:** Used everywhere
**Environment:** Windows + VS Code + PowerShell | Fully self-contained | Cost: ~$0.10/session

---

> **From your Team Lead:** Two genuinely common, unrelated needs
> in this ticket. First: a shared file drive that multiple VMs can
> mount — every org has one of these somewhere, usually older than
> anyone currently working there. Second: controlling exactly how
> your VMs reach the internet, instead of each one getting its own
> unpredictable public IP for outbound traffic. — *Morgan Chen*

---

## 1. Overview — Two New Concepts, Genuinely Unrelated

### Concept 1 — Azure Files (Shared SMB File Storage)

Every storage account you've built stored BLOBS — individual
files accessed by URL, one at a time (NCT-001, APX-003). Azure
Files is different: it's a proper network FILE SHARE, using the
same SMB protocol as a Windows shared drive. Multiple VMs can
mount it simultaneously and read/write files like a normal
folder — not through API calls, through the actual filesystem.

```
Blob Storage (what you've built before):
  App code calls an API -> gets one file back -> done

Azure Files (this project):
  VM runs "mount //server/share /mnt/shared"
  -> the share now behaves like a local folder
  -> cp, ls, cat all work normally, no API calls needed
```

### Concept 2 — NAT Gateway (Controlled Outbound Internet)

Every VM you've built so far either had its own Public IP (for
inbound AND outbound), or no public path at all (fully private,
like MRB-006 onward). NAT Gateway is a third option: VMs with NO
individual public IP, but ALL of them share ONE predictable public
IP for OUTBOUND traffic only.

```
Without NAT Gateway:
  Each VM needing internet access needs its own Public IP
  -> expensive at scale, unpredictable source IPs

With NAT Gateway:
  VMs have NO public IP individually
  -> all outbound traffic exits through ONE shared, predictable IP
  -> useful for allow-listing your traffic on a partner's firewall,
    since they only need to whitelist ONE IP, not every VM's IP
```

### What You Are Building

```
Storage Account (apx-dev-011-sa)
  Azure Files Share: "shared-data"
    Mounted by a VM in the subnet below

VNet + Subnet
  NAT Gateway attached to the subnet
    -> all VMs in this subnet share ONE outbound public IP
  VM: apx-dev-011-vm -- NO individual public IP,
      mounts the Azure Files share, and proves outbound
      internet access still works via the shared NAT IP
```

### Reused Without Guidance
`azurerm_resource_group`, `azurerm_virtual_network` + `azurerm_subnet`,
`azurerm_network_security_group`, `azurerm_network_interface`,
`azurerm_linux_virtual_machine`, `azurerm_storage_account` — you
know all of these. This VM has NO public IP resource at all —
build everything except that.

---

## 2. Naming + Tags

| Resource | Name |
|---|---|
| Resource Group | `apx-dev-011-rg` |
| Storage Account | `apxdev011sajd` |
| Azure Files Share | `shared-data` |
| NAT Gateway | `apx-dev-011-natgw` |
| NAT Gateway Public IP | `apx-dev-011-natgw-pip` |
| VM | `apx-dev-011-vm` |

```hcl
# terraform.tfvars
org_prefix           = "apx"
environment          = "dev"
azure_location       = "East US"
resource_group_name  = "apx-dev-011-rg"
storage_account_name  = "apxdev011sajd"
vm_size                  = "Standard_B1s"
admin_username             = "apxadmin"
owner_name                    = "sam-rivera"
```

> **No `allowed_ssh_ip` this time** — since the VM has no public
> IP, you cannot SSH into it directly from your laptop. See
> Hint 1 for how you'll actually access it.

---

## 3. Core Components

### Component 1 — Networking (Build From Memory, With One Change)

Standard VNet + subnet + NSG. **Do NOT create a Public IP or
attach one to the NIC** — that's the entire point of this project.
The VM's NIC has only a private IP.

### Component 2 — Storage Account + Azure Files Share

```hcl
resource "azurerm_storage_account" "sa" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.rg.name
  location                    = azurerm_resource_group.rg.location
  account_tier                   = "Standard"
  account_replication_type          = "LRS"
  tags                                 = local.common_tags
}

resource "azurerm_storage_share" "shared_data" {
  name                 = "shared-data"
  storage_account_name  = azurerm_storage_account.sa.name
  quota                    = 5
}
```

**`quota = 5`** — Azure Files bills per GB provisioned (standard
tier), so keeping this small keeps cost negligible. This is the
micro-SKU equivalent for file shares — smallest reasonable
allocation for a lab.

### Component 3 — NAT Gateway

```hcl
resource "azurerm_public_ip" "natgw_pip" {
  name                = "${local.name_prefix}-natgw-pip"
  location             = azurerm_resource_group.rg.location
  resource_group_name  = azurerm_resource_group.rg.name
  allocation_method     = "Static"
  sku                     = "Standard"
  tags                     = local.common_tags
}

resource "azurerm_nat_gateway" "natgw" {
  name                    = "${local.name_prefix}-natgw"
  location                 = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  sku_name                      = "Standard"
  tags                             = local.common_tags
}

resource "azurerm_nat_gateway_public_ip_association" "natgw_pip_assoc" {
  nat_gateway_id       = azurerm_nat_gateway.natgw.id
  public_ip_address_id  = azurerm_public_ip.natgw_pip.id
}

resource "azurerm_subnet_nat_gateway_association" "natgw_subnet_assoc" {
  subnet_id       = azurerm_subnet.subnet.id
  nat_gateway_id    = azurerm_nat_gateway.natgw.id
}
```

**Every piece explained:**

```
azurerm_nat_gateway              -> the NAT service itself
azurerm_public_ip                -> the ONE shared outbound IP
azurerm_nat_gateway_public_ip_association
                                   -> connects the IP to the gateway
azurerm_subnet_nat_gateway_association
                                   -> connects the gateway to the
                                     subnet -- THIS is what actually
                                     makes every VM in that subnet
                                     use it for outbound traffic
```

> Four resources, each doing one small job — a similar pattern to
> Load Balancer's multiple small pieces (pool, probe, rule) back
> in MRB-004/APX-006. The `subnet_nat_gateway_association` is the
> one most likely to be forgotten — without it, the NAT Gateway
> exists but nothing actually routes through it.

### Component 4 — VM With No Public IP, Mounting the File Share

```hcl
resource "azurerm_network_interface" "nic" {
  name                = "${local.name_prefix}-nic"
  location             = azurerm_resource_group.rg.location
  resource_group_name  = azurerm_resource_group.rg.name

  ip_configuration {
    name                             = "internal"
    subnet_id                          = azurerm_subnet.subnet.id
    private_ip_address_allocation        = "Dynamic"
  }
  tags = local.common_tags
}
```

**Mount the Azure Files share via `custom_data`:**

```hcl
resource "azurerm_linux_virtual_machine" "vm" {
  # ... standard config, no public IP ...

  custom_data = base64encode(templatefile("${path.module}/mount-share.tpl", {
    storage_account_name = azurerm_storage_account.sa.name
    storage_account_key    = azurerm_storage_account.sa.primary_access_key
    share_name                = azurerm_storage_share.shared_data.name
  }))
}
```

**`mount-share.tpl`:**
```bash
#!/bin/bash
apt-get update
apt-get install -y cifs-utils

mkdir -p /mnt/shared-data

mount -t cifs //${storage_account_name}.file.core.windows.net/${share_name} /mnt/shared-data \
  -o username=${storage_account_name},password=${storage_account_key},serverino,nosharesock

echo "Hello from VM via shared file storage" > /mnt/shared-data/test-file.txt
```

> Notice `templatefile()` being used with REAL variable
> substitution this time — unlike APX-005's empty `{}` map, this
> passes the storage account name, key, and share name directly
> into the script. This is the full power of `templatefile()` you
> were told about but didn't use back in APX-005 — worth revisiting
> now that there's a real use case for it.

---

## 4. Hints

**Hint 1 — With no public IP, how do you actually check the VM
worked?** Two options: (a) use Azure's Run Command feature via
CLI, which executes commands on the VM without needing SSH access
at all, or (b) temporarily add a Bastion host or jump box (a
future series concept) for interactive access. This project uses
option (a) — see the workflow below.

**Hint 2 — Storage account keys in `custom_data` are visible in
Terraform state, same caveat as MRB-004's Hint 2:** this is
acceptable for a learning lab. In production, this mount script
would instead use Managed Identity to authenticate to the storage
account — a natural combination of this project's lesson with
MRB-002/003's Managed Identity pattern, worth connecting mentally
even though this lab keeps it simple with a key for clarity.

**Hint 3 — Forgetting `azurerm_subnet_nat_gateway_association` is
the most common mistake:** the NAT Gateway, its IP, and their
association to EACH OTHER can all apply successfully while the
subnet itself still isn't using it. Always verify via CLI that
the subnet shows a NAT Gateway attached, not just that the NAT
Gateway resource exists.

---

## 5. Workflow (PowerShell)

```powershell
cd C:\Projects\apx-infra-011

terraform init; terraform validate; terraform fmt
terraform plan -out=tfplan
terraform apply tfplan

# Verify NAT Gateway is actually attached to the subnet
az network vnet subnet show `
  --resource-group apx-dev-011-rg `
  --vnet-name apx-dev-011-vnet `
  --name apx-dev-011-subnet `
  --query natGateway --output table

# Run a command ON the VM without SSH, using Azure's Run Command feature
az vm run-command invoke `
  --resource-group apx-dev-011-rg `
  --name apx-dev-011-vm `
  --command-id RunShellScript `
  --scripts "cat /mnt/shared-data/test-file.txt"
# Expected output: "Hello from VM via shared file storage" --
# proof the Azure Files mount actually worked

# Prove outbound internet access works via the shared NAT IP
az vm run-command invoke `
  --resource-group apx-dev-011-rg `
  --name apx-dev-011-vm `
  --command-id RunShellScript `
  --scripts "curl -s https://api.ipify.org"
# Compare this returned IP to your NAT Gateway's public IP --
# they should match exactly
terraform output natgw_public_ip

terraform destroy
```

**What you should see:** the VM's outbound IP (from `curl
api.ipify.org`, run with zero SSH access, zero individual public
IP on the VM) matches your NAT Gateway's IP exactly — proof that
outbound traffic really is being routed through the shared
gateway, not some other unpredictable path.

---

## 6. Checklist

```
[ ] VM's NIC has NO public_ip_address_id -- private only
[ ] Storage Share quota kept small (5 GB)
[ ] All four NAT Gateway pieces present: gateway, IP, IP association,
    subnet association
[ ] custom_data uses templatefile() with REAL variable substitution
[ ] Run Command used to verify the VM (no SSH needed/possible)
[ ] File share mount confirmed via the test file content
[ ] Outbound IP confirmed to match the NAT Gateway's IP exactly
[ ] terraform destroy completed
```

---

## 7. Cost
NAT Gateway (~$0.045/hr) + Standard Public IP (~$0.005/hr) +
Standard_B1s VM (~$0.013/hr) + 5GB File Share (~$0.024/month,
negligible for a session). **A 2-3 hour lab session: ~$0.20.**

## Series Status
```
APX-010   Backup & Disaster Recovery
APX-011   Azure Files + NAT Gateway                        <- THIS PROJECT
APX-012   VMSS Autoscale
```

*Apex Industries — Cloud Platform Engineering | Training Series*
