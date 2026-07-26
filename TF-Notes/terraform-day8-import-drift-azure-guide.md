# Terraform Interview Scenarios — Import & Drift Detection (Azure Edition)

> Based on: "Terraform Zero to Hero — Day 8 (Bonus): Two Scenario-Based Interview Questions" (video transcript you shared)
> Rewritten and re-explained for **Azure**, for absolute beginners.

This is a companion to your Day 6 workspaces guide. Where that video used AWS (EC2, CloudFormation, IAM, Lambda, CloudWatch), this guide maps every concept to its Azure equivalent so you can practice and interview using the cloud you actually work with.

| AWS concept in video | Azure equivalent used in this guide |
|---|---|
| EC2 instance | Azure Virtual Machine |
| CloudFormation | ARM Templates / Bicep |
| IAM policies/users/roles | Azure RBAC (roles, role assignments) |
| CloudWatch (logs) | Azure Monitor / Activity Log |
| Lambda function | Azure Function |
| S3 bucket lifecycle | Storage Account lifecycle management policy |

---

## Table of Contents

1. [Why This Video Exists](#1-why-this-video-exists)
2. [Scenario 1: Migrating Existing Azure Infrastructure into Terraform](#2-scenario-1-migrating-existing-azure-infrastructure-into-terraform)
3. [Scenario 1 — Full Walkthrough on Azure](#3-scenario-1--full-walkthrough-on-azure)
4. [Scenario 2: Configuration Drift Detection](#4-scenario-2-configuration-drift-detection)
5. [Scenario 2 — Two Ways to Detect Drift on Azure](#5-scenario-2--two-ways-to-detect-drift-on-azure)
6. [Interview Answer Cheat Sheet](#6-interview-answer-cheat-sheet)
7. [Summary](#7-summary)

---

## 1. Why This Video Exists

The instructor's earlier 7-day series covered core Terraform concepts (providers, state, modules, workspaces, etc.). This bonus day exists to bridge a specific gap: **scenario-based interview questions**. Knowing *what* a Terraform command does is different from being able to explain, out loud, *why* you'd use it and *what challenges* come with it — which is what interviewers actually probe for.

Two scenarios are covered:

1. **You already have infrastructure in the cloud that was NOT created by Terraform (e.g., created manually, or via ARM templates/Bicep, or by another engineer). How do you bring it under Terraform's management?**
2. **You have infrastructure that Terraform DOES manage, but someone changed it manually outside of Terraform. How do you detect that?**

These map to two important, distinct Terraform concepts: **import** and **drift detection**. Let's go through each in detail.

---

## 2. Scenario 1: Migrating Existing Azure Infrastructure into Terraform

### The setup

Imagine your team previously provisioned an Azure Virtual Machine using something other than Terraform — maybe someone clicked through the Azure Portal manually, or an ARM template/Bicep deployment created it. Now your team wants to **manage that VM going forward using Terraform**.

You can't just write a `main.tf` describing that VM and run `terraform apply` — because Terraform has never seen this resource before. It has **no state file entry** for it. If you did that, Terraform would try to **create a brand-new VM** (since, as far as its memory/state file is concerned, nothing exists yet) — potentially leaving you with a duplicate, or erroring out because the name is already taken.

### Why this is harder than it sounds

If it's a single VM, you might think: *"I'll just write the resource block by hand to match what's already there."* That's manageable for one resource. But real-world migrations usually involve **hundreds of resources** — VMs, Storage Accounts, Virtual Networks, Databases, and so on — each with dozens of fields (networking, security, tags, disks...). Hand-writing all of that accurately, for every resource, would take an enormous amount of time and is highly error-prone.

This is exactly the problem **Terraform's `import` functionality** solves.

### The core idea

> **`terraform import` tells Terraform: "This resource already exists in Azure at this address — go fetch its current configuration and record it in the state file, so you now consider yourself the owner of it."**

Once that resource is represented in your state file, Terraform behaves as if it created it — future `terraform plan` runs will correctly show "no changes" instead of trying to recreate it.

---

## 3. Scenario 1 — Full Walkthrough on Azure

Let's reproduce the video's live demo, but for an Azure VM instead of an EC2 instance.

### Step 0 — The situation

You have an Azure VM already running (created outside Terraform — say, manually via the Portal). You want Terraform to manage it. Your local folder is completely empty — no `.tf` files, no state file.

```
day8/scenario1/          ← empty folder
```

### Step 1 — Write a minimal `main.tf` with a provider block

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

### Step 2 — Use an `import` block (Terraform 1.5+ feature)

Terraform 1.5 introduced a declarative `import` block, so you no longer have to remember a separate CLI command from memory — you can describe the import directly in code:

```hcl
import {
  to = azurerm_linux_virtual_machine.example
  id = "/subscriptions/<sub-id>/resourceGroups/<rg-name>/providers/Microsoft.Compute/virtualMachines/<vm-name>"
}
```

- `to` — the Terraform resource address you want this imported resource to be represented as (you choose this name; here it's `azurerm_linux_virtual_machine.example`).
- `id` — the **Azure Resource ID** of the existing VM. In Azure, every resource has a fully-qualified resource ID (unlike AWS's shorter instance IDs) — you can copy it from the Azure Portal's "Properties" blade, or get it via:

```bash
az vm show --resource-group <rg-name> --name <vm-name> --query "id" -o tsv
```

### Step 3 — Auto-generate the matching resource block

Rather than hand-writing the entire `azurerm_linux_virtual_machine` resource block (which has dozens of possible fields), let Terraform generate it for you:

```bash
terraform init
terraform plan -generate-config-out="generated_resource.tf"
```

This creates a new file, `generated_resource.tf`, containing a complete `resource "azurerm_linux_virtual_machine" "example" { ... }` block reflecting the VM's actual current configuration in Azure — networking, OS disk, size, tags, everything Terraform's provider schema knows about.

> **Why is the generated file so large?** Because Terraform doesn't know which fields you consider "important" — it includes both required fields (like `size`, `resource_group_name`) and every optional field that has a value on the real resource (like specific OS disk caching settings, availability zone, boot diagnostics, etc.). You can trim fields you don't want to manage explicitly later, but Terraform gives you the full picture first.

### Step 4 — Move the generated code into your real `main.tf`

Copy the generated resource block into `main.tf`, then delete `generated_resource.tf` — you only needed it to extract the configuration.

### Step 5 — Run the actual import

```bash
terraform import azurerm_linux_virtual_machine.example \
  "/subscriptions/<sub-id>/resourceGroups/<rg-name>/providers/Microsoft.Compute/virtualMachines/<vm-name>"
```

This is the command that actually writes an entry into your **state file** for this VM.

### Step 6 — Verify

```bash
terraform plan
```

If everything matches, Terraform should report:

```
No changes. Your infrastructure matches the configuration.
```

This confirms the VM is now fully under Terraform's management — your code and Azure's real state agree, and your state file has a record of it.

### What to say in an interview

If asked *"how would you migrate existing Azure infrastructure into Terraform?"*, a strong answer covers:

1. Use `terraform import` (CLI command or declarative `import` block) with the resource's Azure Resource ID.
2. Use `terraform plan -generate-config-out` to avoid hand-writing large, error-prone resource blocks.
3. Verify success with `terraform plan` showing "no changes."
4. Acknowledge the **real challenge**: at scale (hundreds/thousands of existing resources), this is time-consuming and requires careful validation resource-by-resource — mentioning this shows you've actually done it, not just memorized the command.

---

## 4. Scenario 2: Configuration Drift Detection

### The setup

Now assume the opposite problem: **all** of your Azure infrastructure — hundreds of resources — was created and is managed by Terraform. Everything's been running smoothly for months. Then, one day, a teammate needs to fix an urgent issue on a Storage Account's lifecycle management policy. It's late in their shift, so instead of updating the Terraform code and running `apply` properly, they **log into the Azure Portal and change the setting manually**.

This fixes the immediate issue for one customer, but:
- Nine other customers are still affected by the underlying problem.
- The rest of the team has no idea a manual change was made.
- The person who made the change might go on leave, change teams, or simply forget what they changed.

### Why this matters

> **This situation — where the real infrastructure no longer matches what Terraform's state file believes it manages — is called "configuration drift."**

Terraform does **not automatically detect this in real time**. It only notices drift when you explicitly ask it to check, by running a plan/refresh — which means drift can silently exist for a long time if nobody happens to run Terraform.

This is a legitimate and common interview scenario because it tests whether you understand that Terraform is not a live, continuously-enforcing system by default — it's a "check when asked" tool, unless you build extra tooling around it.

---

## 5. Scenario 2 — Two Ways to Detect Drift on Azure

### Option A — Scheduled `terraform refresh` (or `plan`) as a scheduled job

`terraform refresh` re-syncs the state file against real infrastructure without changing anything, and reports discrepancies (this behavior is now also available via `terraform plan -refresh-only`).

**How to operationalize it:**
- Set up a **scheduled pipeline** (e.g., an Azure DevOps Pipeline schedule trigger, or a GitHub Actions cron job) that runs `terraform plan -refresh-only` every hour, every day — whatever interval fits your risk tolerance.
- Parse the output; if it reports any differences, send a notification (Teams webhook, email, Slack, etc.) to the team.

```yaml
# Example: Azure DevOps pipeline schedule (conceptual)
schedules:
- cron: "0 * * * *"   # every hour
  displayName: Hourly drift check
  branches:
    include:
    - main
  always: true

steps:
- script: |
    terraform init
    terraform plan -refresh-only -detailed-exitcode
  displayName: 'Check for drift'
```

**Honest caveat (the video makes this point explicitly, and it's worth repeating):** `terraform refresh` as a standalone command has had a somewhat uncertain path in Terraform's own evolution — its behavior has shifted over versions (notably, plain `terraform refresh` is being nudged toward `terraform plan -refresh-only` / `terraform apply -refresh-only` as the more explicit, safer alternatives). Don't treat this as a rock-solid, permanent API — check the Terraform version your organization is on and confirm current recommended usage before building automation around it.

- ✅ Simple to set up, uses Terraform's own native mechanism.
- ❌ It's **pull-based/periodic**, not real-time — drift can exist undetected between scheduled runs.
- ❌ Relies on you remembering to build and maintain this pipeline.

### Option B — Real-time detection via Azure Monitor + Azure Functions

This is the more event-driven approach and generally scales better for larger teams.

**How it works, step by step:**

1. **Every change to an Azure resource is recorded in the Azure Activity Log** (Azure's equivalent of AWS CloudWatch/CloudTrail-style auditing) — this includes who/what made the change (a specific user, a service principal, or your Terraform automation's identity) and exactly what was changed.
2. **Route Activity Log events to an Azure Function** (Azure's equivalent of AWS Lambda) — you can do this via an Azure Monitor **Action Group** triggered by an **Alert Rule**, or by streaming Activity Log data to an Event Hub that the Function subscribes to.
3. **Inside the Azure Function**, maintain a reference to which resources are managed by Terraform (e.g., by checking for a Terraform-specific tag like `ManagedBy = "terraform"`, or by checking whether the identity that made the change matches your Terraform service principal's identity).
4. **Decision logic:**
   - If the identity that made the change **is** your Terraform service principal → no action, this was a legitimate `terraform apply`.
   - If the identity that made the change is a **human user or any other identity**, and the resource **is tagged/known as Terraform-managed** → this is an unauthorized manual change. The Function sends a notification (Teams, email, Slack, PagerDuty, etc.) immediately.

```
Azure Activity Log
      │
      ▼
Alert Rule / Event Hub
      │
      ▼
Azure Function ──► checks: "Was this identity the Terraform SP?"
      │
      ├── Yes → no action
      └── No  → send alert (Teams/Email/Slack)
```

- ✅ Near real-time — you find out about drift within minutes, not at the next scheduled run.
- ✅ Tells you exactly **who** made the change, which is valuable for accountability.
- ❌ More setup effort: requires building and maintaining the Function, alert rules, and tagging discipline across all Terraform-managed resources.

### Which one should you actually use?

The video is candid that this is somewhat a matter of team preference and maturity, not a strict "correct answer":

- Smaller teams / simpler setups → scheduled `terraform plan -refresh-only` job is often good enough.
- Larger teams, stricter compliance/audit requirements, or environments where unauthorized changes are a real risk → the Azure Monitor + Function approach gives faster, more accountable detection.

A third layer worth mentioning in an interview, even though it's prevention rather than detection: **tightening Azure RBAC** so that most engineers simply don't have direct write access to production resources at all (only your Terraform automation's identity does), reducing the chance of manual drift happening in the first place. This is harder to enforce in practice (people often need break-glass access), which is exactly why detection mechanisms like the two above are still necessary as a safety net.

---

## 6. Interview Answer Cheat Sheet

| Question | Strong answer |
|---|---|
| **How do you bring existing (non-Terraform-created) Azure resources under Terraform management?** | `terraform import` (CLI or declarative `import` block), ideally paired with `terraform plan -generate-config-out` to auto-generate the matching resource code instead of writing it by hand. Verify with `terraform plan` showing "no changes." |
| **What's the biggest challenge with importing at scale?** | Large environments have hundreds/thousands of resources with many fields each; manual review of generated config, and confirming each `terraform plan` truly shows no diff, takes significant time and care. |
| **What is configuration drift?** | When real infrastructure no longer matches what Terraform's state file believes exists — usually because someone changed something outside of Terraform (e.g., directly in the Azure Portal). |
| **How do you detect drift?** | Either (a) a scheduled job running `terraform plan -refresh-only` on an interval, or (b) an event-driven pipeline using Azure Activity Log + Azure Functions to flag changes made by non-Terraform identities in near real-time. |
| **How do you prevent drift in the first place?** | Strict Azure RBAC so only the Terraform automation identity (service principal) has write access to managed resources; human engineers use Terraform PRs/pipelines instead of console access. |

---

## 7. Summary

| Concept | One-line takeaway |
|---|---|
| **Terraform import** | Brings existing, non-Terraform-created Azure resources under Terraform's management by writing them into the state file. |
| **`-generate-config-out`** | Lets Terraform auto-write the resource block for you instead of hand-typing potentially huge configurations. |
| **Configuration drift** | When real Azure infrastructure diverges from what Terraform's state file believes — usually from manual out-of-band changes. |
| **`terraform plan -refresh-only`** (successor to plain `refresh`) | Re-syncs state against real infrastructure and reports differences without changing anything. |
| **Azure Monitor + Azure Function approach** | Event-driven, near real-time drift detection based on Activity Log events and identity checks. |
| **Prevention** | Strict Azure RBAC limiting direct write access mostly to the Terraform service principal. |

**Practice tip:** Try Scenario 1 yourself with a throwaway Azure VM created manually in the Portal, then import it. It's a very reproducible exercise. Scenario 2's Azure Function approach is more involved to set up, but even sketching the architecture (Activity Log → Function → notification) out loud is usually enough to demonstrate understanding in an interview.
