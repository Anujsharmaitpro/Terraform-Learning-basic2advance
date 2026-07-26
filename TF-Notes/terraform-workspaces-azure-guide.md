# Terraform Workspaces — A Complete Beginner's Guide (Azure Edition)

> Based on: "Terraform Zero to Hero — : Terraform Workspaces" 
> Rewritten and re-explained for **Azure**, and expanded for absolute beginners.

---

## How to use this guide

The original uses AWS (EC2 + S3). Since you're focused on Azure, every concept below is mapped to Azure equivalents:

| AWS concept  | Azure equivalent used in this guide |
|---|---|
| AWS provider | `azurerm` provider |
| EC2 instance | Azure Linux Virtual Machine |
| S3 bucket | Azure Storage Account |
| Instance type (`t2.micro`) | VM size (`Standard_B1s`) |
| Region (`us-east-1`) | Azure Region (`East US`) |
| AWS credentials | Azure Service Principal / `az login` |

Nothing about the **core concept of Terraform workspaces** changes — it works identically no matter which cloud provider you use. Only the resource blocks change.

---

## Table of Contents

1. [The Business Problem (Why This Topic Exists)](#1-the-business-problem)
2. [Prerequisite: What is a Terraform State File?](#2-prerequisite-what-is-a-terraform-state-file)
3. [The Problem Without Workspaces](#3-the-problem-without-workspaces)
4. [What Exactly Are Terraform Workspaces?](#4-what-exactly-are-terraform-workspaces)
5. [Terraform Workspace Commands (Cheat Sheet)](#5-terraform-workspace-commands-cheat-sheet)
6. [Hands-On Demo: Setting Up Workspaces on Azure](#6-hands-on-demo-setting-up-workspaces-on-azure)
7. [Making It Dynamic: `terraform.workspace` + `lookup()`](#7-making-it-dynamic-terraformworkspace--lookup)
8. [Two Ways to Manage Per-Environment Values](#8-two-ways-to-manage-per-environment-values)
9. [Critical Safety Warning](#9-critical-safety-warning)
10. [When NOT to Use Workspaces](#10-when-not-to-use-workspaces)
11. [Interview Questions You Should Be Ready For](#11-interview-questions-you-should-be-ready-for)
12. [Full Working Azure Example](#12-full-working-azure-example)
13. [Summary](#13-summary)

---

## 1. The Business Problem

Let's set the scene with a story, exactly likes, but on Azure.

Imagine you are a DevOps Engineer. A development team, **Team XYZ**, raises a ticket:

> "We need an Azure Virtual Machine and a Storage Account created every time we start a new project. We don't have permissions to create these ourselves."

**Step 1 — You write a Terraform module.**
Because you're experienced, you realize this isn't a one-off request. Tomorrow, Team ABC or Team DEF will ask for the exact same thing. So instead of writing one throwaway script, you build a **reusable Terraform module** — a self-contained, parameterized piece of code for "give me a VM" and "give me a storage account." You also add a `README.md` explaining how anyone can consume it.

This solves problem #1: *"I don't want to write the same infrastructure code over and over for every team."*

**Step 2 — A new problem appears: multiple environments.**
Team XYZ comes back and says:

> "This module works great! We tested it in **Dev**. But we also have a **Staging** environment and a **Production** environment. In Dev our VM size is small (`Standard_B1s`), in Staging it's medium (`Standard_B2s`), and in Production it needs to be large (`Standard_D4s_v3`). Do we need to copy this whole project three times — once per environment?"

Your gut instinct might be: *"No problem, I'll just create `dev.tfvars`, `stage.tfvars`, and `prod.tfvars` and pass the right file using `-var-file`."*

Sounds reasonable — but it **doesn't actually work**, and the reason is the **Terraform state file**. To understand why, we need a short detour.

---

## 2. Prerequisite: What is a Terraform State File?

If you already understand this, skip to Section 3. If you're brand new to Terraform, read carefully — this is the single most important concept for understanding workspaces.

When you run `terraform apply`, Terraform doesn't just create resources in Azure and forget about them. It keeps a **record** of exactly what it created, and with what configuration, in a file called `terraform.tfstate` (a JSON file).

Think of the state file as Terraform's **memory**. Every time you run `terraform apply` again, Terraform:

1. Reads the state file to see "what already exists, and what do I think it looks like?"
2. Compares that against your `.tf` code to see "what do you *want* it to look like?"
3. Compares both of those against the **real Azure environment** (a "refresh").
4. Calculates the difference (the "diff" / "plan") and only changes what needs to change.

**Example:** If your state file says "I created a VM named `example-vm` with size `Standard_B1s`," and you then change your code to `Standard_B2s` and run `apply` again, Terraform doesn't create a second VM — it **resizes the existing one**, because its memory (the state file) tells it that VM already exists.

This is exactly the behavior that causes trouble when you try to reuse one project for multiple environments — read on.

---

## 3. The Problem Without Workspaces

Let's say you only use `.tfvars` files and a single, default state file (the normal setup when you first learn Terraform). Your folder looks like this:

```
day6/
├── main.tf
├── terraform.tfvars      # default values
├── dev.tfvars
├── stage.tfvars
├── prod.tfvars
└── modules/
    └── vm/
        ├── main.tf
        └── variables.tf
```

You run:

```bash
terraform apply -var-file="dev.tfvars"
```

Terraform creates a VM. The **one and only** `terraform.tfstate` file now says: *"I own a VM called `example-vm`, configured with the Dev values."*

Now you run:

```bash
terraform apply -var-file="stage.tfvars"
```

You would *expect* a brand-new VM to be created for Staging. **But that's not what happens.** Terraform looks at its one state file, sees "I already have a VM called `example-vm`," and thinks you just want to **modify** that same VM (e.g., resize it to the Staging VM size) — or in worse cases, destroy and recreate it.

> ⚠️ This is exactly what the video demonstrates live: switching `.tfvars` files does **not** create separate infrastructure. It just mutates the same resource over and over, because there's only one state file remembering only one set of resources.

**The real requirement** the teams have is:
- One codebase, written once.
- Independent, non-conflicting infrastructure per environment.
- No copy-pasting entire folders for Dev/Stage/Prod (imagine 10 environments — unmanageable).

This is precisely the gap **Terraform Workspaces** was built to close.

---

## 4. What Exactly Are Terraform Workspaces?

> **Terraform Workspaces let you use the exact same Terraform configuration (code) to manage multiple, completely independent sets of infrastructure — by giving each "workspace" its own separate state file.**

Here's the mental model:

```
terraform.tfstate.d/
├── dev/
│   └── terraform.tfstate     ← remembers ONLY Dev resources
├── stage/
│   └── terraform.tfstate     ← remembers ONLY Stage resources
└── prod/
    └── terraform.tfstate     ← remembers ONLY Prod resources
```

When you're "in" the `dev` workspace and run `terraform apply`, Terraform only reads/writes `terraform.tfstate.d/dev/terraform.tfstate`. It has **zero knowledge** of what exists in `stage` or `prod`. So creating a VM in Dev has no effect whatsoever on Stage or Prod — they're tracked completely separately, even though all three use the **same `main.tf` code**.

This solves the exact problem from Section 3:
- ✅ One project, written once.
- ✅ Environments never collide or overwrite each other.
- ✅ Easy to scale to 10, 50, 100 environments without duplicating folders.

---

## 5. Terraform Workspace Commands (Cheat Sheet)

| Command | What it does |
|---|---|
| `terraform workspace list` | Lists all workspaces. The current one is marked with `*`. There's always a `default` workspace. |
| `terraform workspace new <name>` | Creates a brand-new workspace (and its own empty state file). |
| `terraform workspace select <name>` | Switches your terminal session into a different workspace. |
| `terraform workspace show` | Prints the name of the workspace you're currently in. |
| `terraform workspace delete <name>` | Deletes a workspace (only if its state is empty/destroyed). |

**Example session:**

```bash
terraform workspace new dev
terraform workspace new stage
terraform workspace new prod

terraform workspace list
#   default
# * prod
#   dev
#   stage

terraform workspace select dev
terraform workspace show
# dev
```

---

## 6. Hands-On Demo: Setting Up Workspaces on Azure

Let's rebuild the video's live demo, but using Azure resources instead of AWS. We'll create a simple, reusable **Azure Linux VM module**, then use workspaces to deploy it independently to `dev`, `stage`, and `prod`.

### Step 1 — Folder structure

```
day6-azure/
├── main.tf
├── terraform.tfvars
└── modules/
    └── vm/
        ├── main.tf
        └── variables.tf
```

### Step 2 — Write the reusable module (`modules/vm/main.tf`)

This is the file you, the DevOps engineer, write **once**. It's fully parameterized — nothing is hardcoded.

```hcl
resource "azurerm_resource_group" "rg" {
  name     = "rg-example"
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-example"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "subnet-example"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_interface" "nic" {
  name                = "nic-example"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "example" {
  name                = "vm-example"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = var.vm_size          # <-- this is the important variable
  admin_username      = "azureuser"
  network_interface_ids = [azurerm_network_interface.nic.id]

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}
```

### Step 3 — Declare the module's variables (`modules/vm/variables.tf`)

```hcl
variable "location" {
  description = "Azure region to deploy resources into"
  type        = string
}

variable "vm_size" {
  description = "The size (SKU) of the Azure Virtual Machine"
  type        = string
}
```

### Step 4 — Consume the module (`main.tf` at project root)

This is the file that **Team XYZ** (or you, on their behalf) writes. Notice how short and simple it is — all the complexity lives inside the module.

```hcl
terraform {
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

module "vm" {
  source   = "./modules/vm"
  location = var.location
  vm_size  = var.vm_size
}

variable "location" {
  type = string
}

variable "vm_size" {
  type = string
}
```

### Step 5 — Provide values (`terraform.tfvars`)

```hcl
location = "East US"
vm_size  = "Standard_B1s"
```

### Step 6 — Try it WITHOUT workspaces first (to see the problem)

```bash
terraform init
terraform apply
```

This creates one VM using `Standard_B1s`. Now, exactly like the video, if you create a `stage.tfvars` with `vm_size = "Standard_B2s"` and run:

```bash
terraform apply -var-file="stage.tfvars"
```

Terraform will **resize the existing VM** instead of creating a second, independent one — because there's still only one default state file. This confirms the problem.

### Step 7 — Now bring in workspaces

```bash
# Clean slate: destroy what you made in the previous step first
terraform destroy

# Create one workspace per environment
terraform workspace new dev
terraform workspace new stage
terraform workspace new prod

terraform workspace select dev
terraform init
terraform apply
```

Check your folder — you'll now see:

```
terraform.tfstate.d/
├── dev/terraform.tfstate     ← created after applying in dev
├── stage/                    ← empty until you apply here too
└── prod/                     ← empty until you apply here too
```

Switch and apply for the other two:

```bash
terraform workspace select stage
terraform apply

terraform workspace select prod
terraform apply
```

Now check the Azure Portal (Resource Groups) — you will see **three separate VMs**, one per environment, and none of them interfered with each other. That's the core win of workspaces.

---

## 7. Making It Dynamic: `terraform.workspace` + `lookup()`

In the demo above, we still manually edited `terraform.tfvars` (or swapped `-var-file`) each time we switched workspaces. That's manual, error-prone, and not scalable. The video shows a cleaner pattern using two built-in tools:

1. **`terraform.workspace`** — a special, automatically available variable that always equals the name of the workspace you're currently in (`"dev"`, `"stage"`, or `"prod"`).
2. **`lookup(map, key, default)`** — a built-in function that looks up a value from a map using a key, and falls back to a default if the key isn't found.

Combine these so the VM size is chosen **automatically** based on whichever workspace you're in — no manual editing required.

### Update `modules/vm/variables.tf`

Instead of a plain string, define a **map of strings** keyed by environment name:

```hcl
variable "vm_size" {
  description = "Map of VM sizes per environment"
  type        = map(string)
  default = {
    dev   = "Standard_B1s"
    stage = "Standard_B2s"
    prod  = "Standard_D4s_v3"
  }
}
```

### Update the VM resource to use `lookup()`

```hcl
resource "azurerm_linux_virtual_machine" "example" {
  # ...
  size = lookup(var.vm_size, terraform.workspace, "Standard_B1s")
  # ...
}
```

**How to read this line:**
- Look inside the `var.vm_size` map.
- Use `terraform.workspace` (e.g., `"stage"`) as the key.
- If that key exists in the map → use its value (`"Standard_B2s"`).
- If it doesn't exist → fall back to the default, `"Standard_B1s"`.

Now the entire flow becomes:

```bash
terraform workspace select stage
terraform apply
# terraform.workspace = "stage" → lookup finds "stage" in the map → uses Standard_B2s automatically
```

No more editing `.tfvars` by hand every time you switch environments — the correct configuration is selected automatically based on which workspace is active. This is the same pattern shown live in the video (it's identical logic; only the resource and value names are swapped for Azure).

---

## 8. Two Ways to Manage Per-Environment Values

The video explicitly calls out that manually editing the same `.tfvars` file every time you switch workspaces is bad practice. It gives you two better alternatives:

### Option A — One `.tfvars` file per environment, passed explicitly

```
dev.tfvars
stage.tfvars
prod.tfvars
```

```bash
terraform workspace select stage
terraform apply -var-file="stage.tfvars"
```

- ✅ Simple, explicit, easy to read.
- ❌ You must remember to pass the correct file every time — human error is possible (e.g., accidentally applying `prod.tfvars` while in the `dev` workspace).

### Option B — A single map variable + `lookup()` + `terraform.workspace` (recommended)

This is the pattern from Section 7.

- ✅ Fully automatic — Terraform figures out the right values based on the active workspace. No risk of applying the wrong file.
- ✅ Scales cleanly to many environments — just add another key to the map.
- ❌ Slightly more advanced HCL (maps + functions) for a total beginner.

**Recommendation for real projects:** Option B is generally considered the safer, more scalable pattern once you're comfortable with maps and the `lookup()` function, because it removes the human step of "remembering which file to pass."

---

## 9. Critical Safety Warning

This is called out explicitly in the video, and it deserves its own section because it can cause **real production outages**:

> ⚠️ **Workspaces do not stop you from running the wrong command in the wrong workspace.** If you intend to destroy the `stage` workspace, but you're accidentally sitting in the `prod` workspace, `terraform destroy` **will destroy your production infrastructure.**

Terraform will print a confirmation prompt showing which workspace you're about to affect — **always read it before typing `yes`.**

**Practical safety habits:**
- Always run `terraform workspace show` before any `apply` or `destroy`, especially in a script or CI/CD pipeline.
- In Azure DevOps / GitHub Actions pipelines, explicitly `terraform workspace select <env>` as its own visible pipeline step, and echo the result, so it's logged.
- Consider naming your Azure Resource Groups or resources with the workspace name embedded (e.g., `rg-${terraform.workspace}`) so mistakes are visually obvious in the Azure Portal before they cause damage.
- For true production safety, many teams also use **separate Azure subscriptions or separate remote state backends per environment** in addition to workspaces (more on this in the next section).

---

## 10. When NOT to Use Workspaces

Workspaces are great for **quick, structurally-identical environments** (same resources, different sizes/counts/names). But be aware of real-world limitations, especially relevant if you're heading toward more advanced Azure setups:

- **Workspaces share the same backend configuration.** If Dev and Prod need to live in *completely different Azure subscriptions*, or use *different state storage accounts*, plain workspaces aren't the right tool — you'd typically use separate **backend configs** (e.g., Terraform Cloud workspaces, or distinct `backend "azurerm" {}` blocks per environment) or a directory-per-environment approach instead.
- **If environments need structurally different resources** (not just different sizes, but entirely different architecture — e.g., Prod has a load balancer and Dev doesn't), a single parameterized module with `count`/`for_each` conditionals gets messy fast; separate `.tf` files or modules per environment may be cleaner.
- **Team access control**: workspaces don't provide separate IAM/RBAC boundaries by themselves. If Dev and Prod need different people to have access, that's enforced at the Azure RBAC / backend storage level, not by the workspace feature itself.

This isn't a criticism of the concept — just context so you know workspaces are one tool in the toolbox, not a universal solution for every environment-management scenario.

---

## 11. Interview Questions You Should Be Ready For

The video explicitly says: *"nobody will ask you to build an entire AKS cluster in an interview — they'll ask about workspaces and modules."* Here are the kinds of questions you should be able to answer confidently:

1. **What problem do Terraform workspaces solve?**
   → Reusing the same Terraform code across multiple environments without state file conflicts or code duplication.

2. **What happens to the state file when you create a new workspace?**
   → A dedicated state file is created for that workspace under `terraform.tfstate.d/<workspace_name>/terraform.tfstate`, isolated from all other workspaces.

3. **What is `terraform.workspace` and how would you use it?**
   → A built-in variable that resolves to the current workspace's name at runtime; commonly combined with `lookup()` to select environment-specific values automatically.

4. **What's the danger of using workspaces carelessly?**
   → Running `apply`/`destroy` in the wrong workspace can affect the wrong environment (e.g., destroying production by mistake) since the CLI state is easy to overlook.

5. **Can workspaces fully replace separate directories/repos per environment?**
   → Not always — if environments need different backends, subscriptions, or fundamentally different resource architectures, a directory/module-per-environment or Terraform Cloud workspace approach may be more appropriate.

---

## 12. Full Working Azure Example

Here's the complete, self-contained project combining everything above, ready for you to practice with (adjust names/regions as needed):

```
day6-azure/
├── main.tf
└── modules/
    └── vm/
        ├── main.tf
        └── variables.tf
```

**`main.tf` (root)**
```hcl
terraform {
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

module "vm" {
  source = "./modules/vm"
}
```

**`modules/vm/variables.tf`**
```hcl
variable "vm_size" {
  description = "Map of VM sizes per environment (keyed by workspace name)"
  type        = map(string)
  default = {
    dev   = "Standard_B1s"
    stage = "Standard_B2s"
    prod  = "Standard_D4s_v3"
  }
}
```

**`modules/vm/main.tf`**
```hcl
resource "azurerm_resource_group" "rg" {
  name     = "rg-${terraform.workspace}"
  location = "East US"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${terraform.workspace}"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "subnet-${terraform.workspace}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_interface" "nic" {
  name                = "nic-${terraform.workspace}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "example" {
  name                   = "vm-${terraform.workspace}"
  resource_group_name    = azurerm_resource_group.rg.name
  location               = azurerm_resource_group.rg.location
  size                   = lookup(var.vm_size, terraform.workspace, "Standard_B1s")
  admin_username         = "azureuser"
  network_interface_ids  = [azurerm_network_interface.nic.id]

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}
```

**Run it:**

```bash
cd day6-azure
terraform init

terraform workspace new dev
terraform workspace new stage
terraform workspace new prod

terraform workspace select dev
terraform apply   # creates rg-dev, vm-dev sized Standard_B1s

terraform workspace select stage
terraform apply   # creates rg-stage, vm-stage sized Standard_B2s

terraform workspace select prod
terraform apply   # creates rg-prod, vm-prod sized Standard_D4s_v3
```

Notice that naming resources with `${terraform.workspace}` also solves a secondary Azure-specific problem: resource names (and some resource types, like Storage Accounts) must be **globally or regionally unique**, so embedding the workspace name avoids naming collisions across environments automatically.

---

## 13. Summary

| Concept | One-line takeaway |
|---|---|
| **Terraform module** | Write infrastructure code once, reuse it for any team/project. |
| **State file** | Terraform's memory of what it created — the reason naive multi-environment approaches fail. |
| **The problem** | One state file = one environment's worth of memory; reusing `.tfvars` alone causes Terraform to mutate the same resources instead of creating separate ones. |
| **Terraform Workspaces** | Give each environment its own isolated state file, while reusing the exact same code. |
| **Key commands** | `workspace new`, `workspace select`, `workspace show`, `workspace list`, `workspace delete`. |
| **`terraform.workspace`** | Built-in variable = name of current workspace. |
| **`lookup()`** | Fetch environment-specific values (e.g., VM size) automatically based on the active workspace. |
| **Biggest risk** | Running `destroy`/`apply` in the wrong workspace — always double-check with `terraform workspace show`. |
| **Limitation** | Workspaces alone don't handle differing backends, subscriptions, or structurally different architectures per environment. |

**Practice tip (same advice as in the video):** Don't just read this — actually run through Section 6 and Section 12 yourself in an Azure sandbox subscription or free trial. Interviewers ask about workspaces and modules far more often than complex services, precisely because they reveal whether you understand Terraform's core mechanics.
