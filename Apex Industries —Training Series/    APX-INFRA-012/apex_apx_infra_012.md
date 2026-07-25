# Apex Industries — Cloud Infrastructure Training Series
## VMSS Autoscale — Metric-Driven Scaling
**Project Code:** `APX-INFRA-012` | **Level:** Beginner+++ | **Frequency:** Used everywhere
**Environment:** Windows + VS Code + PowerShell | Fully self-contained | Cost: ~$0.15/session

---

> **From your Team Lead:** In APX-005/006 you set instances = 2
> — a fixed number, chosen by you, changed manually. Real
> production workloads don't work that way. This ticket adds the
> piece that actually makes a Scale Set "elastic" — rules that
> grow and shrink the instance count automatically, based on real
> load. — *Morgan Chen*

---

## 1. Overview — The New Concept

### What Autoscale Actually Does

You already know how to change `instances` manually and re-run
`terraform apply` (APX-005's Hint 3). Autoscale removes the human
from that loop entirely — a separate resource watches a metric
(like CPU) continuously, and automatically adjusts the instance
count within limits you define, with zero manual intervention.

```
Manual scaling (APX-005/006):
  You notice high load -> you edit instances = 4 -> terraform apply

Autoscale (this project):
  A rule watches average CPU every 5 minutes
  -> CPU > 70%? Add one instance automatically
  -> CPU < 20%? Remove one instance automatically
  -> You never touch Terraform for routine scaling again
```

### The New Resource — azurerm_monitor_autoscale_setting

This single resource type defines the ENTIRE autoscale behavior:
the min/max instance boundaries, and one or more RULES describing
when to scale up or down.

```hcl
resource "azurerm_monitor_autoscale_setting" "autoscale" {
  name                = "${local.name_prefix}-autoscale"
  resource_group_name  = azurerm_resource_group.rg.name
  location               = azurerm_resource_group.rg.location
  target_resource_id       = azurerm_linux_virtual_machine_scale_set.vmss.id

  profile {
    name = "default"

    capacity {
      default = 2
      minimum   = 2
      maximum     = 5
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id   = azurerm_linux_virtual_machine_scale_set.vmss.id
        time_grain              = "PT1M"
        statistic                  = "Average"
        time_window                    = "PT5M"
        time_aggregation                   = "Average"
        operator                               = "GreaterThan"
        threshold                                  = 70
      }
      scale_action {
        direction     = "Increase"
        type            = "ChangeCount"
        value             = "1"
        cooldown            = "PT5M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id   = azurerm_linux_virtual_machine_scale_set.vmss.id
        time_grain              = "PT1M"
        statistic                  = "Average"
        time_window                    = "PT5M"
        time_aggregation                   = "Average"
        operator                               = "LessThan"
        threshold                                  = 20
      }
      scale_action {
        direction     = "Decrease"
        type            = "ChangeCount"
        value             = "1"
        cooldown            = "PT5M"
      }
    }
  }
}
```

**Break down every piece — this is a lot at once, go slowly:**

```hcl
capacity {
  default = 2   # instance count when the rule set first applies
  minimum   = 2   # NEVER scale below this, no matter what
  maximum     = 5   # NEVER scale above this, no matter what
}
```
These three numbers are the SAFETY BOUNDARIES. Even if your scale-up
rule fires repeatedly, Azure will never exceed maximum. This is
what prevents a runaway scaling loop from becoming an unlimited
bill — always set boundaries, never leave autoscale unbounded.

```hcl
rule {
  metric_trigger { ... }   # WHEN does this rule fire?
  scale_action { ... }      # WHAT happens when it fires?
}
```
Every rule has exactly these two parts — a trigger condition and
an action. This project has TWO rules: one that scales UP when
busy, one that scales DOWN when idle. Both watch the same metric
(Percentage CPU) but with opposite thresholds and opposite
directions.

```hcl
metric_trigger {
  metric_name = "Percentage CPU"
  time_grain    = "PT1M"      # check the metric every 1 minute
  time_window       = "PT5M"      # average over the last 5 minutes
  time_aggregation      = "Average"
  operator                  = "GreaterThan"
  threshold                     = 70
}
```
Read this as a sentence: "Every 1 minute, look at the average CPU
over the last 5 minutes. If that average is greater than 70%..."
time_grain and time_window are different — grain is how OFTEN
you check, window is how MUCH history you average over each check.

```hcl
scale_action {
  direction = "Increase"
  type        = "ChangeCount"
  value         = "1"
  cooldown        = "PT5M"
}
```
"...then increase the instance count by 1, and wait at least 5
minutes before considering another scale action." cooldown is
critical — without it, a sustained high-load period could trigger
rapid, repeated scale-ups faster than new instances can even boot
and start handling traffic.

### What You Are Building

```
VMSS (reused exactly from APX-005/006)
  Autoscale Setting:
    min 2, max 5, default 2
    Rule 1: CPU > 70% for 5 min avg -> add 1 instance
    Rule 2: CPU < 20% for 5 min avg -> remove 1 instance
    |
    v
  Load a CPU stress test onto one instance -> watch the
  instance count grow automatically, with zero terraform apply
```

### Reused Without Guidance
Everything from APX-006 (VMSS, Load Balancer, boot script) — build
this entire foundation from memory. This project's only new piece
is the azurerm_monitor_autoscale_setting resource itself.

---

## 2. Naming + Tags

| Resource | Name |
|---|---|
| Resource Group | `apx-dev-012-rg` |
| VMSS | `apx-dev-012-vmss` |
| Autoscale Setting | `apx-dev-012-autoscale` |

```hcl
# terraform.tfvars
org_prefix              = "apx"
environment             = "dev"
azure_location          = "East US"
resource_group_name     = "apx-dev-012-rg"
admin_username             = "apxadmin"
autoscale_min_instances       = 2
autoscale_max_instances          = 5
autoscale_default_instances         = 2
```

---

## 3. Core Components

### Component 1 — VMSS + Load Balancer (Build From Memory, APX-006 Pattern)

Full stack: RG, networking, VMSS with boot script serving a simple
page, Load Balancer with backend pool connected via
load_balancer_backend_address_pool_ids inside the VMSS's
network_interface block. No new guidance.

### Component 2 — Autoscale Setting (New — Full Detail Above)

Build exactly as shown in the Overview section, using variables
instead of hardcoded numbers for the capacity block:

```hcl
capacity {
  default = var.autoscale_default_instances
  minimum   = var.autoscale_min_instances
  maximum     = var.autoscale_max_instances
}
```

### Component 3 — Variables + Outputs

```hcl
variable "autoscale_min_instances" {
  type = number
  validation {
    condition     = var.autoscale_min_instances >= 1
    error_message = "autoscale_min_instances must be at least 1."
  }
}

variable "autoscale_max_instances" {
  type = number
  validation {
    condition     = var.autoscale_max_instances <= 10
    error_message = "autoscale_max_instances must be 10 or fewer for this lab (cost control)."
  }
}
```

Outputs:
```
vmss_name
autoscale_setting_id
lb_public_ip
```

---

## 4. Hints

**Hint 1 — Autoscale evaluation takes real time, don't expect
instant results:** even after triggering high CPU load, the
time_window = "PT5M" means Azure needs 5 minutes of sustained
high average before the rule fires — plus the time_grain
checking interval. Budget 10-15 minutes of patience to actually
SEE a scale-up happen, not seconds.

**Hint 2 — PT1M, PT5M are the same ISO 8601 duration format
from Application Gateway and Metric Alerts back in MRB-009/NCT-009:**
PT = "period of time," followed by a number and a unit (M for
minutes, H for hours). This format keeps showing up across
different Azure resources — worth recognizing it on sight by now.

**Hint 3 — Scale-DOWN rules need their own cooldown too, and it's
easy to forget:** if both rules share too short a cooldown, you
can get "flapping" — scaling up, then immediately back down, then
up again — as the average crosses your threshold repeatedly. A
5-minute cooldown on both directions (as shown above) is a
reasonable starting point to avoid this.

---

## 5. Workflow (PowerShell) — Including a Real Triggered Scale-Up

```powershell
cd C:\Projects\apx-infra-012

terraform init; terraform validate; terraform fmt
terraform plan -out=tfplan
terraform apply tfplan

# Confirm starting instance count
az vmss list-instances --resource-group apx-dev-012-rg --name apx-dev-012-vmss --output table
# Expected: 2 instances (the "default" from capacity block)

# Verify the autoscale setting exists and shows your rules
az monitor autoscale show `
  --resource-group apx-dev-012-rg `
  --name apx-dev-012-autoscale `
  --output table

# TRIGGER REAL CPU LOAD on one instance to force a scale-up
$instanceIds = az vmss list-instances --resource-group apx-dev-012-rg --name apx-dev-012-vmss --query "[0].instanceId" -o tsv
az vmss run-command invoke `
  --resource-group apx-dev-012-rg `
  --name apx-dev-012-vmss `
  --instance-id $instanceIds `
  --command-id RunShellScript `
  --scripts "yes > /dev/null &"

# Wait ~10-15 minutes, then check instance count again
az vmss list-instances --resource-group apx-dev-012-rg --name apx-dev-012-vmss --output table
# Expected: MORE than 2 instances now -- proof autoscale actually fired

# Check the autoscale history to see exactly when/why it scaled
az monitor autoscale-settings list-history `
  --resource-group apx-dev-012-rg `
  --name apx-dev-012-autoscale `
  --output table

terraform destroy
```

**What you should see:** the instance count genuinely grow, with
no terraform apply run in between — proof that the autoscale
rule fired independently based on the real CPU metric, exactly as
configured.

---

## 6. Checklist

```
[ ] target_resource_id points at the VMSS
[ ] capacity block has default/minimum/maximum using variables
[ ] Two rules present: one Increase, one Decrease
[ ] Both rules use ISO 8601 duration format correctly (PT1M, PT5M)
[ ] Both scale_action blocks have a cooldown set
[ ] autoscale_max_instances has a validation{} block (cost control)
[ ] CPU load triggered on an instance via run-command
[ ] Instance count genuinely increased without a manual terraform apply
[ ] Autoscale history confirms the scale event via CLI
[ ] terraform destroy completed
```

---

## 7. Cost
Same as APX-006's baseline (~$0.50/session) plus the cost of any
ADDITIONAL instances autoscale creates during your test — capped
at maximum = 5 by the safety boundary, so worst case is roughly
2.5x the base VMSS cost for the duration of the test. **A focused
2-3 hour session, including the scale-up test: under $1.**

## Series Status
```
APX-011   Azure Files + NAT Gateway
APX-012   VMSS Autoscale — real, triggered scaling event  <- THIS PROJECT
APX-013   Governance Trio — Resource Locks, Cost Budgets, Policy
```

*Apex Industries — Cloud Platform Engineering | Training Series*
