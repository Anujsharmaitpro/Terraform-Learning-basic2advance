# Test Project: Git + Terraform + Pull Request Workflow (Windows / VS Code)

## Goal
Simulate a real "Infrastructure-as-operational-config" workflow:
1. Write Terraform config for a small, cheap/free Azure resource.
2. Store it in Git, on GitHub.
3. Make changes on a branch, open a Pull Request, review, merge.
4. Apply only after merge — mimicking a change-control process.
5. Tear everything down so it costs nothing.

This is a **test/sandbox exercise**, not production infra. Total Azure cost if you clean up properly: **$0** (free tier resource group + storage account).

---

## 1. Requirements (accounts you need)

| What | Why | Cost |
|---|---|---|
| GitHub account | Host the repo, open PRs | Free |
| Microsoft Azure account (Free Tier / Pay-As-You-Go with free credit) | Somewhere to actually apply Terraform | Free tier / $200 trial credit |
| Windows 10/11 machine | Your dev box | — |

If you'd rather not touch a real cloud account at all, skip to **Section 7 (No-cloud alternative)** at the bottom — you can do the entire Git/PR workflow using a local `null_resource` or the `local_file` Terraform provider instead of Azure.

---

## 2. Tools to install

| Tool | Purpose |
|---|---|
| Git for Windows | Version control |
| VS Code | Editor |
| VS Code extensions: **HashiCorp Terraform**, **GitLens** (optional), **GitHub Pull Requests and Issues** | Terraform syntax highlighting, inline Git blame, PR management inside VS Code |
| Terraform CLI | Runs `init/plan/apply` |
| Azure CLI | Authenticates Terraform to your Azure subscription |

---

## 3. Step-by-Step Setup

### 3.1 Install Git for Windows
1. Download: https://git-scm.com/download/win
2. Run the installer. Default options are fine. When asked about default editor, you can pick VS Code.
3. Verify — open **PowerShell** and run:
   ```powershell
   git --version
   ```
4. Set your identity (used in every commit):
   ```powershell
   git config --global user.name "Your Name"
   git config --global user.email "you@example.com"
   ```

### 3.2 Install VS Code
1. Download: https://code.visualstudio.com/
2. Install with defaults.
3. Open VS Code → Extensions icon (left sidebar, or `Ctrl+Shift+X`) → search and install:
   - `HashiCorp Terraform`
   - `GitHub Pull Requests and Issues`
   - (optional) `GitLens`

### 3.3 Install Terraform CLI
Easiest method — use **winget** (built into Windows 10/11):
```powershell
winget install HashiCorp.Terraform
```
Verify:
```powershell
terraform -version
```
If `winget` isn't available, download the .zip manually from https://developer.hashicorp.com/terraform/install, extract it, and add the folder to your Windows `PATH` environment variable.

### 3.4 Install Azure CLI
```powershell
winget install Microsoft.AzureCLI
```
Verify:
```powershell
az --version
```

### 3.5 Log in to Azure
```powershell
az login
```
This opens a browser window — sign in with your Azure account. Once done, confirm your subscription:
```powershell
az account show
```
Note the `id` field — that's your Subscription ID (not strictly needed for this simple example, but good to know).

### 3.6 Create a GitHub repository
1. Go to https://github.com/new
2. Name it e.g. `terraform-git-pr-test`
3. Set it to **Private** (recommended for a test/learning repo) or Public, your choice.
4. Check "Add a README file."
5. Click **Create repository**.

### 3.7 Clone it locally
In PowerShell:
```powershell
cd C:\Projects
git clone https://github.com/<your-username>/terraform-git-pr-test.git
cd terraform-git-pr-test
code .
```
The last command opens the folder directly in VS Code.

---

## 4. Create the Terraform Files

In VS Code, create these three files in the repo root.

### `main.tf`
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

resource "azurerm_resource_group" "test_rg" {
  name     = var.rg_name
  location = var.location
}

resource "azurerm_storage_account" "test_sa" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.test_rg.name
  location                 = azurerm_resource_group.test_rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}
```

### `variables.tf`
```hcl
variable "rg_name" {
  description = "Name of the test resource group"
  type        = string
  default     = "rg-terraform-test"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

variable "storage_account_name" {
  description = "Globally unique storage account name (lowercase, no dashes, 3-24 chars)"
  type        = string
  # you MUST override this — storage account names must be globally unique
}
```

### `outputs.tf`
```hcl
output "resource_group_name" {
  value = azurerm_resource_group.test_rg.name
}

output "storage_account_name" {
  value = azurerm_storage_account.test_sa.name
}
```

### `.gitignore`
Create this too, so you never accidentally commit secrets or local state:
```
.terraform/
*.tfstate
*.tfstate.backup
*.tfvars
.terraform.lock.hcl
```
(Note: for a real team you'd usually commit `.terraform.lock.hcl`. For this test project it's fine to ignore it to keep things simple.)

### `terraform.tfvars` (NOT committed — local only)
```hcl
storage_account_name = "sttfteststudentname01"  # must be globally unique, lowercase, no dashes
```

---

## 5. Initial Commit (baseline, on `main`)

```powershell
git add .
git commit -m "Initial Terraform config for test resource group and storage account"
git push origin main
```

---

## 6. The PR Workflow (this is the part you actually want to test)

### 6.1 Create a feature branch
```powershell
git checkout -b feature/add-tags
```

### 6.2 Make a change
Example: add tags to the resource group. Edit `main.tf`:
```hcl
resource "azurerm_resource_group" "test_rg" {
  name     = var.rg_name
  location = var.location

  tags = {
    environment = "test"
    owner       = "your-name"
  }
}
```

### 6.3 Test locally BEFORE opening the PR
This mirrors "syntax and safety review" — you check it runs clean before asking someone (or yourself) to review it.
```powershell
terraform init
terraform fmt
terraform validate
terraform plan
```
Fix any errors. `plan` should show the tag addition with no destructive changes.

### 6.4 Commit and push the branch
```powershell
git add main.tf
git commit -m "Add environment and owner tags to resource group"
git push origin feature/add-tags
```

### 6.5 Open the Pull Request
- In VS Code: click the **GitHub Pull Requests** icon in the sidebar → "Create Pull Request" → base `main`, compare `feature/add-tags` → fill in title/description → Create.
- Or on GitHub.com: you'll see a "Compare & pull request" banner — click it, fill in details, click **Create pull request**.

### 6.6 (Optional but recommended) Set up branch protection
On GitHub: repo → **Settings** → **Branches** → **Add branch protection rule** → protect `main` → require a pull request before merging, require 1 approval. This forces the PR gate even if it's just you testing solo (you'll need a second GitHub account or ask a friend to approve, or temporarily disable the "require approval" part while testing alone).

### 6.7 Review and merge
Review the diff in the PR (this is your "senior engineer checks syntax/safety" step). Click **Merge pull request** → **Confirm merge**.

### 6.8 Pull the merged change locally and apply
```powershell
git checkout main
git pull origin main
terraform plan
terraform apply
```
Type `yes` when prompted. This creates the real resource group + storage account in Azure — the actual "apply only after merge" moment.

### 6.9 Verify in Azure
```powershell
az group show --name rg-terraform-test
```
Or check the Azure Portal (https://portal.azure.com) under Resource Groups.

---

## 7. Clean Up (important — avoid any charges)
```powershell
terraform destroy
```
Type `yes`. Confirm it's gone:
```powershell
az group show --name rg-terraform-test
```
Should return "not found."

---

## 8. No-Cloud Alternative (if you don't want to touch Azure at all)

Replace the `azurerm` provider with the local provider — no cloud account, no cost, zero risk, but you still get the full Git/PR/init/plan/apply muscle memory:

```hcl
terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

resource "local_file" "test" {
  filename = "${path.module}/test-output.txt"
  content  = "Hello from Terraform, managed via Git PR workflow."
}
```
Everything else in this guide (branching, PR, review, merge, apply) works identically — `terraform apply` just writes a local file instead of creating cloud infrastructure.

---

## Summary of what you've now practiced
- Git branching and commit hygiene
- Terraform init/fmt/validate/plan/apply/destroy
- GitHub Pull Request creation and review gating
- (Optional) branch protection as a stand-in for change-control policy
- Safe, no-cost cloud resource lifecycle testing
