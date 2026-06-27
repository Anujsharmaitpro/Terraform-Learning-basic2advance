# Terraform Fundamentals & Infrastructure as Code
## Deep-Dive Learning Guide — Day 1 / 28 Days of Easy Terraform
### Beginner-First Edition | Azure Examples Throughout

---

## Before You Start — A Note to the Complete Beginner

This guide treats you as someone who has never touched Terraform,
never written infrastructure code, and maybe only heard the word "cloud" in passing.
Every single term is explained before it is used.
No assumed knowledge. No unexplained jargon. No skipping.

By the end of this guide you will be able to answer:
- What is Infrastructure as Code and why does it exist?
- What problems does manually managing cloud resources cause?
- How does Terraform solve those problems?
- How does Terraform actually work — step by step?
- How do I install Terraform and confirm it is working?

---

## Table of Contents

1. The World Before Infrastructure as Code
2. What Is Infrastructure as Code? (Plain English)
3. The Three-Tier Architecture Example — What Are We Actually Building?
4. The Six Problems of Manual Infrastructure Management
5. The Six Enterprise Environments — Why the Problems Get Worse
6. What Is Terraform? (And What Are the Alternatives?)
7. How Terraform Solves Every Problem from Section 4
8. How Terraform Works — The Full Workflow, Step by Step
9. Terraform Commands Explained One by One
10. The .tf File — What It Is and Why It Matters
11. What Is a Provider? (Teaser for Next Video)
12. Installing Terraform — Every Operating System
13. Verifying Your Installation
14. Prerequisites Checklist Before You Code
15. Common Beginner Questions Answered
16. Practice Exercises
17. Complete Cheat Sheet

---

## 1. The World Before Infrastructure as Code

To understand why Terraform exists, you first need to feel the pain it was created to solve.

### Imagine you are a DevOps engineer in 2012

Your company runs a web application. That application needs servers — computers in a data centre — to run on. Your job is to make those servers exist, configure them correctly, and keep them running.

In 2012 (and still today in many places), you would:

1. Open a web browser
2. Log into the Azure Portal (or AWS Console, or GCP Console)
3. Click through menus and forms, filling in names, sizes, regions
4. Click "Create" and wait
5. Repeat for every resource you need

This is called **manual provisioning** — you are provisioning (creating) infrastructure by hand, through a graphical interface, one click at a time.

For a single server, this is fine. For a real-world application, this becomes a serious problem very quickly.

---

## 2. What Is Infrastructure as Code? (Plain English)

### The simple definition

**Infrastructure as Code (IaC)** means writing a text file — actual code — that describes what infrastructure you want, and then running that file to automatically create it.

Instead of clicking through the Azure Portal to create a Virtual Machine, you write:

```hcl
# This is Terraform code (a .tf file)
# It tells Azure: "Create a Virtual Machine for me"

resource "azurerm_linux_virtual_machine" "web_server" {
  name                = "my-first-vm"
  resource_group_name = "my-resource-group"
  location            = "East US"
  size                = "Standard_B1s"
  admin_username      = "adminuser"
}
```

You save that file, run one command, and Azure creates the Virtual Machine automatically. No clicking. No forms. No human involvement after you write the code.

### The analogy that makes it click

Think of a recipe book.

A chef can make a cake by memory — they wing it each time, adding a bit of this and a bit of that. The result varies each time. If the chef is sick, no one else can make the same cake.

Or a chef can write down the recipe with exact measurements. Now:
- Anyone can follow the recipe and get the same cake every time
- The recipe can be shared, stored, version-controlled
- You can make 10 identical cakes simultaneously
- If something goes wrong, you check the recipe for the error

**Infrastructure as Code is the recipe. The cloud infrastructure is the cake.**

### IaC Tools Available

The instructor mentioned several tools. Here's what they are:

| Tool | Made By | Works With |
|---|---|---|
| **Terraform** | HashiCorp | Any cloud (Azure, AWS, GCP, and 1000+ providers) |
| **Pulumi** | Pulumi Corp | Any cloud, uses real programming languages (Python, TypeScript) |
| **Azure ARM Templates** | Microsoft | Azure only |
| **Azure Bicep** | Microsoft | Azure only (cleaner version of ARM templates) |
| **AWS CloudFormation** | Amazon | AWS only |
| **GCP Deployment Manager** | Google | GCP only |

Terraform is the most widely used because it works with **any** cloud provider using the same language and workflow. Learn Terraform once, work with any cloud.

---

## 3. The Three-Tier Architecture — What Are We Actually Building?

The instructor drew a diagram showing why manual infrastructure management fails at scale. Let's understand that diagram first, because the rest of the lecture is built around it.

### What is a Three-Tier Architecture?

Most web applications are divided into three layers (tiers). Think of ordering food on Zomato or Swiggy:

```
TIER 1: Web Tier       → What you see in your browser (the menu, buttons)
TIER 2: App Tier       → The logic (checking your order, calculating price)
TIER 3: Database Tier  → Where all data is stored (users, orders, prices)
```

Each tier runs on its own set of servers. Users talk to Tier 1. Tier 1 talks to Tier 2. Tier 2 talks to Tier 3.

### The Azure version of this architecture

```
                        [ USER on Internet ]
                               |
                    [ External Load Balancer ]
                    (Azure Traffic Manager /
                     Azure Load Balancer)
                    /                      \
        [ Web Server 1 ]          [ Web Server 2 ]
        (Azure VM)                (Azure VM)
          Both inside a Virtual Machine Scale Set (VMSS)
                    \                      /
                    [ Internal Load Balancer ]
                    /                      \
        [ App Server 1 ]          [ App Server 2 ]
        (Azure VM)                (Azure VM)
          Both inside another VMSS
                               |
                    [ Azure Database ]
                    (Master + Slave — for high availability)
```

### What is a Virtual Machine Scale Set (VMSS)?

When one of your web servers crashes, Azure needs to automatically create a new one to replace it. A **Virtual Machine Scale Set** is a group of identical VMs that Azure manages for you — if one goes down, a new one is automatically created from a template.

AWS calls this an "Auto Scaling Group." GCP calls it a "Managed Instance Group (MIG)."

### What is a Load Balancer?

Imagine 1000 users hitting your website at the same time. If all 1000 go to Server 1, it crashes. A **Load Balancer** sits in front of your servers and distributes incoming traffic evenly — it sends some users to Server 1 and some to Server 2.

**External Load Balancer** — faces the internet, handles user traffic coming IN.
**Internal Load Balancer** — inside your network, routes traffic between tiers.

### What is a Master/Slave Database?

The **Master** database handles all write operations (saving new data). The **Slave** database is an exact copy that handles read operations (fetching data). If the master fails, the slave can take over. This is called **High Availability**.

### So what does this add up to?

For this single three-tier architecture, you need to create:

```
Resources to provision manually:
─────────────────────────────────
 2 × Web Server VMs
 2 × App Server VMs
 1 × External Load Balancer
 1 × Internal Load Balancer
 1 × Virtual Machine Scale Set (web tier)
 1 × Virtual Machine Scale Set (app tier)
 1 × Master Database
 1 × Slave Database
 1 × Resource Group (the container for all of this)
─────────────────────────────────
 Total: ~10+ resources to configure and wire together
```

The instructor says this takes roughly **2 hours manually**. Now multiply that.

---

## 4. The Six Problems of Manual Infrastructure Management

The instructor listed six specific pain points. Here they are explained in full.

### Problem 1 — TIME

Manually clicking through the Azure Portal to create 10+ resources takes approximately 2 hours.

That is 2 hours where nothing else is happening:
- No development
- No testing
- No performance testing
- No actual work — just infrastructure setup

And when you're done, the infrastructure has to be destroyed (to save money) and recreated again tomorrow. So it's 2 hours every single day, just to get started.

### Problem 2 — PEOPLE REQUIRED

Before Infrastructure as Code existed, companies had dedicated **infrastructure teams** whose entire job was just clicking through portals and provisioning servers. This is not a productive use of skilled engineers.

With Terraform, a single engineer writes the code once, and anyone can use it to provision identical infrastructure in minutes.

### Problem 3 — COST

Cloud resources cost money by the hour. Here's the arithmetic the instructor laid out:

```
Morning: 9 hours to provision infrastructure
          (team arrives, starts clicking, done by early afternoon)

Infrastructure runs overnight:
          No one is using it (everyone went home)
          But Azure is still charging you per hour

The choices:
   Option A — Leave it running overnight → Wasted money
   Option B — Destroy it at end of day   → 2-4 more hours of manual work
                                           Then recreate it next morning (9 more hours)

Either way, you're bleeding time and money.
```

With Terraform, destroying everything takes one command (`terraform destroy`) and recreating it takes one command (`terraform apply`). Both run in minutes.

### Problem 4 — REPETITIVE & ERROR-PRONE

Humans make mistakes, especially when doing the same repetitive task over and over.

When you manually create a Virtual Machine through the Azure Portal, you fill in:
- Name
- Region
- VM size
- Operating system
- Admin username
- Network settings
- Disk configuration
- Tags
- ...and more

One typo. One wrong dropdown selection. One missed checkbox. And your infrastructure is wrong — possibly in a way that causes production outages hours or days later when no one remembers what was configured.

With Terraform, the configuration is written once in code. Code doesn't accidentally click the wrong dropdown.

### Problem 5 — INSECURE

When teams manually manage infrastructure through the Azure Portal:
- Multiple people log in with their own accounts
- It's hard to track who changed what and when
- Role-based access control (who is allowed to change what) is difficult to enforce
- Audit trails are messy

With Terraform code stored in a Git repository:
- Every change is a commit with a name, timestamp, and message
- Changes go through pull requests (code review)
- You can see exactly who changed what, when, and why
- Access is controlled through the Git platform (GitHub, GitLab, Azure DevOps)

### Problem 6 — "IT WORKS ON MY MACHINE"

This is the most important problem, and the one most engineers have personally experienced.

**The scenario:**

A developer writes code and tests it in the Dev environment. It works perfectly. The code is then deployed to Production. It breaks. The developer says: *"But it works on my machine!"*

**Why this happens:**

All six environments (Dev, UAT, SIT, Pre-Prod, DR, Production) were provisioned manually by different people at different times. Over months and years:

```
Dev environment:          Java 11, App Config v2.1, Patch KB4023057 applied
Production environment:   Java 17, App Config v2.3, Patch KB4023057 NOT applied
```

The environments are supposed to be identical. They're not. Because no one was enforcing consistency — every person who clicked through the portal made slightly different choices.

**How Terraform fixes this:**

You write ONE Terraform template. You use it to create ALL environments. The code is the same. The infrastructure is identical. No more "it works on my machine" — because every machine was built from the same recipe.

```hcl
# One template used for ALL environments
# Only the variable value changes

variable "environment" {
  default = "dev"   # change to "prod" for production
}

resource "azurerm_resource_group" "main" {
  name     = "rg-myapp-${var.environment}"   # rg-myapp-dev or rg-myapp-prod
  location = "East US"
}

resource "azurerm_linux_virtual_machine" "web" {
  name                = "vm-web-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_B1s"
  # ... same config for all environments
}
```

Same code. Different variable. Perfectly identical environments.

---

## 5. The Six Enterprise Environments — Why Problems Compound

The instructor explained that in a real enterprise, you don't have one environment. You have six:

| Environment | Purpose |
|---|---|
| **Dev** | Developers write and test new features here |
| **SIT** (System Integration Test) | Multiple components are tested together |
| **UAT** (User Acceptance Testing) | Business users test whether features work as expected |
| **Pre-Production** | Final check — identical to production |
| **DR** (Disaster Recovery) | A standby copy in a different region; activated if production fails |
| **Production** | The live environment that real users use |

### The multiplication problem

```
One environment = 2 hours to provision manually

Six environments = 2 hours × 6 = 12 hours

12 hours of clicking, form-filling, and waiting
Before anyone can write a single line of application code.
```

And then if you need to update a configuration across all six environments? Another full day of manual work with a high risk of inconsistency.

With Terraform:

```bash
# Change one variable, apply to all environments
terraform workspace select dev   && terraform apply
terraform workspace select sit   && terraform apply
terraform workspace select uat   && terraform apply
terraform workspace select preprod && terraform apply
terraform workspace select dr    && terraform apply
terraform workspace select prod  && terraform apply
```

Six environments provisioned consistently, from the same code, in the same time it took to provision one manually.

---

## 6. What Is Terraform?

Terraform is an open-source Infrastructure as Code tool created by **HashiCorp** in 2014.

### What makes Terraform special

**It is cloud-agnostic.** The same Terraform language works with Azure, AWS, GCP, and over 1,000 other providers (Kubernetes, GitHub, Cloudflare, Datadog, etc.). You learn the tool once and use it everywhere.

**It is declarative.** You describe WHAT you want, not HOW to create it. You don't write step-by-step instructions — you describe the end state and Terraform figures out how to get there.

```hcl
# Declarative — you say WHAT you want
resource "azurerm_resource_group" "example" {
  name     = "my-resource-group"
  location = "East US"
}
```

Terraform reads this and says: "The user wants a Resource Group named 'my-resource-group' in East US. Does it exist? No. I will create it."

**It tracks state.** Terraform remembers what it has already created. If you run it again without changes, it does nothing. If you change the name, it knows to update (or recreate) only that resource.

### Terraform's file extension

All Terraform configuration files end in **`.tf`**

```
main.tf           ← your main infrastructure code
variables.tf      ← variable definitions
outputs.tf        ← values you want printed after apply
providers.tf      ← which cloud provider to use
terraform.tfvars  ← actual values for variables
```

Terraform automatically reads ALL `.tf` files in the same folder. You don't need to import or link them — they are all automatically combined.

---

## 7. How Terraform Solves Every Problem

| Problem | Manual Way | Terraform Way |
|---|---|---|
| Time | 2 hours per environment | Minutes — `terraform apply` |
| People | Dedicated infra team | One engineer writes code once |
| Cost | Infrastructure runs overnight accidentally | `terraform destroy` at end of day in seconds |
| Human Error | Wrong dropdown, missed checkbox | Code reviewed and version-controlled |
| Security | Messy portal access, no audit trail | Git history, pull requests, code review |
| "Works on my machine" | Environments drift apart over months | All environments from same code — always identical |

---

## 8. How Terraform Works — The Full Workflow

This is the diagram the instructor drew. Let's understand every box.

```
┌─────────────────────────────────────────────────────────────┐
│                    YOUR GIT REPOSITORY                       │
│    main.tf   variables.tf   outputs.tf   providers.tf       │
└──────────────────────────┬──────────────────────────────────┘
                           │
              DevOps Engineer runs commands
              (or a CI/CD pipeline does it automatically)
                           │
            ┌──────────────▼─────────────────┐
            │        terraform init           │  Step 1
            │   Downloads provider plugins    │
            └──────────────┬─────────────────┘
                           │
            ┌──────────────▼─────────────────┐
            │       terraform validate        │  Step 2
            │   Checks code for syntax errors │
            └──────────────┬─────────────────┘
                           │
            ┌──────────────▼─────────────────┐
            │        terraform plan           │  Step 3
            │   Shows what WILL be created/   │
            │   updated/destroyed (dry run)   │
            └──────────────┬─────────────────┘
                           │
            ┌──────────────▼─────────────────┐
            │        terraform apply          │  Step 4
            │   Actually makes the changes    │
            │   to Azure (or AWS/GCP etc.)    │
            └──────────────┬─────────────────┘
                           │
            ┌──────────────▼─────────────────┐
            │       terraform destroy         │  Step 5 (when done)
            │   Deletes all created resources │
            │   (saves cost)                  │
            └─────────────────────────────────┘
```

---

## 9. Terraform Commands Explained — One by One

### `terraform init`

**What it does:** Initialises your project. Downloads the necessary **provider plugin** for the cloud you're using.

Think of it like `npm install` (for JavaScript developers) or `pip install` (for Python developers) — it downloads the dependencies.

```bash
terraform init
```

You will see output like:
```
Initializing the backend...
Initializing provider plugins...
- Finding hashicorp/azurerm versions matching "~> 3.0"...
- Installing hashicorp/azurerm v3.75.0...
- Installed hashicorp/azurerm v3.75.0

Terraform has been successfully initialized!
```

**When to run it:** Once when you first start a project. Again if you add a new provider.

---

### `terraform validate`

**What it does:** Checks your `.tf` files for syntax errors — like a spell-checker for your Terraform code. It does NOT connect to Azure. It only checks the code itself.

```bash
terraform validate
```

Success output:
```
Success! The configuration is valid.
```

Error output:
```
Error: Argument or block definition required
  on main.tf line 5, in resource "azurerm_resource_group" "example":
   5: location = 
An argument definition must end with a newline or comma.
```

**When to run it:** After writing new code, before running plan.

---

### `terraform plan`

**What it does:** Connects to Azure, compares what you have in your code with what currently exists in Azure, and shows you exactly what it will CREATE, UPDATE, or DESTROY — without actually doing it.

This is your **dry run**. Your chance to review before anything is changed.

```bash
terraform plan
```

Output example:
```
Terraform will perform the following actions:

  # azurerm_resource_group.example will be created
  + resource "azurerm_resource_group" "example" {
      + id       = (known after apply)
      + location = "eastus"
      + name     = "my-resource-group"
    }

  # azurerm_linux_virtual_machine.web will be created
  + resource "azurerm_linux_virtual_machine" "web" {
      + id   = (known after apply)
      + name = "my-web-vm"
      + size = "Standard_B1s"
    }

Plan: 2 to add, 0 to change, 0 to destroy.
```

The symbols tell you what will happen:
```
+   (green)  → Resource will be CREATED
~   (yellow) → Resource will be UPDATED (changed in place)
-   (red)    → Resource will be DESTROYED
-/+ (red)    → Resource will be DESTROYED then RECREATED
```

**When to run it:** Always before apply. Never skip this step.

---

### `terraform apply`

**What it does:** Actually executes the changes — creates, updates, or destroys resources in Azure. By default, it shows the plan one more time and asks for confirmation.

```bash
terraform apply
```

It will prompt:
```
Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes
```

To skip the confirmation prompt (used in automated pipelines):
```bash
terraform apply --auto-approve
```

After completion:
```
Apply complete! Resources: 2 added, 0 changed, 0 destroyed.
```

---

### `terraform destroy`

**What it does:** Deletes ALL resources that Terraform created. This is how you clean up after testing to stop Azure billing.

```bash
terraform destroy
```

Or with auto-approval:
```bash
terraform destroy --auto-approve
```

Output:
```
Destroy complete! Resources: 2 destroyed.
```

**Important:** Only destroys resources that are tracked in Terraform's state file. Resources created manually outside Terraform are not touched.

---

## 10. The .tf File — What It Is and Why It Matters

A `.tf` file is a plain text file written in **HCL** — HashiCorp Configuration Language. It looks similar to JSON but is more human-readable.

### A complete, simple Azure example

Here is a full working Terraform setup to create a Resource Group and a Virtual Network in Azure. This is the kind of code you will write in the coming videos.

**providers.tf** — tells Terraform which cloud to talk to:
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
```

**variables.tf** — defines input values so the code is reusable:
```hcl
variable "environment" {
  description = "The deployment environment (dev, uat, prod)"
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure region to deploy resources"
  type        = string
  default     = "East US"
}
```

**main.tf** — the actual infrastructure:
```hcl
# Step 1: Create a Resource Group
# (A Resource Group is like a folder in Azure — it holds all your resources)
resource "azurerm_resource_group" "main" {
  name     = "rg-myapp-${var.environment}"
  location = var.location

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Step 2: Create a Virtual Network inside that Resource Group
resource "azurerm_virtual_network" "main" {
  name                = "vnet-myapp-${var.environment}"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = {
    Environment = var.environment
  }
}
```

**outputs.tf** — values printed after apply so you can see what was created:
```hcl
output "resource_group_name" {
  description = "The name of the created Resource Group"
  value       = azurerm_resource_group.main.name
}

output "vnet_id" {
  description = "The ID of the Virtual Network"
  value       = azurerm_virtual_network.main.id
}
```

### Reading a resource block — anatomy

```hcl
resource "azurerm_resource_group" "main" {
│      │                          │    │
│      │                          │    └── Local name (you choose this)
│      │                          └─────── Resource type (from Azure docs)
│      └────────────────────────────────── Keyword: always "resource"
└───────────────────────────────────────── Block type

  name     = "rg-myapp-dev"   ← argument: the actual Azure resource name
  location = "East US"         ← argument: which Azure region
}
```

The **resource type** (`azurerm_resource_group`) tells Terraform exactly what Azure API to call. The **local name** (`main`) is just how you refer to this resource inside your own code.

---

## 11. What Is a Provider? (Teaser for Next Video)

The instructor mentioned "provider plugins" during the `terraform init` step. Here's a brief explanation so you're not confused.

A **provider** is a plugin that lets Terraform talk to a specific service. Azure has its own provider. AWS has its own. GitHub has its own.

Without a provider, Terraform is just a language with no way to talk to anything.

```hcl
# This tells Terraform: "Use the Azure provider"
provider "azurerm" {
  features {}
}
```

When you run `terraform init`, Terraform downloads the Azure provider plugin from the internet. This plugin knows how to translate your `.tf` code into actual Azure API calls.

The next video in the series covers providers in full detail.

---

## 12. Installing Terraform — Every Operating System

### macOS (what the instructor used)

Uses **Homebrew** (a package manager for Mac):

```bash
# Step 1: Add HashiCorp's tap (repository of packages)
brew tap hashicorp/tap

# Step 2: Install Terraform
brew install hashicorp/tap/terraform
```

If Homebrew is not installed:
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### Windows

**Option A — Using Chocolatey (package manager):**
```powershell
# Run in PowerShell as Administrator
choco install terraform
```

**Option B — Manual download:**
1. Go to https://developer.hashicorp.com/terraform/downloads
2. Download the Windows AMD64 zip file
3. Extract it — you get a single file called `terraform.exe`
4. Move `terraform.exe` to `C:\Windows\System32\` (or add its folder to your PATH)

**Option C — Using winget (Windows Package Manager):**
```powershell
winget install HashiCorp.Terraform
```

### Linux (Ubuntu/Debian)

```bash
# Step 1: Install required packages
sudo apt-get update && sudo apt-get install -y gnupg software-properties-common

# Step 2: Add HashiCorp's GPG key (verifies the download is authentic)
wget -O- https://apt.releases.hashicorp.com/gpg | \
  sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

# Step 3: Add HashiCorp repository
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
  https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
  sudo tee /etc/apt/sources.list.d/hashicorp.list

# Step 4: Update and install
sudo apt update && sudo apt-get install terraform
```

### Linux (RHEL/CentOS/Fedora)

```bash
# Add HashiCorp repository
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo

# Install
sudo yum -y install terraform
```

### Check Your Architecture First (What the Instructor Showed)

Before downloading binaries, check what type of system you have:

```bash
uname -a
```

Output example:
```
Darwin MacBook-Pro.local 23.0.0 Darwin Kernel Version ... arm64
```

`arm64` means you have an Apple Silicon Mac (M1/M2/M3). `x86_64` means Intel/AMD.
Download the binary matching your architecture.

---

## 13. Verifying Your Installation

After installing, run this single command:

```bash
terraform -version
```

You should see something like:
```
Terraform v1.9.8
on darwin_arm64
```

The version number will differ, but as long as you see `Terraform v1.x.x` without an error, installation was successful.

If you see `command not found`, Terraform is not in your PATH. This is the most common installation problem — the instructor noted this and pointed to his GitHub repository for troubleshooting steps.

---

## 14. Prerequisites Checklist Before You Code

The instructor listed these before starting the series. Go through each one:

```
□ 1. Azure Account
      Sign up at: https://azure.microsoft.com/free
      Free tier gives you $200 credit for 30 days

□ 2. Azure Fundamentals Knowledge
      Understand: Resource Groups, VMs, VNets, Load Balancers, Storage
      Free learning: https://learn.microsoft.com/en-us/training/paths/az-900-describe-cloud-concepts/

□ 3. Terraform Installed
      Verify with: terraform -version

□ 4. VS Code Installed
      Download at: https://code.visualstudio.com/
      Add the "HashiCorp Terraform" extension for syntax highlighting

□ 5. Azure CLI Installed (needed for authentication in coming videos)
      Mac:   brew install azure-cli
      Linux: curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
      Windows: winget install Microsoft.AzureCLI
      Verify: az version

□ 6. Git Installed (for version control)
      Mac:   brew install git
      Linux: sudo apt install git
      Windows: https://git-scm.com/download/win
      Verify: git --version
```

---

## 15. Common Beginner Questions Answered

**Q: Is Terraform free?**
Yes. Terraform itself is open-source and free. You pay for the cloud resources it creates (Azure VMs, databases, etc.) — that billing is between you and Azure, not HashiCorp.

**Q: Do I need to know a programming language first?**
No. HCL (HashiCorp Configuration Language) is simpler than most programming languages. It is declarative — you describe what you want, not how to do it step by step.

**Q: What happens if I accidentally run `terraform apply` and create real resources?**
Run `terraform destroy` immediately. As long as you destroy within the same billing period, the cost is minimal. This is why the instructor always reminds viewers to destroy resources at the end of each video.

**Q: Where does Terraform store information about what it has created?**
In a file called `terraform.tfstate`. This is critical — it is Terraform's memory. Do not delete it. In production, this file is stored remotely (Azure Blob Storage, S3, etc.) so teams can share it.

**Q: What is the difference between terraform plan and terraform apply?**
`plan` is a preview — nothing changes in Azure. `apply` actually makes changes. Always run `plan` first.

**Q: What if two people run terraform apply at the same time?**
This is called a state conflict and it can corrupt your infrastructure. In professional setups, the state file is locked during apply so only one person can run it at a time. The next videos will cover this.

**Q: Can Terraform import infrastructure that was created manually (through the Azure Portal)?**
Yes — using `terraform import`. But it only imports the state reference; you still have to write the matching code. This is a more advanced topic.

---

## 16. Practice Exercises

### Exercise 1 — Conceptual: The Problems of Manual Infrastructure

Without writing any code, answer these questions:

- Your team manually creates 4 environments. Each takes 3 hours. How many person-hours are spent just on provisioning?
- A junior engineer accidentally selected "West Europe" instead of "East US" when creating a VM manually. How would you catch this mistake? How would Terraform prevent it?
- Your production environment has been running for 6 months with manual changes applied by 5 different team members, none of whom documented what they did. What risks does this create?

### Exercise 2 — Installation Verification

Run the following commands and note the output:

```bash
terraform -version          # What version is installed?
uname -a                    # What architecture is your machine?
az version                  # Is Azure CLI installed?
git --version               # Is Git installed?
```

### Exercise 3 — File Structure

Create this folder structure on your machine (no code yet, just files):

```
my-first-terraform/
├── providers.tf
├── variables.tf
├── main.tf
└── outputs.tf
```

Open `main.tf` and type this (do NOT run it yet — just practise writing it):

```hcl
resource "azurerm_resource_group" "learning" {
  name     = "rg-terraform-learning"
  location = "East US"
}
```

### Exercise 4 — Command Order

Without looking at notes, write down the correct order of Terraform commands for:
- Starting a new project
- Before applying changes
- After testing, to clean up

**Answer:**
```
1. terraform init      ← always first, once per project
2. terraform validate  ← check for syntax errors
3. terraform plan      ← review what will change
4. terraform apply     ← make the changes
5. terraform destroy   ← clean up when done
```

---

## 17. Complete Cheat Sheet

```
╔══════════════════════════════════════════════════════════════════════════════╗
║           TERRAFORM FUNDAMENTALS — DAY 1 QUICK REFERENCE                    ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  WHAT IS IaC?                                                                ║
║  Writing code (text files) to automatically create cloud infrastructure     ║
║  instead of manually clicking through the Azure Portal                      ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  6 PROBLEMS TERRAFORM SOLVES                                                 ║
║  1. Time         → Minutes instead of hours                                  ║
║  2. People       → One engineer writes code once                             ║
║  3. Cost         → terraform destroy in seconds, no idle resources           ║
║  4. Human Error  → Code doesn't click the wrong dropdown                    ║
║  5. Security     → Git history + pull requests + code review                 ║
║  6. Consistency  → Same code = identical environments, every time            ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  COMMANDS — in order                                                         ║
║                                                                              ║
║  terraform init       Download provider plugins (run once)                   ║
║  terraform validate   Check code for syntax errors (no Azure connection)    ║
║  terraform plan       Preview changes — nothing is created (dry run)        ║
║  terraform apply      Make actual changes in Azure                           ║
║  terraform destroy    Delete all Terraform-managed resources                 ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  PLAN OUTPUT SYMBOLS                                                         ║
║  +    green   → will be CREATED                                              ║
║  ~    yellow  → will be UPDATED                                              ║
║  -    red     → will be DESTROYED                                            ║
║  -/+  red     → will be DESTROYED then RECREATED                             ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  FILE TYPES                                                                  ║
║  .tf          Terraform configuration files (HCL language)                  ║
║  .tfvars      Variable values                                                ║
║  .tfstate     Terraform's memory of what it created (don't delete this)     ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  STANDARD FILE STRUCTURE                                                     ║
║  providers.tf    Which cloud and version to use                              ║
║  variables.tf    Input variable definitions                                  ║
║  main.tf         Your actual infrastructure resources                        ║
║  outputs.tf      Values to print after apply                                 ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  BASIC RESOURCE BLOCK ANATOMY                                                ║
║                                                                              ║
║  resource "azurerm_resource_group" "main" {                                  ║
║          │                          │                                        ║
║          └── resource type          └── local name (your choice)            ║
║                                                                              ║
║    name     = "my-rg"    ← argument: the Azure resource name                ║
║    location = "East US"  ← argument: the Azure region                       ║
║  }                                                                           ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  INSTALLATION (VERIFY WITH: terraform -version)                              ║
║  macOS:   brew tap hashicorp/tap && brew install hashicorp/tap/terraform     ║
║  Windows: choco install terraform  OR  winget install HashiCorp.Terraform    ║
║  Ubuntu:  sudo apt-get install terraform  (after adding HashiCorp repo)      ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  IaC TOOLS COMPARISON                                                        ║
║  Terraform        → Any cloud, most widely used, HCL language               ║
║  Azure Bicep      → Azure only, cleaner than ARM templates                  ║
║  AWS CloudFormation → AWS only                                               ║
║  Pulumi           → Any cloud, uses Python/TypeScript/Go                    ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

---

## The Core Mental Model for This Entire Series

```
Manual Way:
  You → Azure Portal → Click, Fill Forms, Pray → Infrastructure
  (Slow, error-prone, inconsistent, unrepeatable)

Terraform Way:
  You → Write .tf file once → terraform apply → Infrastructure
  (Fast, consistent, version-controlled, repeatable, auditable)
```

The rest of this 28-video series builds on this foundation — adding variables, modules, remote state, loops, functions, and eventually full end-to-end production architectures on Azure.

---

*Guide covers: Infrastructure as Code, IaC tools comparison, three-tier architecture, VMSS, load balancers, manual vs automated provisioning, the 6 problems of manual infrastructure, enterprise environments, what Terraform is, HCL, .tf files, provider plugins, terraform init / validate / plan / apply / destroy, plan output symbols, tfstate file, Terraform installation on macOS/Windows/Linux, Azure Resource Group, Azure Virtual Network, variable blocks, output blocks, resource block anatomy.*
