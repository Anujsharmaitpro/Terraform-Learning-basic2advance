# Terraform + Azure Monitor — Action Groups and Metric Alerts
## Deep-Dive Learning Guide — Day 23 / 28 Days of Easy Terraform
### Beginner-First Edition | PowerShell Throughout

---

## Before You Start

This is Day 23. The topic is proactive monitoring — building Azure
Monitor action groups and metric alerts through Terraform, so a VM's
high CPU usage or resource strain automatically triggers a
notification rather than someone noticing an outage after the fact.

One correction needs to be made upfront, because it changes what the
second alert in this project actually does: the video builds what it
calls a "low disk space" alert using the metric name **Available
Memory Bytes**. That metric measures available **RAM**, not disk
space — the two are unrelated Azure resources. As configured, the
video's second alert genuinely fires on low memory, not low disk.
This isn't a minor naming quibble; if you deployed this exact
configuration expecting a disk-space warning, you'd get no warning at
all when a disk actually filled up, and you'd get an unexpected memory
alert instead. Sections 7 and 8 explain the correction and what a
real disk-space alert requires.

---

## Table of Contents

1. What Is Azure Monitor? (Action Groups and Metric Alerts, Plain English)
2. The Project's Starting Point — Recap of the VM Scaffold
3. The Action Group — Building It Correctly
4. Anatomy of a Metric Alert Resource
5. ISO 8601 Durations — Frequency and Window Size
6. Building the CPU Alert
7. A Necessary Correction: This Isn't a Disk-Space Alert
8. What a Genuine Free-Disk-Space Alert Actually Requires
9. Correcting the `dimension` Block's Purpose
10. Reducing Duplication — `for_each` Instead of Copy-Paste
11. Running the Deployment
12. Simulating CPU Load — And Clarifying PowerShell vs Bash Here
13. Verifying the Alert Fired
14. The Assignment — Testing a Genuine Disk-Space Condition
15. Complete Corrected Working Code
16. Common Mistakes
17. Practice Exercises
18. Summary Reference

---

## 1. What Is Azure Monitor? (Action Groups and Metric Alerts, Plain English)

**Azure Monitor** is Azure's built-in observability service — it
continuously collects metrics (CPU usage, network throughput, memory
availability, and more) from your resources without you installing
anything extra, for most platform-level metrics.

Two pieces matter for this project:

- **Action Group** — defines *what happens* when something goes wrong:
  send an email, call a webhook, trigger an Azure Function, page
  someone via SMS. It's the notification channel, decoupled from any
  specific condition.
- **Metric Alert** — defines *the condition* that should trigger an
  action group: "when average CPU exceeds 60% over 5 minutes," for example.

You build the action group once, then reference it from as many
metric alerts as you need — the same one-definition-many-uses pattern
that motivated Day 20's module discussion, just applied here to
monitoring configuration instead of infrastructure resources.

---

## 2. The Project's Starting Point — Recap of the VM Scaffold

The video reuses the VM, virtual network, subnet, NSG, public IP, and
NGINX-via-`remote-exec` setup built in an earlier day (Day 19's
provisioners project, specifically). If any of that scaffold is
unfamiliar, it's fully covered there — this guide picks up from "the
VM already exists" and focuses on the new monitoring resources.

Worth flagging in passing, since it's directly relevant to Section 12:
that earlier NSG allowed SSH from any source IP (`source_address_prefix
= "*"`), which Day 19's own guide already noted as a hardening item
worth fixing before anything resembling production use — the same
caution applies here, since this project still uses that same VM.

---

## 3. The Action Group — Building It Correctly

```hcl
resource "azurerm_monitor_action_group" "main" {
  name                = "vm-alerts-action-group"
  resource_group_name = azurerm_resource_group.rg.name
  short_name          = "vmalerts"

  email_receiver {
    name          = "send-to-admin"
    email_address = var.alert_email
  }
}
```

- `short_name` — a required field (max 12 characters) used in SMS/push
  notification text where space is limited; it's easy to overlook
  since it isn't the display name shown in the Portal's main view
- `email_receiver` — one of several receiver types available
  (`sms_receiver`, `webhook_receiver`, `azure_function_receiver`,
  `logic_app_receiver`, and others); a single action group can contain
  multiple receivers of different types simultaneously, so one alert
  firing can simultaneously email a team and call a webhook

**`variables.tf`**
```hcl
variable "alert_email" {
  type        = string
  description = "Email address to receive monitoring alerts"
}
```

Worth a small but real correction to how the video handles this: it
hardcodes a personal email address directly as the variable's
`default` value, in a file that would typically be committed to a
Git repository. An email address isn't a secret in the way a password
is, but it's still personal data that shouldn't be baked into shared,
version-controlled code by default — supply it at apply time instead:

```powershell
$env:TF_VAR_alert_email = "your-email@example.com"
terraform apply --auto-approve
```

---

## 4. Anatomy of a Metric Alert Resource

```hcl
resource "azurerm_monitor_metric_alert" "cpu_alert" {
  name                = "high-cpu-alert"
  resource_group_name = azurerm_resource_group.rg.name
  scopes              = [azurerm_linux_virtual_machine.vm.id]
  description         = "Triggers when average CPU exceeds 60% for 5 minutes"

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 60
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}
```

Note the correct resource name is **`azurerm_monitor_metric_alert`**
— "metric," not "matrix." This matters beyond pronunciation: if you
type `azurerm_monitor_matrix_alert` into a `.tf` file expecting it to
work, Terraform will simply report no such resource type exists.

Field by field:

- `scopes` — a list of resource IDs this alert monitors. Despite being
  plural (supporting multiple resources under one alert for some
  resource types), this project scopes it to a single VM
- `criteria.metric_namespace` — which Azure service's metrics to look
  in; `Microsoft.Compute/virtualMachines` for VM-level platform metrics
- `criteria.metric_name` — the exact metric name, case-sensitive and
  must match Azure's own naming precisely (`"Percentage CPU"`, not
  `"CPU Percentage"` or `"cpu_percent"`) — get this wrong and the
  resource still creates successfully, but silently monitors nothing
  meaningful, since Terraform doesn't validate metric names exist
  against the Azure Monitor metrics catalog at plan time
- `aggregation` — how multiple data points within the evaluation
  window are combined: `Average`, `Total`, `Maximum`, `Minimum`, or `Count`
- `operator` — the comparison: `GreaterThan`, `LessThan`,
  `GreaterThanOrEqual`, `LessThanOrEqual`, `Equal`
- `threshold` — the numeric value being compared against
- `action.action_group_id` — links this criteria back to the
  notification channel built in Section 3

---

## 5. ISO 8601 Durations — Frequency and Window Size

The video correctly notes the "5 minutes" evaluation window is a
default it didn't explicitly set. Worth making that default visible
rather than leaving it implicit, and connecting it to a pattern you've
already seen: this is the same ISO 8601 duration format Day 14's
autoscale rules used (`PT5M`, `PT1M`).

```hcl
resource "azurerm_monitor_metric_alert" "cpu_alert" {
  # ...
  frequency   = "PT1M"   # how often the alert rule evaluates (every 1 minute)
  window_size = "PT5M"   # the time range each evaluation looks back over (5 minutes)
  severity    = 3        # 0 = Critical, 4 = Verbose; 3 is a reasonable mid-level default
}
```

Setting these explicitly, rather than relying on unstated defaults, is
worth doing even when the default happens to match what you want —
someone reading the code later shouldn't need to know Azure Monitor's
current default to understand what the alert actually does.

---

## 6. Building the CPU Alert

Combining Sections 3-5, the complete, correctly-named CPU alert:

```hcl
resource "azurerm_monitor_metric_alert" "cpu_alert" {
  name                = "high-cpu-alert"
  resource_group_name = azurerm_resource_group.rg.name
  scopes              = [azurerm_linux_virtual_machine.vm.id]
  description         = "Triggers when average CPU exceeds 60% over 5 minutes"
  severity            = 3
  frequency           = "PT1M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 60
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}
```

---

## 7. A Necessary Correction: This Isn't a Disk-Space Alert

The video's second alert uses `metric_name = "Available Memory Bytes"`
and describes it, in narration, as a low-disk-space warning. This is
worth stating plainly rather than passing over: **Available Memory
Bytes is a RAM metric.** It reports how much physical memory is free
on the VM — completely unrelated to how much storage space remains on
a disk. A VM can have 95% of its disk full while simultaneously
showing plenty of available memory, and vice versa; these are two
independent resources with independent metrics.

As literally configured in the source video, the resulting alert
genuinely does something useful — it warns when the VM is running low
on RAM — but it does not do what the narration claims it does, and
would not fire if disk space actually filled up.

The corrected, honestly-labeled version of what the video actually built:

```hcl
resource "azurerm_monitor_metric_alert" "low_memory_alert" {
  name                = "low-available-memory-alert"
  resource_group_name = azurerm_resource_group.rg.name
  scopes              = [azurerm_linux_virtual_machine.vm.id]
  description         = "Triggers when available memory drops below threshold"
  severity            = 3
  frequency           = "PT1M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Available Memory Bytes"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = var.low_memory_threshold_bytes
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}
```

Note also that `threshold` for a bytes-based metric needs to be
expressed in **bytes**, not a percentage — unlike the CPU alert's
`60` meaning "60%," a memory-bytes threshold like `1073741824` means
"1 GiB." The video's narration frames this alert as a percentage
("20% free disk space"), which doesn't match how a bytes-denominated
metric's threshold actually works either — another reason the
metric-name and threshold-semantics mismatch here is worth catching
rather than copying as-is.

---

## 8. What a Genuine Free-Disk-Space Alert Actually Requires

If your actual goal is "alert me when a VM's disk is nearly full," it
takes more than swapping in a different `metric_name` string, because
**disk-space-percentage-free is not exposed as a simple platform-level
metric** the way CPU percentage is. Azure's platform-level metrics for
`Microsoft.Compute/virtualMachines` include things like Disk Read/Write
Bytes, Disk IOPS, and OS Disk Bandwidth/IOPS Consumed Percentage — but
not a direct "how full is the filesystem" number, because that number
depends on what's actually written *inside* the guest operating
system's filesystem, which the Azure platform doesn't inspect by default.

To get genuine free-disk-space monitoring, you need one of these approaches:

**Option A — Azure Monitor Agent (AMA) with a guest-level performance
counter.** Install the Azure Monitor Agent extension on the VM, which
then reports OS-level performance counters (on Linux, typically via
`Logical Disk` / filesystem counters) into a Log Analytics workspace.
You then build an alert against a **Log Analytics query** (a Kusto
query alert), not a simple platform metric alert:

```hcl
resource "azurerm_log_analytics_workspace" "law" {
  name                = "day23-law"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "PerGB2018"
}

resource "azurerm_virtual_machine_extension" "ama" {
  name                       = "AzureMonitorLinuxAgent"
  virtual_machine_id         = azurerm_linux_virtual_machine.vm.id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorLinuxAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "low_disk" {
  name                = "low-disk-space-alert"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  scopes              = [azurerm_log_analytics_workspace.law.id]
  severity            = 2

  criteria {
    query                   = <<-QUERY
      Perf
      | where ObjectName == "Logical Disk" and CounterName == "% Free Space"
      | where InstanceName == "/"
      | summarize AvgFreeSpace = avg(CounterValue) by bin(TimeGenerated, 5m)
      | where AvgFreeSpace < 20
    QUERY
    time_aggregation_method = "Average"
    threshold               = 20
    operator                = "LessThan"
  }

  action {
    action_groups = [azurerm_monitor_action_group.main.id]
  }
}
```

This is genuinely more involved than the simple metric alert pattern
used for CPU, which is precisely why the video's shortcut of reusing
the same simple pattern with a different metric name is understandable
as a demo simplification, but shouldn't be mistaken for a working
solution to the stated problem.

**Option B — a simpler proxy, if guest-level monitoring is more than
you need right now:** monitor **OS Disk Bandwidth/IOPS Consumed
Percentage** as a rough indirect signal of disk pressure, using the
exact same simple `azurerm_monitor_metric_alert` pattern from Section
6. This doesn't tell you *how full* the disk is, but it can surface
when disk I/O is becoming a bottleneck — a genuinely available
platform-level metric, just measuring something different from "free
space percentage."

For a learning project, Option B (or even just being upfront that the
video's alert monitors memory, as corrected in Section 7) is
reasonable. For production disk-space monitoring, Option A is the
real answer.

---

## 9. Correcting the `dimension` Block's Purpose

The video removes the `dimension` block from the copied documentation
example and describes it as "specific to the webhook." That's not
accurate, and worth correcting since it could lead you to remove a
block you actually need in a different scenario: `dimension` filters
which specific sub-resource instances a metric criteria applies to —
for example, on a resource with multiple network interfaces or
multiple disks, you can scope the alert to just one specific NIC or
disk by its dimension value, rather than aggregating across all of
them. It has nothing to do with receiver type (email vs webhook); it
was correctly omitted here simply because this project's metrics
(CPU, memory) don't have a meaningful per-instance dimension to filter
on for a single VM.

---

## 10. Reducing Duplication — `for_each` Instead of Copy-Paste

The video builds the second alert by duplicating the entire first
alert block and manually editing several fields. This is exactly the
repetition problem Day 8's `for_each` and Day 20's modules both exist
to solve. A cleaner approach for two structurally similar alerts:

```hcl
locals {
  alerts = {
    high_cpu = {
      name        = "high-cpu-alert"
      description = "Average CPU above 60% for 5 minutes"
      metric_name = "Percentage CPU"
      operator    = "GreaterThan"
      threshold   = 60
    }
    low_memory = {
      name        = "low-available-memory-alert"
      description = "Available memory below threshold for 5 minutes"
      metric_name = "Available Memory Bytes"
      operator    = "LessThan"
      threshold   = 1073741824   # 1 GiB in bytes
    }
  }
}

resource "azurerm_monitor_metric_alert" "vm_alerts" {
  for_each = local.alerts

  name                = each.value.name
  resource_group_name = azurerm_resource_group.rg.name
  scopes              = [azurerm_linux_virtual_machine.vm.id]
  description         = each.value.description
  severity            = 3
  frequency           = "PT1M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = each.value.metric_name
    aggregation      = "Average"
    operator         = each.value.operator
    threshold        = each.value.threshold
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}
```

Adding a third alert now means adding one entry to the `local.alerts`
map — no copy-pasted resource block, no risk of forgetting to update
one field in the duplicate the way the video's manual copy required
careful, mistake-prone editing.

---

## 11. Running the Deployment

```powershell
Set-Location "C:\projects\day23"

az login
$env:ARM_CLIENT_ID       = "your-client-id"
$env:ARM_CLIENT_SECRET   = "your-client-secret"
$env:ARM_TENANT_ID       = "your-tenant-id"
$env:ARM_SUBSCRIPTION_ID = "your-subscription-id"
$env:TF_VAR_alert_email  = "your-email@example.com"

terraform init
terraform validate
terraform plan
terraform apply --auto-approve
```

---

## 12. Simulating CPU Load — And Clarifying PowerShell vs Bash Here

This is a point worth being explicit about rather than blurring: the
commands you run **on your own Windows machine** to connect to Azure
and drive Terraform belong in PowerShell, as shown throughout this
guide. But once you SSH into the VM, you are inside an **Ubuntu Linux
shell** — the stress-testing commands themselves must be Bash, because
that's the operating system actually running on the target VM.
Relabeling Linux-only commands as "PowerShell" wouldn't make them work
differently; PowerShell is a shell you can run *on* Linux in some
setups, but the VM here is configured with a standard Bash login
shell, and the stress tool itself is a Linux utility with no Windows
equivalent being invoked here.

**PowerShell — from your own machine, connecting to the VM:**
```powershell
$vmIp = terraform output -raw vm_public_ip
ssh azureuser@$vmIp
```

**Bash — once connected, inside the VM itself:**
```bash
sudo apt-get update
sudo apt-get install -y stress
stress --cpu 6 --timeout 300
```

`--cpu 6` spins up 6 worker processes each pegging a CPU core at 100%;
`--timeout 300` stops the test automatically after 300 seconds (5
minutes) rather than requiring you to remember to kill it manually.

---

## 13. Verifying the Alert Fired

**In the Azure Portal:** Monitor → Alerts, filtered to your resource
group, shows fired and resolved alert instances with a timestamp,
the metric value that triggered it, and a link to investigate further.

**PowerShell — checking alert history via Azure CLI, without leaving
your terminal:**
```powershell
az monitor metrics alert list --resource-group "day23-rg" --output table
```

**PowerShell — querying the actual metric values directly, useful for
confirming a metric name exists and is reporting data before you even
build an alert around it:**
```powershell
$vmId = az vm show --resource-group "day23-rg" --name "demo-vm" --query "id" -o tsv

az monitor metrics list `
  --resource $vmId `
  --metric "Percentage CPU" `
  --interval PT1M `
  --output table
```

Running this last command before building an alert is a genuinely
useful habit — it would have immediately surfaced that "Available
Memory Bytes" reports memory values, not a disk-space percentage,
rather than that mismatch only becoming apparent by comparing the
metric's actual behavior against the narrated intent.

---

## 14. The Assignment — Testing a Genuine Disk-Space Condition

The video leaves disk-space testing as an exercise, suggesting filling
a disk with large files. Worth pairing this with Section 8's
correction: testing "disk space" against the configuration as
literally written in the source video will not produce a disk-related
alert at all, since that alert is actually watching memory. To test
disk space meaningfully, you'd first need to implement Section 8's
Option A or B, then test with something like:

```bash
# Inside the VM (Bash) — deliberately consume disk space for testing
fallocate -l 5G /tmp/testfile.img
df -h /
# Clean up afterward:
rm /tmp/testfile.img
```

To test the memory alert that the video's configuration *actually*
implements, a memory-stress tool serves the purpose instead:
```bash
stress --vm 2 --vm-bytes 1G --timeout 300
```

---

## 15. Complete Corrected Working Code

**`monitor.tf`**
```hcl
resource "azurerm_monitor_action_group" "main" {
  name                = "vm-alerts-action-group"
  resource_group_name = azurerm_resource_group.rg.name
  short_name          = "vmalerts"

  email_receiver {
    name          = "send-to-admin"
    email_address = var.alert_email
  }
}

locals {
  alerts = {
    high_cpu = {
      name        = "high-cpu-alert"
      description = "Average CPU above 60% for 5 minutes"
      metric_name = "Percentage CPU"
      operator    = "GreaterThan"
      threshold   = 60
    }
    low_memory = {
      name        = "low-available-memory-alert"
      description = "Available memory below 1 GiB for 5 minutes"
      metric_name = "Available Memory Bytes"
      operator    = "LessThan"
      threshold   = 1073741824
    }
  }
}

resource "azurerm_monitor_metric_alert" "vm_alerts" {
  for_each = local.alerts

  name                = each.value.name
  resource_group_name = azurerm_resource_group.rg.name
  scopes              = [azurerm_linux_virtual_machine.vm.id]
  description         = each.value.description
  severity            = 3
  frequency           = "PT1M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = each.value.metric_name
    aggregation      = "Average"
    operator         = each.value.operator
    threshold        = each.value.threshold
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}
```

**`variables.tf`**
```hcl
variable "alert_email" {
  type        = string
  description = "Email address to receive monitoring alerts"
}
```

**`outputs.tf`**
```hcl
output "vm_public_ip" {
  value = azurerm_public_ip.vm_ip.ip_address
}

output "action_group_id" {
  value = azurerm_monitor_action_group.main.id
}
```

---

## 16. Common Mistakes

**Mistake 1 — Trusting a metric name without verifying it against
Azure's actual metrics catalog.** As Section 7 covers directly,
`"Available Memory Bytes"` sounds disk-related in casual conversation
but is a RAM metric. Terraform won't catch a semantically wrong (but
syntactically valid) metric name at plan time — use
`az monitor metrics list` (Section 13) to confirm what a metric
actually measures before building an alert around it.

**Mistake 2 — Mismatching threshold units and metric units.** A
percentage-based metric (`Percentage CPU`) takes a threshold like
`60`. A bytes-based metric (`Available Memory Bytes`) needs a
byte-count threshold like `1073741824`, not a percentage.

**Mistake 3 — Hardcoding a personal email address as a variable
default in committed code.** Supply it at apply time via `TF_VAR_`
instead (Section 3).

**Mistake 4 — Copy-pasting a resource block for a second, similar
alert instead of parameterizing with `for_each`.** Section 10 shows
the cleaner alternative — one resource block, a map of differences.

**Mistake 5 — Assuming disk-space-percentage-free is a simple platform
metric like CPU.** It generally requires guest-level monitoring (Azure
Monitor Agent + Log Analytics query alert), not a simple
`azurerm_monitor_metric_alert` — Section 8 covers the actual
requirements.

---

## 17. Practice Exercises

**Exercise 1** — Without looking back at Section 7, explain in your
own words why an alert configured with `metric_name = "Available
Memory Bytes"` and described as "low disk space" is a factual
mismatch, and what it actually monitors.

*Answer:* "Available Memory Bytes" reports free RAM, not free disk
storage — these are two independent hardware resources with
independent Azure Monitor metrics. As literally configured, this alert
fires on low memory, and would give no warning if disk space filled up.

**Exercise 2** — Add a third alert to the `for_each`-based
configuration from Section 10 that fires when average network-out
traffic exceeds 100 MB over the evaluation window, without duplicating
the `azurerm_monitor_metric_alert` resource block.

*Answer:* Add one entry to `local.alerts`:
```hcl
high_network_out = {
  name        = "high-network-out-alert"
  description = "Network out exceeds 100MB over 5 minutes"
  metric_name = "Network Out Total"
  operator    = "GreaterThan"
  threshold   = 104857600   # 100 MB in bytes
}
```
No changes to the `resource` block itself are needed — the `for_each`
map already generates a new alert resource from this new entry
automatically.

**Exercise 3** — A metric alert deploys successfully with `terraform
apply` and shows no errors, but never fires even under conditions that
should clearly trigger it. What are two possible causes worth checking
first, based on this guide?

*Answer:* (1) The `metric_name` string might not match Azure's actual
metric catalog exactly (case-sensitive, exact wording) — verify with
`az monitor metrics list` as shown in Section 13. (2) The
`threshold`'s units might not match the metric's actual unit (a
percentage threshold against a bytes-based metric, or vice versa) —
Section 7's correction is exactly this class of mismatch.

---

## 18. Summary Reference

Action groups (`azurerm_monitor_action_group`) define notification
channels; metric alerts (`azurerm_monitor_metric_alert` — "metric,"
not "matrix") define the conditions that trigger them, referencing an
action group by ID.

Metric alert criteria requires an exact, case-sensitive metric name
from Azure's own catalog — Terraform does not validate this against
Azure's metrics list at plan time, so a wrong-but-plausible-sounding
name deploys without error while silently monitoring the wrong thing,
exactly as happened with "Available Memory Bytes" being used for what
was intended as a disk-space check.

Threshold units must match the metric's own unit — percentage metrics
take percentage thresholds; bytes-based metrics need byte-count thresholds.

Genuine free-disk-space monitoring requires guest-level telemetry
(Azure Monitor Agent feeding a Log Analytics workspace, queried via a
scheduled query rule alert), not a simple platform metric alert —
disk-space-percentage-free isn't exposed as a basic platform metric
the way CPU percentage is.

`dimension` blocks filter a metric to a specific sub-resource instance
(like one disk among several), unrelated to notification receiver type.

Repetitive, structurally similar alerts are a good `for_each`
candidate — a map of differences plus one resource block, rather than
duplicated resource blocks edited by hand.

---

*Guide covers: Azure Monitor action groups and metric alerts,
azurerm_monitor_action_group and email_receiver, azurerm_monitor_metric_alert
(correct resource name versus a common mispronunciation), metric alert
anatomy (scopes, criteria, metric_namespace, metric_name, aggregation,
operator, threshold, action), ISO 8601 duration format for frequency
and window_size (callback to Day 14's autoscale timers), severity
levels, a substantive correction identifying "Available Memory Bytes"
as a RAM metric rather than a disk-space metric, threshold-unit
matching between percentage and bytes-based metrics, what genuine
free-disk-space monitoring actually requires (Azure Monitor Agent,
Log Analytics workspace, azurerm_monitor_scheduled_query_rules_alert_v2,
Kusto query criteria), correcting the purpose of the dimension block
(sub-resource filtering, not receiver-type-specific), reducing alert
duplication with for_each and a locals map (callback to Day 8 and Day
20), az monitor metrics list for verifying metric names and values
before building alerts, the PowerShell-versus-Bash distinction between
local machine commands and remote Linux VM commands, the stress
utility for CPU and memory load testing, and az monitor metrics alert
list for checking alert history via PowerShell.*
