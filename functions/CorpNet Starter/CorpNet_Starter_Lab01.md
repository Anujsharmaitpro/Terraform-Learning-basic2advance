# 🏗️ Terraform Practice Project: "CorpNet Starter"
## Lab 01 — Beginner-Friendly Azure Infrastructure Deployment

> **Series:** Terraform Beginner → Advanced (Self-Paced Learning)  
> **Lab:** 01 of 12  
> **Estimated Cost:** ~$5–$10/month (with Micro-SKUs)  
> **Estimated Time:** 3–4 hours to complete  
> **Real-World Scenario:** You are a Junior DevOps Engineer at a small company. Your manager asks you to set up a basic corporate web presence with a simple website, secure storage for assets, and a way to monitor uptime — all using Infrastructure as Code (IaC).

---

## 📋 Table of Contents

1. [Project Overview](#1-project-overview)
2. [Naming Conventions](#2-naming-conventions)
3. [Architecture Diagram](#3-architecture-diagram)
4. [Core Components to Build](#4-core-components-to-build)
5. [Sample Data to Use](#5-sample-data-to-use)
6. [Environment Requirements](#6-environment-requirements)
7. [Hints & Pitfalls](#7-hints--pitfalls)
8. [Verification Checklist](#8-verification-checklist)
9. [Cost Breakdown (Micro-SKUs)](#9-cost-breakdown-micro-skus)
10. [Next Labs Preview](#10-next-labs-preview)

---

## 1. Project Overview

### What We Are Building

A **real, testable corporate web infrastructure** on Azure using Terraform. This is not a toy project — you will deploy actual resources, host a real website, and verify it works via a public URL.

### The Business Story

> **Scenario:** "TechStart Solutions" is a small IT consulting firm. They need:
> - A simple company website to showcase services
> - A place to store and serve static assets (logos, documents, images)
> - Basic network isolation for security
> - A way to monitor if the website is up and running
>
> You are the DevOps engineer tasked with building this from scratch using Terraform.

### Why This Matters

| Skill You Will Learn | Why It Matters in Real Orgs |
|---------------------|----------------------------|
| Resource Group & Tagging | Every org uses resource groups for billing isolation and governance |
| Virtual Network + Subnet | Foundation of ALL Azure networking — every app needs this |
| Storage Account (Static Website) | Cheapest way to host a website; used for SPAs, documentation, assets |
| Azure Load Balancer (Basic) | Entry point for multi-tier apps; you will use this heavily in future labs |
| Terraform State Management | Critical for team collaboration; skipping this is a career mistake |

### Scope (Strictly Beginner)

- ✅ Deploy 5–6 Azure resources
- ✅ All resources are **independent** — no Lab 2 dependency
- ✅ Use **Micro-SKUs** only (Free / Basic / Standard Small)
- ✅ End with a **working public URL** you can share
- ❌ No complex multi-tier apps (covered in Labs 5–8)
- ❌ No Azure AD (covered in Labs 9–12)
- ❌ No Kubernetes, no databases, no VMs (covered in future labs)

---

## 2. Naming Conventions

> **Rule:** Follow these EXACTLY. In real orgs, inconsistent naming breaks automation, billing, and security audits.

### 2.1 General Rules

| Rule | Example | Why |
|------|---------|-----|
| **All lowercase** | `corpnet` not `CorpNet` | Azure has case-insensitive resource names; lowercase prevents confusion |
| **No special chars** except hyphens | `corpnet-rg` not `corpnet_rg` | Some Azure resources don't allow underscores |
| **Environment suffix mandatory** | `-dev`, `-prod`, `-lab` | Prevents accidental production changes |
| **Max 24 chars for storage accounts** | `corpnetstdev` | Storage account name limit is 24 chars, globally unique |
| **Region abbreviation** | `eus` (East US), `weu` (West Europe) | Short, consistent, readable |

### 2.2 Resource-Specific Naming

| Resource Type | Naming Pattern | Example |
|---------------|---------------|---------|
| **Resource Group** | `rg-<project>-<env>-<region>` | `rg-corpnet-lab-eus` |
| **Virtual Network** | `vnet-<project>-<env>-<region>` | `vnet-corpnet-lab-eus` |
| **Subnet** | `snet-<purpose>-<env>` | `snet-web-lab`, `snet-mgmt-lab` |
| **Storage Account** | `st<project><env><region>` (no hyphens, max 24) | `stcorpnetlabeus` |
| **Load Balancer** | `lb-<purpose>-<env>-<region>` | `lb-web-lab-eus` |
| **Public IP** | `pip-<purpose>-<env>-<region>` | `pip-web-lab-eus` |
| **Network Security Group** | `nsg-<purpose>-<env>-<region>` | `nsg-web-lab-eus` |
| **Terraform Variables** | `snake_case` | `resource_group_name`, `location` |
| **Terraform Locals** | `snake_case` | `common_tags`, `naming_prefix` |
| **Terraform Outputs** | `snake_case` | `website_url`, `storage_endpoint` |

### 2.3 Tagging Standard (Mandatory)

Every resource MUST have these tags:

```
Environment   = "lab"
Project       = "corpnet-starter"
ManagedBy     = "terraform"
Owner         = "your-name"
CostCenter    = "learning"
CreatedDate   = "2026-07-20"
```

> 💡 **Pro Tip:** In real orgs, missing tags = failed security audit. Build the habit now.

---

## 3. Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        AZURE CLOUD                               │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              Resource Group: rg-corpnet-lab-eus          │   │
│  │                                                          │   │
│  │  ┌─────────────────────────────────────────────────┐    │   │
│  │  │     Virtual Network: vnet-corpnet-lab-eus         │    │   │
│  │  │     Address Space: 10.0.0.0/16                  │    │   │
│  │  │                                                  │    │   │
│  │  │  ┌─────────────────────────────────────────┐   │    │   │
│  │  │  │  Subnet: snet-web-lab                   │   │    │   │
│  │  │  │  Address Prefix: 10.0.1.0/24             │   │    │   │
│  │  │  │                                          │   │    │   │
│  │  │  │  ┌─────────────────────────────────┐    │   │    │   │
│  │  │  │  │  NSG: nsg-web-lab-eus           │    │   │    │   │
│  │  │  │  │  Rules: Allow HTTP (80)         │    │   │    │   │
│  │  │  │  │         Allow HTTPS (443)       │    │   │    │   │
│  │  │  │  └─────────────────────────────────┘    │   │    │   │
│  │  │  └─────────────────────────────────────────┘   │    │   │
│  │  └─────────────────────────────────────────────────┘    │   │
│  │                                                          │   │
│  │  ┌─────────────────────────────────────────────────┐    │   │
│  │  │  Storage Account: stcorpnetlabeus               │    │   │
│  │  │  Tier: Standard (LRS)                           │    │   │
│  │  │  Static Website Hosting: ENABLED              │    │   │
│  │  │  Primary Endpoint: $web                       │    │   │
│  │  │                                                  │    │   │
│  │  │  Container: $web (auto-created)               │    │   │
│  │  │  Files: index.html, error.html                  │    │   │
│  │  └─────────────────────────────────────────────────┘    │   │
│  │                                                          │   │
│  │  ┌─────────────────────────────────────────────────┐    │   │
│  │  │  Load Balancer: lb-web-lab-eus (Basic SKU)     │    │   │
│  │  │  Public IP: pip-web-lab-eus (Basic, Dynamic)   │    │   │
│  │  │  Frontend IP: Assigned by Azure                │    │   │
│  │  │  Backend Pool: (placeholder for future VMs)   │    │   │
│  │  │  Health Probe: HTTP on port 80                │    │   │
│  │  │  Load Balancing Rule: TCP 80 → 80               │    │   │
│  │  └─────────────────────────────────────────────────┘    │   │
│  │                                                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Terraform State: Remote (Azure Storage Backend)        │   │
│  │  Container: tfstate                                       │   │
│  │  File: corpnet-lab.terraform.tfstate                      │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘

    🌐 Public Access:
    • Website URL: https://stcorpnetlabeus.z13.web.core.windows.net/
    • Load Balancer IP: <Dynamic Public IP from Azure>
```

---

## 4. Core Components to Build

> **Instructions:** Build these 4 components. Each is **independent** — you can build them in any order. No component depends on another to function.

---

### Component 1: Foundation Layer (Resource Group + VNet + Subnet + NSG)

**What to Build:**
- Create a Resource Group with proper tags
- Deploy a Virtual Network with address space `10.0.0.0/16`
- Create one Subnet `snet-web-lab` with prefix `10.0.1.0/24`
- Attach a Network Security Group to the subnet with rules:
  - Allow inbound HTTP (port 80) from `Internet`
  - Allow inbound HTTPS (port 443) from `Internet`
  - Deny all other inbound traffic (default Azure behavior)

**Why It Matters:**
> This is the **network foundation** used in 95% of Azure deployments. Every VM, App Service, and database lives inside a VNet. Learning this first makes everything else easier.

**Real-World Parallel:**
> When you join a company, the first thing you'll do is provision networking for a new project. This component teaches you that exact workflow.

---

### Component 2: Static Website Hosting (Storage Account)

**What to Build:**
- Create a Standard Storage Account (LRS replication)
- Enable **Static Website Hosting** feature
- Upload two HTML files:
  - `index.html` — Company homepage
  - `error.html` — 404 error page
- Configure the storage account to serve `index.html` as the default document
- Output the **primary website endpoint URL** as a Terraform output

**Why It Matters:**
> Static website hosting on Azure Storage is the **cheapest way to host a website** (~$0.02/GB/month). It's used for:
> - Company landing pages
> - Documentation sites
> - Single Page Applications (SPAs)
> - Asset/CDN origins

**Real-World Parallel:**
> Many startups host their entire marketing site on Azure Storage + CDN. This is a skill you'll use repeatedly.

---

### Component 3: Load Balancer (Basic SKU)

**What to Build:**
- Deploy an Azure Load Balancer with **Basic SKU** (free tier)
- Create a **Public IP address** (Basic, Dynamic allocation)
- Configure:
  - Frontend IP Configuration (linked to Public IP)
  - Backend Address Pool (empty for now — placeholder)
  - Health Probe (HTTP, port 80, interval 15s)
  - Load Balancing Rule (TCP, frontend port 80 → backend port 80)
- Output the **Public IP address** as a Terraform output

**Why It Matters:**
> Load Balancers are the **entry point for every multi-tier application**. Even with an empty backend pool, learning to configure:
> - Frontend IPs
> - Health probes
> - Load balancing rules
>
> ...prepares you for the VM-based and container-based labs ahead.

**Real-World Parallel:**
> In production, this LB would sit in front of 2+ VMs or a VM Scale Set. For now, you're learning the configuration pattern — the backend will be populated in Lab 3 (VMs).

---

### Component 4: Terraform State Management (Remote Backend)

**What to Build:**
- Create a **separate** Storage Account (or use the same one with a different container) for Terraform state
- Create a blob container named `tfstate`
- Configure Terraform to use **Azure Storage Backend**:
  - Store the state file remotely (not locally)
  - Enable state locking (using blob leases)
- Verify: After `terraform apply`, check the blob container — your `.tfstate` file should be there

**Why It Matters:**
> **This is the #1 mistake beginners make.** Storing state locally means:
> - You can't collaborate with teammates
> - You lose state if your laptop crashes
> - You can't run Terraform in CI/CD pipelines
>
> Remote state with locking is **non-negotiable** in every real organization.

**Real-World Parallel:**
> Every Terraform project in a corporate environment uses remote state. This component ensures you build the right habit from day one.

---

## 5. Sample Data to Use

> Use these exact values to keep your project consistent and testable.

### 5.1 Terraform Variables (sample `.tfvars`)

```hcl
# ============================================
# CorpNet Starter - Terraform Variables
# ============================================

# General
project_name    = "corpnet"
environment     = "lab"
location        = "eastus"
region_abbr     = "eus"

# Network
vnet_address_space   = "10.0.0.0/16"
snet_web_prefix      = "10.0.1.0/24"

# Storage
storage_account_tier = "Standard"
replication_type     = "LRS"

# Tags (applied to ALL resources)
tags = {
  Environment   = "lab"
  Project       = "corpnet-starter"
  ManagedBy     = "terraform"
  Owner         = "your-name"
  CostCenter    = "learning"
  CreatedDate   = "2026-07-20"
}
```

### 5.2 HTML Files to Upload

**`index.html` — Company Homepage**

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>TechStart Solutions</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            max-width: 800px;
            margin: 0 auto;
            padding: 40px 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            min-height: 100vh;
        }
        .container {
            background: rgba(255,255,255,0.1);
            border-radius: 16px;
            padding: 40px;
            backdrop-filter: blur(10px);
        }
        h1 { font-size: 2.5em; margin-bottom: 10px; }
        .subtitle { font-size: 1.2em; opacity: 0.9; margin-bottom: 30px; }
        .services {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin-top: 30px;
        }
        .service-card {
            background: rgba(255,255,255,0.15);
            padding: 20px;
            border-radius: 12px;
            text-align: center;
        }
        .badge {
            display: inline-block;
            background: #00d4aa;
            color: #1a1a2e;
            padding: 8px 16px;
            border-radius: 20px;
            font-weight: bold;
            font-size: 0.9em;
            margin-top: 20px;
        }
        .footer {
            margin-top: 40px;
            text-align: center;
            opacity: 0.7;
            font-size: 0.9em;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 TechStart Solutions</h1>
        <p class="subtitle">Your Trusted IT Consulting Partner</p>

        <p>We deliver cutting-edge cloud infrastructure, DevOps automation, and digital transformation solutions for businesses of all sizes.</p>

        <span class="badge">✅ Deployed via Terraform on Azure</span>

        <div class="services">
            <div class="service-card">
                <h3>☁️ Cloud Migration</h3>
                <p>Seamless transition to Azure, AWS, or GCP</p>
            </div>
            <div class="service-card">
                <h3>🔧 DevOps</h3>
                <p>CI/CD pipelines, IaC, and automation</p>
            </div>
            <div class="service-card">
                <h3>🔒 Security</h3>
                <p>Compliance, monitoring, and threat detection</p>
            </div>
        </div>

        <div class="footer">
            <p>📍 East US Region | 🏗️ Infrastructure as Code | 💰 Cost-Optimized</p>
            <p><em>This website is hosted on Azure Storage Static Website — deployed entirely with Terraform.</em></p>
        </div>
    </div>
</body>
</html>
```

**`error.html` — 404 Error Page**

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>404 - Page Not Found | TechStart Solutions</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            margin: 0;
            background: #1a1a2e;
            color: white;
        }
        .error-container {
            text-align: center;
            padding: 40px;
        }
        .error-code {
            font-size: 8em;
            font-weight: bold;
            color: #e94560;
            margin: 0;
        }
        .error-message {
            font-size: 1.5em;
            margin: 20px 0;
        }
        .home-link {
            display: inline-block;
            margin-top: 30px;
            padding: 12px 30px;
            background: #e94560;
            color: white;
            text-decoration: none;
            border-radius: 8px;
            font-weight: bold;
            transition: background 0.3s;
        }
        .home-link:hover { background: #c73e54; }
    </style>
</head>
<body>
    <div class="error-container">
        <p class="error-code">404</p>
        <p class="error-message">Oops! The page you're looking for doesn't exist.</p>
        <p>It might have been moved, deleted, or you may have typed the URL incorrectly.</p>
        <a href="/" class="home-link">← Back to Home</a>
    </div>
</body>
</html>
```

---

## 6. Environment Requirements

### 6.1 Prerequisites (Install Before You Start)

| Tool | Minimum Version | How to Verify | Install Link |
|------|----------------|---------------|--------------|
| **Terraform** | 1.5.0+ | `terraform -version` | https://developer.hashicorp.com/terraform/downloads |
| **Azure CLI** | 2.50.0+ | `az --version` | https://learn.microsoft.com/en-us/cli/azure/install-azure-cli |
| **Git** | 2.30.0+ | `git --version` | https://git-scm.com/downloads |

### 6.2 Azure Account Setup

1. **Create a Free Azure Account** (if you don't have one):
   - https://azure.microsoft.com/en-us/free/
   - You get **$200 credit for 30 days** + 12 months of free services
   - After that, this project costs ~$5–$10/month

2. **Login via Azure CLI:**
   ```bash
   az login
   az account set --subscription "Your-Subscription-Name"
   ```

3. **Verify your subscription:**
   ```bash
   az account show
   ```

### 6.3 Project Folder Structure

Create this folder structure before you start:

```
corpnet-starter-lab01/
├── README.md
├── main.tf
├── variables.tf
├── outputs.tf
├── providers.tf
├── terraform.tfvars
├── backend.tf
└── assets/
    ├── index.html
    └── error.html
```

### 6.4 File Responsibilities

| File | Purpose |
|------|---------|
| `providers.tf` | Define Azure provider, version constraints, backend config |
| `variables.tf` | Declare all input variables (with descriptions and types) |
| `terraform.tfvars` | Assign actual values to variables |
| `main.tf` | Define all Azure resources |
| `outputs.tf` | Define what values to display after apply |
| `backend.tf` | Configure remote state backend (Azure Storage) |
| `assets/` | Static files to upload to the storage account |

---

## 7. Hints & Pitfalls

> ⚠️ **I will NOT give you the code.** These are conceptual hints to guide your thinking. Struggle with these — that's how you learn.

### Hint 1: Storage Account Name = Globally Unique

> Azure Storage Account names must be **globally unique across ALL of Azure** — not just your subscription. If you try `stcorpnetlab`, someone else in the world might have taken it.
>
> **Think about:** How can you make the name unique without hardcoding random numbers? (Hint: Terraform has a function for generating random strings. Or you could use a unique suffix variable.)
>
> **Common Mistake:** Hardcoding a storage account name and getting a "already exists" error on your second run. Always plan for uniqueness.

### Hint 2: Static Website Hosting is a "Data Source" Feature

> Enabling static website hosting on a Storage Account is **not** a standard resource property. It's a separate configuration that requires a specific Terraform resource type.
>
> **Think about:** Look for a resource that specifically manages the static website settings of a storage account. It's not inside the `azurerm_storage_account` resource block.
>
> **Common Mistake:** Trying to enable static website hosting inside the storage account resource and wondering why the `$web` container isn't created.

### Hint 3: Remote Backend Chicken-and-Egg Problem

> You need a Storage Account to store Terraform state. But you're using Terraform to create that Storage Account. This is a classic **bootstrap problem**.
>
> **Think about:** How do you create the first Storage Account without remote state? (Hint: You might need to run Terraform once with local state, then migrate. Or create the backend storage manually via Azure CLI first.)
>
> **Common Mistake:** Setting up the backend before the storage account exists, then getting a "container not found" error. Plan your bootstrap sequence carefully.

---

## 8. Verification Checklist

After you run `terraform apply`, verify each item below. **Don't skip this — it's how you know your project actually works.**

### ✅ Resource Verification

- [ ] Run `terraform show` — do you see all 6 resources?
- [ ] Open Azure Portal → Resource Groups → `rg-corpnet-lab-eus` — are all resources present?
- [ ] Check that every resource has the **6 mandatory tags**

### ✅ Website Verification

- [ ] Navigate to the Storage Account → Static Website → copy the **Primary endpoint URL**
- [ ] Open the URL in a browser — do you see the TechStart Solutions homepage?
- [ ] Append a non-existent path (e.g., `/nonexistent`) — do you see the 404 error page?
- [ ] Check browser DevTools → Network tab — is the response `200 OK` for index and `404` for missing pages?

### ✅ Load Balancer Verification

- [ ] Navigate to the Load Balancer in Azure Portal
- [ ] Check the **Frontend IP Configuration** — is a Public IP assigned?
- [ ] Check the **Health Probe** — is it configured for HTTP port 80?
- [ ] Check the **Load Balancing Rule** — is TCP 80 mapped correctly?
- [ ] Try accessing the Public IP on port 80 — you should get a timeout (no backend yet), but the LB should respond

### ✅ Terraform State Verification

- [ ] Navigate to the Storage Account → Blob Containers → `tfstate`
- [ ] Do you see a `.tfstate` file?
- [ ] Run `terraform state list` — does it show all your resources?
- [ ] Run `terraform plan` again — does it show **"No changes"**? (Idempotency check)

### ✅ Cost Verification

- [ ] Go to Azure Portal → Cost Management + Billing → Cost Analysis
- [ ] Filter by Resource Group `rg-corpnet-lab-eus`
- [ ] Is the daily cost under **$0.50/day**?

---

## 9. Cost Breakdown (Micro-SKUs)

> 💰 **Target Budget: $5–$10/month**  
> All SKUs are chosen to minimize cost while remaining functional.

| Resource | SKU / Tier | Estimated Monthly Cost | Why This SKU |
|----------|-----------|----------------------|--------------|
| Resource Group | N/A | Free | No cost for the container itself |
| Virtual Network | N/A | Free | VNet itself is free; only data transfer costs |
| Subnet | N/A | Free | Subnets are free |
| Network Security Group | N/A | Free | NSGs are free |
| Storage Account | Standard, LRS | ~$0.02–$0.05 | LRS = cheapest replication; static website feature is free |
| Load Balancer | Basic | Free | Basic LB has **no hourly charge** for the first 5 rules |
| Public IP | Basic, Dynamic | Free | Basic Public IPs are free when assigned to a resource |
| Data Transfer (outbound) | First 5 GB | Free | Azure gives 5 GB free outbound per month |
| **TOTAL** | | **~$0–$1/month** | Well under your $5–$10 budget |

> ⚠️ **Cost Warning:** If you accidentally choose:
> - Standard Load Balancer instead of Basic → ~$18/month
> - Standard Public IP instead of Basic → ~$3.60/month
> - GRS or ZRS replication instead of LRS → 2x–3x storage cost
>
> **Double-check your SKUs before applying!**

---

## 10. Next Labs Preview

> Here's the roadmap for the full series. Each lab builds new skills while keeping costs low.

| Lab | Topic | New Resources | Cost |
|-----|-------|-------------|------|
| **Lab 01** | CorpNet Starter (this lab) | RG, VNet, Subnet, NSG, Storage (Static Web), LB (Basic) | ~$0–$1/mo |
| **Lab 02** | VM + Bastion Host | Linux VM (B1s), Azure Bastion (Developer SKU) | ~$5–$8/mo |
| **Lab 03** | App Gateway + WAF | App Gateway (WAF_v2, Small), SSL/TLS | ~$5–$10/mo |
| **Lab 04** | Traffic Manager | Traffic Manager (Standard), 2x Storage Endpoints | ~$0.50/mo |
| **Lab 05** | Multi-Tier App (Part 1) | Web Tier: App Service (F1 Free), SQL DB (Basic) | ~$5/mo |
| **Lab 06** | Multi-Tier App (Part 2) | App Tier: Function App (Consumption), Queue Storage | ~$1/mo |
| **Lab 07** | Multi-Tier App (Part 3) | Data Tier: Cosmos DB (Serverless), Private Endpoints | ~$2/mo |
| **Lab 08** | Full 3-Tier with LB | VM Scale Set, Internal LB, Auto-scaling | ~$8–$10/mo |
| **Lab 09** | Azure AD (Part 1) | App Registration, Service Principal, RBAC | Free |
| **Lab 10** | Azure AD (Part 2) | Managed Identity, Key Vault, Secret Rotation | ~$0.03/mo |
| **Lab 11** | Azure AD (Part 3) | Conditional Access, MFA, Group-based Access | Free |
| **Lab 12** | Capstone Project | Full CI/CD, Monitoring, Cost Alerts, Governance | ~$10–$15/mo |

> 📌 **Note:** Labs 5–8 focus on multi-tier architecture (your request). Labs 9–11 focus on Azure AD (your request). Each lab is independent — no "must complete Lab 3 to run Lab 4" dependencies.

---

## 🎯 Success Criteria

You have successfully completed this lab when:

1. ✅ You can open a **public URL** in your browser and see the TechStart Solutions website
2. ✅ You can run `terraform plan` and see **"No changes"** (idempotent)
3. ✅ Your Terraform state is stored **remotely** in Azure Storage
4. ✅ All resources have **proper tags** and follow **naming conventions**
5. ✅ Your monthly Azure bill for this project is **under $1**
6. ✅ You can explain to someone else what each resource does and why it exists

---

## 📚 Additional Resources

| Resource | Link | Purpose |
|----------|------|---------|
| Terraform Azure Provider Docs | https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs | Official reference for every resource |
| Azure Pricing Calculator | https://azure.microsoft.com/en-us/pricing/calculator/ | Estimate costs before deploying |
| Terraform Best Practices | https://www.terraform-best-practices.com/ | Naming, structure, state management |
| Azure Free Services | https://azure.microsoft.com/en-us/free/ | What's always free vs. 12-month free |

---

> 🏆 **Remember:** The goal isn't to copy-paste code. The goal is to **understand WHY each resource exists, HOW they connect, and WHAT problem they solve.** Take your time. Break things. Fix them. That's how you learn.
>
> **Good luck, future DevOps engineer!** 🚀

---

*Project designed for self-paced learning. No expensive resources. No hidden dependencies. Just you, Terraform, and Azure.*
