# Terraform Provisioners — local-exec, remote-exec, and file
## Deep-Dive Learning Guide — Day 19 / 28 Days of Easy Terraform
### Beginner-First Edition | PowerShell Throughout

---

## Before You Start

This is Day 19. You've now covered fundamentals, expressions and
functions, data sources, and five mini projects (VMSS, VNet peering,
Entra ID, App Service, Azure Functions).

Today's topic is **provisioners** — a feature that lets Terraform run
scripts and commands as a side effect of creating a resource. I want
to be direct about something up front, because the source material for
this video says it clearly and it's worth repeating rather than
softening: **HashiCorp's own documentation states provisioners are a
last resort.** This isn't a minor caveat — it's the single most
important thing to understand before using them. This guide explains
provisioners fully, but also spends real time on *why* they're
discouraged and what you should reach for first instead.

---

## Table of Contents

1. What Is a Provisioner? (Plain-English Definition)
2. Why HashiCorp Discourages Provisioners — Read This Before Using Any of Them
3. The Three Provisioner Types — Overview
4. `local-exec` — Running Commands on Your Own Machine
5. `remote-exec` — Running Commands on the Target Resource
6. `file` — Copying Files to the Target Resource
7. The `null_resource` — A Resource That Isn't a Resource
8. The `connection` Block — Required for remote-exec and file
9. `depends_on` and Provisioner Ordering
10. The Preferred Alternatives to Provisioners
11. Building the Demo — Starting Point (Recap of Prior-Day Resources)
12. Step 1 — `local-exec`: Logging a Deployment Timestamp
13. Step 2 — `remote-exec`: Installing and Starting NGINX
14. Step 3 — `file`: Copying a Config File to the VM
15. Running the Deployment and Verifying Each Provisioner
16. The Instructor's HTTPS Confusion — What Actually Happened
17. The Assignment — A Second Timestamp File on Completion
18. The Complete Working Code — All Files
19. Common Mistakes and Corrections
20. Practice Exercises
21. Summary Reference

---

## 1. What Is a Provisioner? (Plain-English Definition)

A **provisioner** is a block inside a Terraform resource that runs a
script or command as a side effect of that resource being created (or,
less commonly, destroyed). It's Terraform stepping outside its normal
job — declaring desired infrastructure state — and instead executing
an imperative action, like "run this shell command right now."

Three kinds exist:

- **local-exec** — runs a command on the machine where you're running
  `terraform apply` (your laptop, or a CI/CD runner)
- **remote-exec** — runs a command on the resource Terraform just
  created (a VM, typically, over SSH or WinRM)
- **file** — copies a file or inline content from your machine to the
  resource Terraform just created

---

## 2. Why HashiCorp Discourages Provisioners — Read This Before Using Any of Them

This is not me adding caution for its own sake — it's directly stated
in HashiCorp's official Terraform documentation, and the source video
for this guide says the same thing. The reasoning is worth
understanding, not just accepting:

**Provisioners break Terraform's declarative model.** Terraform's core
value proposition is that it calculates the difference between your
desired state and the actual state, then reconciles it. A provisioner
is an imperative script — Terraform has no visibility into what it
actually did, whether it's idempotent (safe to re-run), or whether it
partially succeeded. If a `remote-exec` script fails halfway through,
Terraform generally doesn't know how to cleanly roll that back.

**They introduce a hard runtime dependency.** `remote-exec` and `file`
need network connectivity to the target resource *at apply time*. If
your VM isn't reachable yet (still booting, NSG rule not yet
propagated, SSH daemon not started), the provisioner fails and your
`apply` fails with it — even though the resource itself was created
successfully.

**They can silently mask configuration drift.** Because provisioners
run once at creation time, running `terraform apply` again later
generally does *not* re-run them (unless you force it) — so if
something on the VM changes afterward, Terraform's state has no idea
and no mechanism to fix it. Compare this to `cloud-init`/custom data,
which is baked into the VM image at boot and is far more visible and
reproducible.

**Security surface.** Storing SSH private keys or WinRM credentials in
your Terraform configuration (even referenced via file paths) adds a
credential-handling responsibility that platform-native alternatives
(managed identities, cloud-init) don't require.

None of this means provisioners are forbidden — they exist for a
reason, and this guide covers them fully. But treat them the way the
official guidance frames it: **the tool you reach for only after
confirming there's no cloud-native alternative**, not a default choice.

---

## 3. The Three Provisioner Types — Overview

| Provisioner | Runs where | Needs `connection`? | Typical use |
|---|---|---|---|
| `local-exec` | Your machine (where `terraform apply` runs) | No | Logging, calling a local script, triggering an external API |
| `remote-exec` | The target resource (e.g. a VM) | Yes | Installing packages, starting services |
| `file` | Copies from local machine to target resource | Yes | Pushing config files, small scripts, certificates |

`local-exec` only requires a `command` argument. `remote-exec` and
`file` both require a `connection` block, because they need to
establish SSH (Linux) or WinRM (Windows) access to the target.

---

## 4. `local-exec` — Running Commands on Your Own Machine

### Syntax

```hcl
provisioner "local-exec" {
  command = "echo hello"
}
```

`command` is the only required argument. Optional arguments include
`working_dir`, `interpreter`, and `environment`.

### Where it runs

`local-exec` executes on whatever machine is running `terraform
apply` — your laptop during learning, or a build agent/runner in a
CI/CD pipeline. It has no awareness of the resource's own operating
system; it's tied to the Terraform *process's* environment, not the
resource being created.

### PowerShell note — the default shell matters

On Windows, Terraform's `local-exec` provisioner defaults to running
commands through `cmd.exe`, not PowerShell. If you want PowerShell
syntax and cmdlets specifically, set the `interpreter` explicitly:

```hcl
provisioner "local-exec" {
  interpreter = ["PowerShell", "-Command"]
  command     = "Write-Output \"Deployment started at $(Get-Date)\" | Out-File deployment-log.txt"
}
```

Without an explicit `interpreter`, Linux-style commands (as used in
the original video, on macOS/Linux) will not work as-is on a Windows
machine — this is a real platform difference worth being explicit
about, since the source material was recorded on macOS.

---

## 5. `remote-exec` — Running Commands on the Target Resource

### Syntax

```hcl
provisioner "remote-exec" {
  inline = [
    "sudo apt update",
    "sudo apt install -y nginx",
    "sudo systemctl enable nginx",
    "sudo systemctl start nginx"
  ]

  connection {
    type        = "ssh"
    user        = "azureuser"
    private_key = file("~/.ssh/id_rsa")
    host        = azurerm_public_ip.vm_ip.ip_address
  }
}
```

### `inline` vs `script`

`inline` takes a list of individual command strings, run in order.
Alternatively, `script` (singular) runs one local script file remotely,
or `scripts` (plural) runs multiple. `inline` is what the source video
uses and is the simplest to read for short command sequences.

### A factual correction on "azureuser"

The video refers to logging in as "azure user," which reads as if
it's a fixed, built-in account name. It isn't — `azureuser` is simply
a common convention, but the actual username is whatever you set on
`admin_username` in your `azurerm_linux_virtual_machine` resource. If
your Terraform code sets `admin_username = "deployadmin"`, your
`connection` block's `user` value must match that exactly, or the SSH
connection will fail with an authentication error. There's no default
"Azure user" account independent of what you configured.

---

## 6. `file` — Copying Files to the Target Resource

### Syntax

```hcl
provisioner "file" {
  source      = "config/sample.json"
  destination = "/home/azureuser/sample.json"

  connection {
    type        = "ssh"
    user        = "azureuser"
    private_key = file("~/.ssh/id_rsa")
    host        = azurerm_public_ip.vm_ip.ip_address
  }
}
```

`destination` and `connection` are mandatory. `source` (a local file
path) is one option for providing content; alternatively you can use
`content` to provide the file's text inline in your Terraform code
instead of referencing an external file — you use one or the other,
not both.

---

## 7. The `null_resource` — A Resource That Isn't a Resource

Provisioners must live inside a resource block. But sometimes you want
to run a provisioner that isn't tied to creating any real
infrastructure at all — like the timestamp-logging step in this
project, which runs before the VM even exists.

For that, Terraform provides `null_resource` — a resource type that
does nothing on its own except serve as a place to attach
provisioners and lifecycle behaviour.

```hcl
resource "null_resource" "deployment_prep" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = "echo \"Deployment started at ${timestamp()}\" > deployment-${timestamp()}.log"
  }
}
```

### The `triggers` block

`triggers` is a map of arbitrary values. Terraform re-runs the
`null_resource`'s provisioners whenever any value in `triggers`
changes between applies. Setting a trigger to `timestamp()` guarantees
it's different on every single `apply`, which forces the provisioner
to run every time — the pattern the video uses to make sure the
timestamp log always gets created.

Note: `hashicorp/terraform` also documents an equivalent newer
construct, `terraform_data`, intended as `null_resource`'s eventual
successor for this exact use case. `null_resource` still works and is
what the source video uses, but if you're starting a new project
today it's worth checking whether `terraform_data` better fits your
Terraform version.

---

## 8. The `connection` Block — Required for remote-exec and file

```hcl
connection {
  type        = "ssh"              # or "winrm" for Windows targets
  user        = "azureuser"        # must match admin_username on the VM
  private_key = file("~/.ssh/id_rsa")
  host        = azurerm_public_ip.vm_ip.ip_address
}
```

Key fields:
- `type` — `"ssh"` for Linux, `"winrm"` for Windows
- `user` — the account to authenticate as
- `private_key` or `password` — how to authenticate (SSH key file
  content, read via the `file()` function, or a plaintext password —
  key-based auth is strongly preferable)
- `host` — the IP address or hostname Terraform connects to

**PowerShell — generating an SSH key pair if you don't already have one:**
```powershell
ssh-keygen -t rsa -b 4096 -f "$HOME\.ssh\id_rsa"
```

If the VM doesn't yet have a public IP available at the moment the
provisioner runs (a very real ordering problem), the connection will
fail — this is part of why remote-exec is fragile compared to
cloud-init, which runs locally on the VM at boot with no network
round-trip required.

---

## 9. `depends_on` and Provisioner Ordering

The `null_resource` running the local timestamp log needs to execute
*before* the VM is created. Terraform doesn't automatically know this
relationship — a `null_resource` with no reference to the VM has no
inherent ordering with it. This is exactly the explicit-dependency
scenario Day 3 covered.

```hcl
resource "azurerm_linux_virtual_machine" "vm" {
  # ...

  depends_on = [null_resource.deployment_prep]
}
```

This forces Terraform to complete `null_resource.deployment_prep`
(and its `local-exec` provisioner) before starting the VM's creation.

---

## 10. The Preferred Alternatives to Provisioners

Since Section 2 established that provisioners are a last resort, it's
worth being concrete about what to use instead, because the source
video names these directly:

**cloud-init / custom data (Azure, VMs)** — a script or configuration
passed to the VM at boot time, executed by the VM's own operating
system before you ever need network access from Terraform's side. In
Azure Terraform resources this is typically the `custom_data`
argument (base64-encoded), which you've already used in earlier days
of this series for VMSS startup scripts.

```hcl
resource "azurerm_linux_virtual_machine" "vm" {
  # ...
  custom_data = base64encode(<<-EOF
    #!/bin/bash
    apt update
    apt install -y nginx
    systemctl enable nginx
    systemctl start nginx
  EOF
  )
}
```

This replaces the entire `remote-exec` block in Section 5 with
something that runs locally on the VM at first boot — no SSH
connection required from Terraform, no ordering fragility.

**Kubernetes-native resources** — for AKS or other Kubernetes
clusters, rather than running `kubectl apply` via a `remote-exec` or
`local-exec` provisioner, the `kubernetes` or `kubectl` Terraform
providers offer resources like `kubernetes_manifest` that manage
manifests declaratively, inside Terraform's own state tracking.

**Provider-native resources generally** — before writing any
provisioner, check whether the specific action you want has a
first-class Terraform resource already. Many "run this script on the
resource" needs turn out to already have a proper `azurerm_*` (or
equivalent) resource type once you look.

---

## 11. Building the Demo — Starting Point (Recap of Prior-Day Resources)

The video begins from an already-familiar set of resources built over
the earlier days of this series — nothing new conceptually here, just
listed for completeness:

- `azurerm_resource_group`
- `azurerm_virtual_network` and `azurerm_subnet`
- `azurerm_network_security_group` allowing inbound SSH (port 22) and
  HTTP (port 80)
- `azurerm_public_ip`
- `azurerm_network_interface`, associated with the public IP
- `azurerm_linux_virtual_machine`, using an SSH key from
  `~/.ssh/id_rsa.pub`
- an `output` block exposing the VM's public IP address

If any of this is unfamiliar, it's covered in full in this series'
earlier days on resources, networking, and virtual machines — this
guide assumes you can build that scaffold and focuses on what's new:
the provisioner blocks layered on top of it.

---

## 12. Step 1 — `local-exec`: Logging a Deployment Timestamp

```hcl
resource "null_resource" "deployment_prep" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = "echo \"Deployment started at ${timestamp()}\" > deployment-${timestamp()}.log"
  }
}
```

**PowerShell equivalent**, if you want this to actually run correctly
on a Windows machine rather than assuming a Unix shell:

```hcl
resource "null_resource" "deployment_prep" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command     = "\"Deployment started at $(Get-Date -Format o)\" | Out-File -FilePath \"deployment-log.txt\""
  }
}
```

This resource creates no cloud infrastructure at all — its entire
purpose is to run a local command as a side effect.

---

## 13. Step 2 — `remote-exec`: Installing and Starting NGINX

```hcl
resource "azurerm_linux_virtual_machine" "vm" {
  # ... existing VM configuration from prior days ...

  depends_on = [null_resource.deployment_prep]

  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install -y nginx",
      "echo '<h1>Provisioned with Terraform - file, remote executor, enable nginx</h1>' | sudo tee /var/www/html/index.html",
      "sudo systemctl start nginx",
      "sudo systemctl enable nginx"
    ]

    connection {
      type        = "ssh"
      user        = "azureuser"
      private_key = file("~/.ssh/id_rsa")
      host        = azurerm_public_ip.vm_ip.ip_address
    }
  }
}
```

Section 10 already covered why `custom_data` is the generally
preferred way to achieve exactly this outcome — this block is here to
demonstrate `remote-exec` as taught in the source video, not because
it's the recommended production pattern for this particular task.

---

## 14. Step 3 — `file`: Copying a Config File to the VM

Added as a second `provisioner` block inside the same VM resource
(Terraform allows multiple provisioner blocks per resource, executed
in the order they're written):

```hcl
  provisioner "file" {
    source      = "config/sample.json"
    destination = "/home/azureuser/sample.json"

    connection {
      type        = "ssh"
      user        = "azureuser"
      private_key = file("~/.ssh/id_rsa")
      host        = azurerm_public_ip.vm_ip.ip_address
    }
  }
```

Note the `connection` block is repeated per provisioner — each
provisioner that needs remote access defines its own connection
details; they aren't automatically shared across provisioner blocks
within the resource.

---

## 15. Running the Deployment and Verifying Each Provisioner

```powershell
Set-Location "C:\projects\day19"

$env:ARM_CLIENT_ID       = "your-client-id"
$env:ARM_CLIENT_SECRET   = "your-client-secret"
$env:ARM_TENANT_ID       = "your-tenant-id"
$env:ARM_SUBSCRIPTION_ID = "your-subscription-id"

terraform init
terraform validate
terraform plan
terraform apply --auto-approve
```

**Verifying the local-exec output:**
```powershell
Get-ChildItem .\deployment-*.log
Get-Content .\deployment-*.log
```

**Verifying the remote-exec and file provisioners, by SSH-ing in directly:**
```powershell
$vmIp = terraform output -raw vm_public_ip
ssh azureuser@$vmIp
```

Once connected:
```bash
ls ~
cat ~/sample.json
systemctl status nginx
cat /var/www/html/index.html
```

**Verifying NGINX over HTTP from PowerShell, without opening a browser:**
```powershell
Invoke-WebRequest -Uri "http://$vmIp" -UseBasicParsing
```

---

## 16. The Instructor's HTTPS Confusion — What Actually Happened

Worth addressing directly rather than glossing over, since the source
video presents this as a genuine mystery at the time: the demo NGINX
page failed to load in the browser, and the instructor eventually
found that the browser was automatically resolving the address to
`https://` instead of `http://`.

**What actually causes this**, more precisely than "it just redirected":
Modern browsers (Chrome, Edge, and others) maintain an internal
**HSTS preload list** and, separately, will often *default* an
address-bar-typed bare IP or hostname to HTTPS on the first attempt,
or silently upgrade `http://` to `https://` for domains previously
visited over HTTPS. Since this project's NGINX installation was never
configured with a TLS certificate and has no listener on port 443,
the HTTPS attempt would fail to connect (not "redirect and then
work") — while HTTP on port 80, explicitly typed, succeeded, as
confirmed later in the video with a working `curl`/browser test.

This is a genuinely common source of confusion when testing plain-HTTP
demo servers, and the fix demonstrated (explicitly typing `http://`)
is correct — I'm only adding precision to *why*, since "it was
redirecting to HTTPS by default" slightly overstates what modern
browsers actually do (it's closer to "defaulting to" or "upgrading
to" HTTPS than a server-side redirect, since no redirect could have
been served by an NGINX instance with nothing listening on 443).

---

## 17. The Assignment — A Second Timestamp File on Completion

The instructor leaves this as a practice task, matching the pattern
already demonstrated in Section 12, placed at the *end* of the
resource instead of the beginning:

```hcl
resource "azurerm_linux_virtual_machine" "vm" {
  # ... existing config, remote-exec, file provisioners above ...

  provisioner "local-exec" {
    command = "echo \"Deployment completed at ${timestamp()}\" > deployment-complete-${timestamp()}.log"
  }
}
```

Since this provisioner is declared as part of the VM resource itself
(rather than a separate `null_resource`), it naturally runs only after
the VM — and any earlier provisioners on that same resource — have
completed successfully, without needing an explicit `depends_on`.

---

## 18. The Complete Working Code — All Files

**`provider.tf`**
```hcl
terraform {
  required_version = ">= 1.9.0"
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

**`main.tf`** (network/VM scaffold — abbreviated; full detail in earlier days)
```hcl
resource "azurerm_resource_group" "rg" {
  name     = "day19-rg"
  location = "Canada Central"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "day19-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "day19-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_security_group" "nsg" {
  name                = "day19-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "allow-ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-http"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_public_ip" "vm_ip" {
  name                = "day19-vm-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "nic" {
  name                = "day19-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm_ip.id
  }
}

resource "azurerm_network_interface_security_group_association" "nsg_assoc" {
  network_interface_id     = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "null_resource" "deployment_prep" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = "echo \"Deployment started at ${timestamp()}\" > deployment-${timestamp()}.log"
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                = "day19-vm"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B1s"
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

  depends_on = [null_resource.deployment_prep]

  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install -y nginx",
      "echo '<h1>Provisioned with Terraform</h1>' | sudo tee /var/www/html/index.html",
      "sudo systemctl start nginx",
      "sudo systemctl enable nginx"
    ]

    connection {
      type        = "ssh"
      user        = "azureuser"
      private_key = file("~/.ssh/id_rsa")
      host        = azurerm_public_ip.vm_ip.ip_address
    }
  }

  provisioner "file" {
    source      = "config/sample.json"
    destination = "/home/azureuser/sample.json"

    connection {
      type        = "ssh"
      user        = "azureuser"
      private_key = file("~/.ssh/id_rsa")
      host        = azurerm_public_ip.vm_ip.ip_address
    }
  }

  provisioner "local-exec" {
    command = "echo \"Deployment completed at ${timestamp()}\" > deployment-complete-${timestamp()}.log"
  }
}
```

**`outputs.tf`**
```hcl
output "vm_public_ip" {
  value = azurerm_public_ip.vm_ip.ip_address
}
```

**`config/sample.json`** (the file copied via the `file` provisioner)
```json
{
  "deployed_by": "terraform",
  "environment": "day19-demo"
}
```

---

## 19. Common Mistakes and Corrections

**Mistake 1 — Forgetting `depends_on` for provisioners that must run
before a resource exists.** A `null_resource` with no reference to
another resource has no inherent creation-order relationship with it;
Terraform may create them in parallel. Explicit `depends_on` is
required if strict ordering matters, exactly as in Section 9.

**Mistake 2 — Assuming a re-run of `terraform apply` re-executes
provisioners.** By default, provisioners run once, at resource
creation. Re-running `apply` on an already-created resource does not
re-trigger its provisioners unless the resource itself is being
recreated, or you're using a `null_resource` with a changing
`triggers` value.

**Mistake 3 — Mismatched `user` in the `connection` block.** As
covered in Section 5, `azureuser` is a convention, not a guarantee —
it must exactly match whatever `admin_username` (or
`admin_ssh_key.username`) you actually configured on the VM.

**Mistake 4 — Assuming Linux shell commands work unmodified on
Windows via `local-exec`.** Section 4 covers this: without an explicit
PowerShell `interpreter`, Terraform's default shell on Windows is
`cmd.exe`, and Unix-style `echo ... > file` syntax may not behave as
expected.

**Mistake 5 — Reaching for provisioners as a first choice.** This is
the mistake this entire guide has argued against from Section 2
onward: check for a `custom_data`/cloud-init equivalent, or a
provider-native resource, before writing a `remote-exec` block.

---

## 20. Practice Exercises

**Exercise 1** — Rewrite the `remote-exec` block in Section 13 as
`custom_data` instead, and explain one concrete operational advantage
of the rewrite.

*Answer:* Base64-encode the same shell commands and pass them via
`custom_data` on the VM resource. Advantage: the script runs locally
on the VM at boot via cloud-init, removing the requirement for
Terraform to have live SSH connectivity to the VM at apply time —
eliminating an entire class of "VM not reachable yet" failures.

**Exercise 2** — A colleague's `null_resource` provisioner only runs
on the very first `terraform apply` and never again, even though they
want it to log every deployment. What's missing?

*Answer:* A `triggers` block with a value that changes on every
apply (such as `timestamp()`), as shown in Section 12. Without it,
Terraform has no signal to re-run the `null_resource`'s provisioners
on subsequent applies.

**Exercise 3** — Why does HashiCorp's own documentation describe
provisioners as a "last resort," and can you name two of the specific
alternatives this guide covers for common provisioner use cases?

*Answer:* Because they break Terraform's declarative model, introduce
a runtime network dependency, and can mask configuration drift
(Section 2). Alternatives: `custom_data`/cloud-init for VM startup
scripts (Section 10), and Kubernetes-native provider resources like
`kubernetes_manifest` in place of running `kubectl apply` via
`remote-exec`.

---

## 21. Summary Reference

Three provisioner types: `local-exec` (runs on your machine, no
`connection` needed), `remote-exec` (runs commands on the target
resource, needs `connection`), `file` (copies a file to the target
resource, needs `connection`).

`null_resource` provides a place to attach provisioners not tied to a
real infrastructure resource; its `triggers` block controls when its
provisioners re-run.

`depends_on` is required to force explicit ordering when Terraform
can't infer a dependency from resource references alone — as is the
case for a `null_resource` with no attribute references to the
resource it should run before.

HashiCorp's official position, echoed directly in the source video,
is that provisioners should be a last resort, used only when no
cloud-native alternative (cloud-init/`custom_data`, provider-native
resources like `kubernetes_manifest`) exists for the task at hand.

---

*Guide covers: Terraform provisioners, local-exec, remote-exec, file
provisioner, null_resource, terraform_data as a newer alternative,
triggers block, connection block (ssh/winrm, user, private_key, host),
depends_on for provisioner ordering, why provisioners are discouraged
by HashiCorp (declarative model violation, runtime network dependency,
configuration drift risk), cloud-init and custom_data as the preferred
alternative for VM startup automation, kubernetes_manifest as the
preferred alternative to remote kubectl execution, PowerShell
interpreter argument for local-exec on Windows, SSH key generation
with ssh-keygen, admin_username matching in connection blocks,
verifying provisioner output via PowerShell (Get-Content, Invoke-WebRequest,
ssh), and a corrected technical explanation of browser HTTP-to-HTTPS
default behaviour versus an actual server-side redirect.*
