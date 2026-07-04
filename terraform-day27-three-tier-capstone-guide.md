# Terraform Capstone — End-to-End Azure Three-Tier Architecture
## Deep-Dive Learning Guide — Day 27 / 28 Days of Easy Terraform
### Capstone Project | Beginner-First Edition | PowerShell Throughout

---

## Before You Start

This is Day 27 — the largest single project in the series: a complete
three-tier web application infrastructure (Application Gateway + WAF,
two Virtual Machine Scale Sets running containers, an internal load
balancer, a Postgres Flexible Server with a read replica, Key Vault,
private DNS, a NAT Gateway, and a Bastion host), all provisioned
through custom Terraform modules.

Given how much ground this covers, I want to flag several places
where the source video's narration is either imprecise or describes
something slightly different from what actually happens on Azure —
not to nitpick, but because a few of these affect what you'd actually
get if you built this expecting the narrated behavior. The most
significant one: the video describes the Postgres read replica as
providing automatic failover ("whenever primary goes down, request
will be redirected to the reader replica... it will then become the
master"). **Azure Database for PostgreSQL Flexible Server read
replicas do not fail over automatically** — promoting a replica to
primary is a deliberate, manual operation. If you're relying on this
architecture for actual high availability, that distinction matters a
great deal, and Section 5 covers what would be needed for genuine
automatic failover.

---

## Table of Contents

1. What This Capstone Project Actually Is
2. The Three-Tier Architecture, Layer by Layer
3. A Precise Correction: Azure's Outbound Internet Model
4. Containers on VMSS — What This Pattern Actually Is
5. A Necessary Correction: Postgres Read Replicas Are Not Automatic Failover
6. Network Security Groups Per Tier
7. Using Azure Service Tags Instead of Raw Address Prefixes
8. The Bastion Host Pattern
9. Project Structure and the Root Module
10. Custom Modules — What "Cannot Be Overridden" Actually Means
11. The `count` + `length()` Subnet Pattern
12. Random Suffix for Global Uniqueness
13. Module Dependency Chains — Why Key Vault Waits on Database
14. Setting Up the Service Principal — PowerShell and Permission Reality
15. Setting Up the Remote Backend — PowerShell
16. Passing Secrets Safely — Command Line vs Environment Variables
17. Running the Deployment
18. The Cost Reality
19. Tearing Down Correctly — And What Went Wrong in the Video
20. The Environment Folder Pattern
21. Ways to Elevate This Project Further
22. Common Mistakes
23. Practice Exercises
24. Summary Reference

---

## 1. What This Capstone Project Actually Is

A three-tier web application — a to-do/goal-tracker app with a Node.js
frontend, a Go backend, and a Postgres database — deployed onto Azure
infrastructure that mirrors what a real production environment would
look like: public-facing load-balanced compute in public subnets,
business logic isolated in private subnets, and a database tier
reachable only from within the virtual network. Everything is built
through custom Terraform modules (Day 20), demonstrating the modular,
production-oriented approach rather than one large flat configuration.

---

## 2. The Three-Tier Architecture, Layer by Layer

**Presentation tier (public subnets, x2 for availability zones)** —
the Node.js frontend, running as a Docker container on VM instances
inside a Virtual Machine Scale Set (VMSS). Reached through Azure
Application Gateway, which sits behind a Web Application Firewall
(WAF) policy and has its own public IP.

**Application tier (private subnets, x2)** — the Go backend, also
running as a Docker container on its own VMSS, reached only through an
internal (private) Load Balancer — never directly from the internet.

**Data tier (private subnets, x2)** — a Postgres Flexible Server
primary instance plus a read replica, reachable only from within the
virtual network.

**Why separate subnets per tier at all:** this is the core three-tier
principle — each tier gets its own Network Security Group rules,
because a public-facing web server and a database server should never
have equivalent network exposure. Section 6 covers the actual rules
this project applies per tier.

---

## 3. A Precise Correction: Azure's Outbound Internet Model

The video frames NAT Gateway as an alternative to "the internet
gateway," implying Azure has a separate resource called an internet
gateway the way AWS does. Worth correcting directly, especially for
anyone coming from an AWS background: **Azure has no separate
"Internet Gateway" resource.** Historically, VMs without a public IP
still had implicit, automatic outbound internet access by default —
but Microsoft has been progressively retiring that default outbound
access for new deployments (a deprecation Microsoft announced with a
firm cutoff date for new subscriptions/deployments), specifically
*because* silent, unmanaged default outbound access is a security and
auditability weakness.

**Azure NAT Gateway is the explicit, deliberate replacement for that
implicit default** — not a contrast against a distinct AWS-style
Internet Gateway object. Functionally, once attached to a subnet, NAT
Gateway provides the same practical outcome the video describes
(private-subnet VMs can reach the internet outbound for package
updates and image pulls, without a public IP directly on the VM, and
without inbound reachability from the internet) — the correction is
purely about what Azure's actual resource model looks like versus how
the video frames it by analogy to AWS.

---

## 4. Containers on VMSS — What This Pattern Actually Is

Worth being precise about the architecture here, since "containers
running" can sound like a managed container platform (AKS, Container
Apps, Container Instances) when it's actually something more manual:
in this project, each VM inside the VMSS runs a **custom script
extension** on boot that installs Docker directly onto the VM's
operating system, then runs the application container with a plain
`docker run` command. There is no container orchestrator here — no
scheduling, no container-level self-healing, no rolling deployment
mechanism beyond what VMSS itself provides at the *VM* level.

This is a legitimate, simpler-to-reason-about pattern, and it's worth
understanding exactly what it gives you versus AKS (Day 20):

- If a **VM** becomes unhealthy, VMSS's health-probe-based instance
  repair replaces it, and the boot script reruns on the new instance —
  which does effectively restart the container, just via a full VM
  replacement rather than a lightweight container restart
- If the **container process itself** crashes but the VM stays
  healthy, nothing in this setup automatically restarts just the
  container unless the boot script or a supervisor process (systemd,
  a restart policy on the `docker run` command) is explicitly
  configured to do so
- There's no built-in rolling update mechanism for deploying a new
  container image version — that would need to be added as a separate
  deployment step (re-running the script, or replacing the VMSS
  instances) rather than something Terraform or VMSS does automatically

---

## 5. A Necessary Correction: Postgres Read Replicas Are Not Automatic Failover

This is the most consequential correction in this guide, because it
changes the actual resilience guarantee of the architecture as
described. **Azure Database for PostgreSQL Flexible Server's read
replica feature is explicitly a manual-promotion mechanism**, not an
automatic-failover cluster. If the primary server fails, the
application does **not** automatically start talking to the replica —
someone (or some automation you'd have to build separately) has to
deliberately run a promotion operation:

```powershell
az postgres flexible-server replica promote `
  --name "<replica-server-name>" `
  --resource-group "<resource-group-name>"
```

Promotion also **breaks replication permanently** for that replica —
once promoted, it becomes an independent primary and no longer
receives updates from the original server. This is fundamentally
different from what the video's narration implies ("it will then
become the master" as if automatically).

**What Azure actually offers for automatic high availability** on
Postgres Flexible Server is a separate, distinct feature: **Zone
Redundant High Availability**, which maintains a synchronously
replicated standby and *does* fail over automatically:

```hcl
resource "azurerm_postgresql_flexible_server" "primary" {
  # ... other configuration ...

  high_availability {
    mode = "ZoneRedundant"
  }
}
```

If genuine automatic database failover is a goal for this
architecture, `high_availability { mode = "ZoneRedundant" }` is the
correct feature to add — the read replica configuration this project
builds serves a different purpose (offloading read traffic, or
providing a disaster-recovery target you promote manually), not
automatic failover.

---

## 6. Network Security Groups Per Tier

The actual rule set the project applies, tier by tier:

**Public subnet (frontend) NSG** — inbound HTTP (80) and HTTPS (443)
from the internet (so users can reach the app through Application
Gateway); inbound SSH (22) restricted to the Bastion subnet's address
range only, never from the internet directly; a node-port-style rule
for the container's actual application port.

**Private subnet (backend) NSG** — inbound only from within the
virtual network itself (covering the Bastion host, the internal load
balancer, and Application Gateway's own subnet) on the application
port (8080) — never open to the public internet at all.

**Database subnet NSG** — inbound only from the virtual network on
the Postgres port (5432); outbound restricted to the virtual network
plus a specific allowance for reaching Azure's own management/cloud
endpoints (Section 7 covers the correct way to express that last rule).

**Bastion subnet NSG** — inbound HTTPS (443) from the internet
(Bastion itself needs a public-facing HTTPS endpoint to serve its
browser-based session) and from Azure's Gateway Manager service tag;
inbound from the virtual network on the ports Bastion needs to relay
SSH/RDP sessions.

The consistent principle across every tier: **only the traffic a tier
genuinely needs is allowed, and the source is always scoped as
narrowly as the actual requirement** — public subnets accept public
traffic because that's their job; nothing else does.

---

## 7. Using Azure Service Tags Instead of Raw Address Prefixes

The video's narration mentions an outbound rule "to Azure cloud" for
the database tier's egress, without being precise about the actual
Terraform syntax. Worth stating the correct, current approach: Azure
provides **service tags** — named, Microsoft-maintained groups of IP
ranges for its own services — specifically so you don't have to
hardcode and maintain IP ranges yourself:

```hcl
resource "azurerm_network_security_rule" "db_outbound_azure" {
  name                        = "allow-outbound-azurecloud"
  priority                    = 200
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "AzureCloud"   # service tag, not a literal IP range
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.db.name
}
```

`"AzureCloud"` (and its region-specific variants like
`"AzureCloud.EastUS"`) is a service tag Azure keeps updated
automatically as its own infrastructure IP ranges change — using it
instead of a literal CIDR block means your NSG rule doesn't silently
break the next time Microsoft reassigns address space.

---

## 8. The Bastion Host Pattern

Already covered in depth in **Day 15**, and reused identically here:
the principle is that no one should SSH directly into a production
application server. Instead, administrators connect to a Bastion host
first (a "jump box"), and from there, connect onward to the actual
target server. Azure Bastion (the managed service version, rather than
a self-managed jump VM) removes the need to expose SSH publicly on any
application server at all — Day 15's guide covers the
`azurerm_bastion_host` resource and its subnet-naming requirement in
full.

---

## 9. Project Structure and the Root Module

```
day27/
  infra/
    main.tf              (root module: resource group, locals, module calls)
    variables.tf          (all input variable declarations + defaults)
    outputs.tf             (values printed after apply)
    providers.tf            (azurerm + random provider configuration)
    modules/
      networking/
      keyvault/
      database/
      dns/
      compute-frontend/
      compute-backend/
    environments/
      prod/
        terraform.tfvars
        backend.tf
  backend/
  frontend/
  docker-compose.yml       (for local testing, not part of the Azure deployment)
```

Connecting directly to **Day 20**'s terminology: `infra/` (containing
`main.tf`) is the **root module** — every Terraform project has
exactly one, whether or not it calls any child modules. Each folder
under `modules/` is a **child module**; `main.tf` at the root is the
**calling module**, since it contains the `module { }` blocks
invoking each of them.

---

## 10. Custom Modules — What "Cannot Be Overridden" Actually Means

The video describes modules as a way to specify things a team member
"cannot override." Worth being precise about the actual mechanism
rather than treating it as a special locking feature: **a Terraform
module has no explicit lock or permission system** — the encapsulation
comes entirely from ordinary variable scoping. Whatever a module's
`main.tf` hardcodes directly (rather than exposing through a declared
`variable` block) simply has no way to be set by whoever calls that
module, because there's no input path for it. If the `networking`
module hardcodes `account_replication_type = "LRS"` on some internal
resource rather than exposing it as a variable, nobody calling that
module can change it — not because Terraform is enforcing a rule, but
because there's genuinely no mechanism to reach in and override an
un-exposed value. This is standard function/module encapsulation, the
same concept as a function parameter list in any programming
language — nothing Azure- or Terraform-specific beyond that.

---

## 11. The `count` + `length()` Subnet Pattern

Directly reusing **Day 8**'s pattern to create exactly as many subnets
as there are entries in a list variable:

```hcl
variable "public_subnet_prefixes" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

resource "azurerm_subnet" "public" {
  count                = length(var.public_subnet_prefixes)
  name                 = "public-subnet-${count.index}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.public_subnet_prefixes[count.index]]
}
```

`length(var.public_subnet_prefixes)` evaluates to `2`, so `count = 2`
creates exactly two subnet resources, each pulling its own address
prefix from the corresponding position in the list via
`count.index`. Adding a third availability zone later means adding one
more entry to the list — no changes to the resource block itself.

---

## 12. Random Suffix for Global Uniqueness

```hcl
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

locals {
  resource_name_prefix = "${var.environment}-${random_string.suffix.result}"
}
```

This directly reuses the pattern first introduced conceptually in
**Day 3** and **Day 18** around globally unique Azure resource naming
(Storage Accounts, SQL Servers) — rather than manually retyping a
unique suffix by hand each time (which is exactly what caused Day 18's
and Day 22's naming-collision debugging sessions), generating one
random, lowercase, alphanumeric suffix once and reusing it consistently
across every resource name in this project avoids that entire class of problem.

---

## 13. Module Dependency Chains — Why Key Vault Waits on Database

```hcl
module "keyvault" {
  source = "./modules/keyvault"
  # ...
  depends_on = [module.database]
}
```

This is an **explicit** dependency (Day 3's terminology), added
deliberately here because the actual *data flow* dependency — Key
Vault storing the database's generated hostname and credentials as
secrets — already exists implicitly through references like
`module.database.server_fqdn`. The explicit `depends_on` on the whole
module is a belt-and-suspenders addition in case any specific secret
value doesn't have a direct attribute reference forcing the ordering
on its own. Worth noting as a reasonable defensive choice rather than
a strict necessity, consistent with Day 20's similar
`depends_on [module.service_principal]` pattern.

---

## 14. Setting Up the Service Principal — PowerShell and Permission Reality

```powershell
az login

az ad sp create-for-rbac `
  --name "day27-terraform-sp" `
  --role "Contributor" `
  --scopes "/subscriptions/<your-subscription-id>"
```

The video adds only Contributor initially, with an explicit "let's see
if we get an error" — and does hit exactly the kind of permission gap
Day 20's guide already covered in depth (Contributor alone doesn't
grant Key Vault administration or Azure AD object creation
rights). Rather than repeat that same trial-and-error here, the
direct answer: for this specific project, you also need **Key Vault
Administrator** (to create secrets), scoped to the resource group
this project provisions into rather than the whole subscription, per
Day 20's least-privilege guidance:

```powershell
$spObjectId = az ad sp show --id "<app-id-from-above>" --query "id" -o tsv

az role assignment create `
  --assignee $spObjectId `
  --role "Key Vault Administrator" `
  --scope "/subscriptions/<sub-id>/resourceGroups/<this-project-rg>"
```

**Setting environment variables for Terraform's authentication:**
```powershell
$env:ARM_CLIENT_ID       = "<app-id>"
$env:ARM_CLIENT_SECRET   = "<password>"
$env:ARM_TENANT_ID       = "<tenant>"
$env:ARM_SUBSCRIPTION_ID = "<subscription-id>"

az login --service-principal `
  -u $env:ARM_CLIENT_ID `
  -p $env:ARM_CLIENT_SECRET `
  --tenant $env:ARM_TENANT_ID
```

---

## 15. Setting Up the Remote Backend — PowerShell

```powershell
$suffix = -join ((97..122) | Get-Random -Count 6 | ForEach-Object {[char]$_})

az group create --name "tfstate-rg" --location "eastus"

az storage account create `
  --name "tfstate$suffix" `
  --resource-group "tfstate-rg" `
  --location "eastus" `
  --sku Standard_LRS

az storage container create `
  --name "tfstate" `
  --account-name "tfstate$suffix" `
  --auth-mode login

terraform init `
  -backend-config="resource_group_name=tfstate-rg" `
  -backend-config="storage_account_name=tfstate$suffix" `
  -backend-config="container_name=tfstate" `
  -backend-config="key=prod.terraform.tfstate"
```

This connects directly to **Day 4**'s remote-backend lesson — a
separate, dedicated resource group and storage account for state,
never mixed with the actual application infrastructure it's tracking,
for exactly the isolation reasons Day 4 covered in depth.

---

## 16. Passing Secrets Safely — Command Line vs Environment Variables

The video passes the Docker Hub personal access token directly as a
`-var` command-line argument during `terraform apply`. Worth flagging
precisely why environment variables are the meaningfully better
choice here, connecting to **Day 5**'s `TF_VAR_` pattern: a value
passed with `-var="docker_password=..."` on the command line is
recorded in your shell's history file and is briefly visible to
anything else on the machine that can inspect running process
arguments while the command executes. A `TF_VAR_` environment variable
avoids both of those specific exposure paths.

```powershell
$env:TF_VAR_docker_password = "<your-pat-token>"
terraform apply -var-file="environments/prod/terraform.tfvars"
```

Worth being precise about the limit of this improvement, though,
consistent with every prior day's `sensitive` caveat (Day 4, Day 12,
Day 20, Day 22, Day 25): **neither approach protects the value once
Terraform writes it into the state file** — the Docker Hub token ends
up in plaintext in `terraform.tfstate` regardless of which input
method delivered it. The environment-variable improvement is real but
narrow (shell history and process listing exposure), not a substitute
for securing the state backend itself.

---

## 17. Running the Deployment

```powershell
Set-Location "C:\projects\day27\infra"

terraform init `
  -backend-config="resource_group_name=tfstate-rg" `
  -backend-config="storage_account_name=tfstate$suffix" `
  -backend-config="container_name=tfstate" `
  -backend-config="key=prod.terraform.tfstate"

terraform validate

$env:TF_VAR_docker_username = "<your-dockerhub-username>"
$env:TF_VAR_docker_password = "<your-dockerhub-pat>"

terraform plan -var-file="environments/prod/terraform.tfvars"
terraform apply -var-file="environments/prod/terraform.tfvars" --auto-approve
```

Expect roughly 60+ resources and a genuinely long apply time — the
video reports "63 to add" and around 15 minutes, with the Postgres
Flexible Server and the VMSS instances being the slowest individual
resources to provision.

```powershell
terraform output frontend_url
Start-Process (terraform output -raw frontend_url)
```

Give the application a few minutes after the infrastructure finishes
provisioning before testing it — the custom script extensions
installing Docker and pulling/starting containers run *after*
Terraform reports the VMSS itself as created, so there's a real gap
between "Terraform says done" and "the application is actually ready
to serve traffic," exactly as the video experiences when the first
attempt to add a goal fails silently.

---

## 18. The Cost Reality

The video reports a genuine $157 spend for building, debugging, and
running this project over roughly three days, with a rough breakdown
worth internalizing before you build this yourself:

- Postgres Flexible Server (multi-AZ configuration with a read
  replica): approximately $96 — by far the largest single cost driver
- Application Gateway: approximately $35
- Virtual machines (the VMSS instances): approximately $10
- The remaining balance spread across NAT Gateway, Bastion, Key Vault,
  storage, and networking

The practical takeaway, stated plainly: **this is not a "spin it up
for an afternoon and forget about it" project.** Budget for it
explicitly, and treat the destroy step (Section 19) as mandatory
immediately after you're done testing, not as an optional cleanup
step for later.

---

## 19. Tearing Down Correctly — And What Went Wrong in the Video

```powershell
terraform destroy -var-file="environments/prod/terraform.tfvars" --auto-approve
```

The video hits a real, instructive failure here: the Service
Principal it had been using was apparently deleted (accidentally,
during unrelated testing) *before* running `terraform destroy` —
leaving Terraform unable to authenticate to actually perform the
destroy. The video's response was to manually delete the resource
group directly from the Azure Portal instead, explicitly acknowledging
on camera that this is not the correct approach for anything beyond a
throwaway test environment.

Worth being precise about exactly *why* that's a problem, connecting
directly to **Day 24**'s state-desynchronization lesson from the
opposite direction: Day 24 covered `terraform state rm` leaving
Terraform's bookkeeping unaware of resources that still genuinely
exist. This is the mirror-image failure — resources are deleted
*outside* Terraform's knowledge while the state file still confidently
records them as existing and managed. The state file is left
permanently inaccurate for that workspace: a future `terraform plan`
against that same state would either error trying to refresh
resources that no longer exist, or — depending on the specific
resource type and provider version — attempt to recreate everything
from scratch, with all the same collision and duplication risks Day 24
already covered.

**The correct recovery path, had the Service Principal genuinely been
lost:**
```powershell
# Create a replacement Service Principal with equivalent permissions
az ad sp create-for-rbac --name "day27-recovery-sp" --role "Contributor" --scopes "/subscriptions/<sub-id>"

# Then run terraform destroy normally with the NEW credentials
$env:ARM_CLIENT_ID = "<new-app-id>"
$env:ARM_CLIENT_SECRET = "<new-password>"
# ... ARM_TENANT_ID, ARM_SUBSCRIPTION_ID unchanged
terraform destroy -var-file="environments/prod/terraform.tfvars" --auto-approve
```

Creating a fresh Service Principal with equivalent permissions and
running a genuine `terraform destroy` (rather than a manual Portal
deletion) keeps the state file and reality in agreement throughout —
the actual root problem here was a lost credential, not something
requiring abandoning Terraform's own teardown process.

---

## 20. The Environment Folder Pattern

```
environments/
  prod/
    terraform.tfvars
    backend.tf
  test/
    terraform.tfvars
    backend.tf
  dev/
    terraform.tfvars
    backend.tf
```

The video builds only `prod/` in the demo but explicitly describes
this as the pattern to extend. The reasoning is worth restating
plainly: production infrastructure should never share a state file,
backend storage account, or (ideally) the exact same credentials as
dev/test infrastructure — precisely Day 4's environment-isolation
principle, applied here at the folder-organization level rather than
just the backend-configuration level. Each environment folder gets
its own `terraform.tfvars` (different resource sizes, different
region choices, different scaling parameters) and its own
`backend.tf` pointing at a dedicated state file — never a shared one.

---

## 21. Ways to Elevate This Project Further

Directly from the video's own suggestions, organized concretely:

- **Azure Container Registry** instead of public Docker Hub images —
  gives you private image storage, vulnerability scanning, and
  control over image provenance, all things a public registry doesn't
  provide
- **Zone Redundant High Availability** on the Postgres server
  (Section 5) if genuine automatic database failover is actually a
  requirement, rather than relying on the read replica's manual-promotion behavior
- **CI/CD pipeline** wiring (Day 26) so infrastructure and application
  code changes both flow through automated pipelines rather than
  manual `terraform apply` runs
- **Multiple environment folders** actually built out (Section 20),
  not just described
- **Azure Monitor alerts** (Day 23) on the VMSS instances and the
  Postgres server, so infrastructure health issues surface
  proactively rather than being discovered by a user reporting a
  broken "add goal" button

---

## 22. Common Mistakes

**Mistake 1 — Assuming the Postgres read replica provides automatic
failover.** Section 5 — it requires a manual promotion command;
`high_availability { mode = "ZoneRedundant" }` is the feature for
genuine automatic failover.

**Mistake 2 — Deleting resources manually from the Portal instead of
running `terraform destroy`.** Section 19 — this permanently
desynchronizes the state file from reality, mirroring Day 24's
opposite-direction lesson.

**Mistake 3 — Passing secrets via `-var` on the command line instead
of `TF_VAR_` environment variables.** Section 16 — a real, if narrow,
exposure-surface reduction, though neither protects the state file itself.

**Mistake 4 — Assuming Contributor alone is sufficient for a service
principal that also needs to manage Key Vault.** Section 14 — Key
Vault Administrator (scoped to the relevant resource group) is
additionally required.

**Mistake 5 — Testing the application immediately after `terraform
apply` reports success.** Section 17 — custom script extensions
installing Docker and starting containers run after Terraform
considers the VMSS "created," so there's a real propagation delay
before the application is actually reachable.

**Mistake 6 — Treating "containers running on VMSS" as equivalent to a
managed container orchestration platform.** Section 4 — no scheduler,
no container-level self-healing beyond what the boot script and VMSS
instance repair provide at the VM level.

---

## 23. Practice Exercises

**Exercise 1** — A teammate wants automatic database failover for this
architecture and proposes relying on the existing read replica
configuration. Explain why that won't achieve their goal, and name
the correct feature to add instead.

*Answer:* Azure Database for PostgreSQL Flexible Server read replicas
require a manual promotion operation (`az postgres flexible-server
replica promote`) — there is no automatic failover triggered by
primary failure. `high_availability { mode = "ZoneRedundant" }` on the
primary server resource is the correct feature for genuine automatic failover.

**Exercise 2** — Explain the actual mechanism by which a Terraform
module prevents a caller from changing a hardcoded value inside it,
using Section 10's explanation.

*Answer:* There's no explicit locking or permission system — if a
value inside the module isn't exposed as a declared `variable`, there
is simply no input path for a caller to reach in and change it. It's
ordinary variable scoping/encapsulation, the same principle as a
function's parameter list in any programming language.

**Exercise 3** — A `terraform destroy` fails because the credentials
Terraform was using no longer exist. What is the correct recovery
path, and why is manually deleting resources from the Portal the
wrong one?

*Answer:* Create a replacement credential (Service Principal) with
equivalent permissions, then run `terraform destroy` normally with the
new credentials. Manually deleting from the Portal leaves the state
file confidently recording resources that no longer exist, permanently
desynchronizing Terraform's bookkeeping from reality — the mirror
image of Day 24's `terraform state rm` risk.

---

## 24. Summary Reference

This capstone combines custom modules (Day 20), remote state (Day 4),
environment isolation (Day 4, Day 26), globally-unique naming via
random suffixes (Day 3/18/22), and the `count` + `length()` subnet
pattern (Day 8) into one production-shaped three-tier architecture.

Two corrections matter most if you're building this yourself: Postgres
Flexible Server read replicas require manual promotion, not automatic
failover (use Zone Redundant HA for that instead); and Azure has no
distinct "Internet Gateway" resource the way AWS does — NAT Gateway
replaces what used to be implicit default outbound access, not a
separate gateway object.

This is a genuinely costly project to run (roughly $150+ if left
running across a multi-day build, primarily driven by the multi-AZ
Postgres configuration) — budget for it and destroy promptly, using
`terraform destroy` itself rather than manual Portal deletion, which
permanently breaks the state file's accuracy.

---

*Guide covers: end-to-end three-tier Azure architecture (Application
Gateway with WAF, dual-VMSS presentation and application tiers,
internal load balancer, Postgres Flexible Server with read replica,
Key Vault, private DNS, NAT Gateway, Bastion host), a precise
correction distinguishing Azure's NAT Gateway/default-outbound-access
model from AWS's Internet Gateway concept, an architectural
clarification of Docker-containers-on-VMSS-via-custom-script versus
managed container orchestration, a substantive correction on Postgres
Flexible Server read replica manual promotion versus Zone Redundant
High Availability for genuine automatic failover, per-tier Network
Security Group rule design, Azure service tags (AzureCloud) as the
correct alternative to hardcoded IP ranges, the Bastion host pattern
(callback to Day 15), root/calling/child module terminology applied to
this project's structure (callback to Day 20), the actual mechanism
behind module encapsulation and non-overridable values, the count +
length() subnet-generation pattern (callback to Day 8), random_string
suffixes for globally unique naming (callback to Day 3/18/22), module
dependency chains and depends_on usage, Service Principal setup with
the specific Key Vault Administrator permission gap, remote backend
setup via PowerShell, TF_VAR_ environment variables versus -var
command-line arguments for secret handling and their shared state-file
limitation, a real cost breakdown ($157, primarily Postgres
multi-AZ), a detailed analysis of the video's manual-Portal-deletion
teardown failure and the correct Service-Principal-replacement
recovery path (callback to Day 24's state desynchronization lesson
from the opposite direction), the environment folder pattern for
dev/test/prod isolation, and concrete suggestions for extending the
project (Azure Container Registry, Zone Redundant HA, CI/CD
integration, Azure Monitor alerting).*
