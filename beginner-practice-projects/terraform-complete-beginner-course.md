# Terraform From Absolute Zero — Complete Course
### For someone who has never written a single line of code before
### Every example uses Azure (`azurerm` provider)

> Scope note, stated honestly upfront: this guide is built from general
> Terraform/Azure fundamentals and cross-checked against the structure
> of the `piyushsachdeva/Terraform-Full-Course-Azure` course you linked
> (I was rate-limited pulling the full folder listing this time, so I'm
> not claiming to mirror every lesson number exactly — but the concept
> coverage below is the standard, complete beginner-to-intermediate
> Terraform curriculum, and it lines up with what that kind of course
> teaches). If you want me to verify against a specific day/lesson
> number later, paste the folder name and I'll pull it directly.

---

## How This Guide Is Organized

Sixteen sections, each building on the last. Every section ends with
a **mini project** — small, runnable, and designed to be typed out by
hand, not copy-pasted. Do not skip ahead. Terraform concepts stack on
each other; skipping the state section, for example, will make
lifecycle and count/for_each much harder to understand later.

```
0.  Setup — tools you need before writing any code
1.  What is Infrastructure as Code — the "why" before the "how"
2.  Anatomy of a Terraform file — blocks, arguments, syntax basics
3.  Providers — how Terraform talks to Azure
4.  Resources — the things Terraform actually creates
5.  Variables — making your code reusable
6.  Outputs — getting information back out
7.  The State File — Terraform's memory
8.  count — repeating a resource N times
9.  for_each — repeating a resource per item in a collection
10. count vs for_each — when to use which
11. The lifecycle block — controlling how resources are replaced
12. Constraints & Validation — enforcing rules on your inputs
13. Locals & Functions — computing values (recap + reference table)
14. Data sources — reading things Terraform didn't create
15. Modules — packaging code for reuse
16. Capstone project — everything combined
17. Command cheat sheet
```

---
---

# 0. Setup — What You Need Before Writing Any Code

Since you have zero coding background, let's be extremely explicit
about what "writing Terraform code" actually requires on your machine.

| Tool | What it is, in plain English | Why you need it |
|---|---|---|
| **Terraform CLI** | A program you run from a terminal that reads your `.tf` files and talks to Azure | This is the actual engine — without it, `.tf` files are just text |
| **Azure CLI (`az`)** | A program that lets you log into your Azure account from the terminal | Terraform needs to prove to Azure who you are before it can create anything |
| **A code editor** (VS Code recommended) | A text editor with helpful color-highlighting for `.tf` files | You *can* use Notepad, but VS Code catches typos and formatting issues as you type |
| **A terminal** | A text-based window where you type commands instead of clicking buttons | Terraform has no visual app — everything happens through typed commands |

### Installing (do this once)

```bash
# Check if Terraform is already installed
terraform -version

# Check if Azure CLI is installed
az -version
```

If either command says "command not found," you'll need to install
them — search "install terraform [your operating system]" and
"install azure cli [your operating system]" for the official
HashiCorp/Microsoft instructions, since install steps differ by OS
and change over time.

### Logging into Azure (do this every time you start a new session)

```bash
az login
```

This opens a browser window, you sign in with your Azure account, and
your terminal is now "authenticated" — Terraform will use this same
login automatically.

```bash
az account show
```

This confirms which Azure subscription you're currently connected to
— important if your account has more than one subscription, since
Terraform will deploy into whichever one is "active."

---
---

# 1. What Is Infrastructure as Code — The "Why" Before the "How"

### Explain it like you've never coded

Imagine two ways of building a house:

**Way 1 (manual / "ClickOps"):** You walk into the Azure Portal (a
website), click "Create Resource Group," fill in a form, click
"Create Storage Account," fill in another form, click through 15
more screens for a virtual network. It works, but if you need to
build the *exact same thing* again next month for a different client,
you have to remember every click, in the right order, correctly,
every single time. One missed checkbox and you have a subtly broken
copy.

**Way 2 (Infrastructure as Code):** You write down, in a text file,
exactly what you want: "one resource group, one storage account, one
virtual network, configured like this." Then you run one command, and
a program (Terraform) reads your text file and builds *exactly* that,
every time, identically, with zero clicking. Need to build it again?
Run the same command again.

That text file is your infrastructure, described as *code* — hence
"Infrastructure as Code" (IaC). Terraform is one specific tool that
does this. It is not the only one (Azure has its own called "ARM
templates" / "Bicep"), but Terraform works across many cloud
providers with one consistent language, which is why it's so widely
used.

### Why this actually matters, beyond convenience

- **Repeatability** — the same code produces the same infrastructure, every time, with no human memory involved
- **Version control** — your infrastructure's history lives in a text file you can track changes to, just like a Word document's "track changes," except far more precise
- **Review before you build** — Terraform can show you *exactly* what it's about to change before it touches anything real (`terraform plan` — you'll use this constantly)
- **Teamwork** — instead of one person clicking through a portal (a single point of failure and knowledge), a whole team can read, review, and improve the same code

---
---

# 2. Anatomy of a Terraform File — Blocks, Arguments, Syntax Basics

### Explain it like you've never coded

Terraform files end in `.tf` and are written in a language called
**HCL** (HashiCorp Configuration Language). Think of HCL as a very
structured, very picky form of English — it's not a full programming
language like Python, it's closer to filling out a very strict form.

Every piece of Terraform code is built from **blocks**. A block looks
like this:

```hcl
block_type "label_one" "label_two" {
  argument_name = "argument_value"
  another_arg   = 123
}
```

Let's dissect this piece by piece, since every single Terraform file
you'll ever see follows this exact shape:

- **`block_type`** — a fixed keyword Terraform recognizes: `resource`,
  `variable`, `provider`, `output`, `locals`, `data`, `module`,
  `terraform`. You cannot invent your own block type.
- **`"label_one"` and `"label_two"`** — names *you* choose, in quotes.
  Not every block type needs two labels — some need one, some need none.
- **`{ }`** — curly braces always wrap the block's contents. Everything
  between them belongs to that block.
- **`argument_name = "argument_value"`** — inside the block, you set
  arguments using an equals sign. This is just "key = value," the same
  concept as filling in a form field.

### A real, complete, minimal example

```hcl
resource "azurerm_resource_group" "rg" {
  name     = "rg-hello-world"
  location = "eastus"
}
```

Reading this out loud in plain English: *"Create a `resource` of type
`azurerm_resource_group`. I'm going to refer to this specific one by
the internal nickname `rg`. Set its `name` argument to the text
`"rg-hello-world"` and its `location` argument to `"eastus"`."*

**Critical beginner distinction:** the label `"rg"` is a name **you
invented for Terraform's internal bookkeeping** — it is NOT the actual
Azure resource group name. The actual Azure name is whatever you set
`name = "..."` to. This trips up every single beginner at least once:
`"rg"` (the label) and `"rg-hello-world"` (the `name` argument) are
two completely different things serving two completely different
purposes.

### Referencing one block from another

Once a resource exists, you can reference its attributes elsewhere
using dot notation: `block_type.label.attribute`

```hcl
resource "azurerm_resource_group" "rg" {
  name     = "rg-hello-world"
  location = "eastus"
}

resource "azurerm_storage_account" "sa" {
  name                     = "sthelloworld001"
  resource_group_name      = azurerm_resource_group.rg.name       # <- reference!
  location                 = azurerm_resource_group.rg.location   # <- reference!
  account_tier             = "Standard"
  account_replication_type = "LRS"
}
```

`azurerm_resource_group.rg.name` means: *"go find the resource block
of type `azurerm_resource_group` labeled `rg`, and grab its `name`
attribute."* This is how Terraform automatically figures out that the
storage account must be created **after** the resource group — it
sees the reference and builds a dependency order for you, without you
ever writing "do this first, then that."

### Comments (notes to yourself that Terraform ignores)

```hcl
# This is a single-line comment
resource "azurerm_resource_group" "rg" {
  name     = "rg-hello-world"  # you can also comment at the end of a line
  location = "eastus"
}
```

---
---

# 3. Providers — How Terraform Talks to Azure

### Explain it like you've never coded

Terraform itself doesn't know anything about Azure, AWS, Google
Cloud, or any specific platform out of the box — it's a general
engine. A **provider** is a plugin that teaches Terraform how to
speak to one specific platform's API. For Azure, that plugin is
called `azurerm` (short for "Azure Resource Manager").

Every Terraform project needs to declare which provider(s) it uses,
and which version, before anything else works:

```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.8.0"
    }
  }
  required_version = ">= 1.9.0"
}

provider "azurerm" {
  features {}
}
```

### Breaking down every line

- **`terraform { ... }`** — a special block for settings about
  Terraform itself, not about any specific cloud resource.
- **`required_providers { azurerm = { ... } }`** — tells Terraform
  "this project needs the `azurerm` plugin, fetched from
  `hashicorp/azurerm` (the official registry location), and it must
  be version `~> 4.8.0`."
- **`~> 4.8.0`** — a **version constraint**. The `~>` symbol means
  "this version, or any later patch version, but not the next minor
  version." So `~> 4.8.0` allows `4.8.1`, `4.8.9`, but NOT `4.9.0`.
  This protects you from an update accidentally introducing breaking
  changes to your code.
- **`required_version = ">= 1.9.0"`** — same idea, but for the
  Terraform CLI itself, not a provider. `>=` means "this version or
  anything newer."
- **`provider "azurerm" { features {} }`** — this is the block that
  actually *activates* the provider for use. `features {}` is a
  required empty block the Azure provider insists on — think of it as
  Azure's provider saying "you must acknowledge this settings block
  exists, even if you're not customizing anything in it yet."

### The first command you'll ever run in a new project

```bash
terraform init
```

This reads your `required_providers` block, downloads the actual
`azurerm` plugin files onto your computer, and sets up a hidden
`.terraform` folder to store them. **You must run this once in every
new project folder** before any other Terraform command will work.

---
---

# 4. Resources — The Things Terraform Actually Creates

### Explain it like you've never coded

If providers are "the language Terraform speaks to Azure," resources
are "the actual sentences" — each `resource` block describes one real
thing that should exist in Azure: a resource group, a virtual
network, a storage account, a virtual machine.

```hcl
resource "azurerm_resource_group" "rg" {
  name     = "rg-mini-project"
  location = "eastus"
}
```

The general shape is always:
```
resource "<PROVIDER>_<THING>" "<your_internal_nickname>" {
  <settings for this specific thing>
}
```

`azurerm_resource_group` is called the **resource type** — it's a
fixed name defined by the `azurerm` provider (you can't invent your
own; you look these up in the Terraform Registry documentation for
whatever resource you want to create). Every resource type has its
own specific set of required and optional arguments, documented on
the Terraform Registry website.

### The four commands you'll run constantly

```bash
terraform init      # download provider plugins (once per project)
terraform plan       # show what WOULD change, without changing anything
terraform apply       # actually create/change/destroy real Azure resources
terraform destroy      # delete everything this project created
```

**The single most important habit to build as a beginner:** always run
`terraform plan` before `terraform apply`, and actually **read** the
output. Terraform will show you a summary like:

```
Plan: 2 to add, 0 to change, 0 to destroy.
```

If that number doesn't match what you expect, stop and figure out why
*before* running `apply`. This is how you avoid accidentally deleting
something important.

---

## MINI PROJECT 1 — Your First Real Deployment

**Goal:** deploy one resource group and one storage account to Azure,
using everything from sections 2-4.

**Steps:**
1. Create a new folder, add a `provider.tf` file with the provider
   block from Section 3
2. Create a `main.tf` file with a resource group and a storage account
   (storage account names must be globally unique, all lowercase, no
   hyphens, 3-24 characters — pick something like `sayourinitials001`)
3. Run `terraform init`
4. Run `terraform plan` — read the output carefully, confirm it says
   "2 to add"
5. Run `terraform apply`, type `yes` when prompted
6. Go check the Azure Portal — your resource group and storage account
   should actually be there
7. Run `terraform destroy` to clean up, type `yes` when prompted

This is the smallest possible complete Terraform workflow. Everything
else in this guide adds sophistication on top of this exact loop.

---
---

# 5. Variables — Making Your Code Reusable

### Explain it like you've never coded

In Mini Project 1, you hardcoded `"eastus"` and a storage account name
directly into `main.tf`. That's fine for a one-off test, but what if
you want to deploy the same setup to `"westus"` for a different
project tomorrow? You'd have to go edit the file itself, which is
error-prone and doesn't scale.

A **variable** is a labeled input slot — a placeholder that gets
filled in with a real value at the time you run Terraform, instead of
being hardcoded.

```hcl
variable "location" {
  type        = string
  description = "Which Azure region to deploy into"
  default     = "eastus"
}
```

Then, anywhere else in your code, you reference it as `var.location`:

```hcl
resource "azurerm_resource_group" "rg" {
  name     = "rg-mini-project"
  location = var.location
}
```

### The pieces of a variable block

- **`type`** — what *kind* of value is allowed: `string` (text),
  `number`, `bool` (true/false), `list(string)` (a list of text
  values), `map(string)` (labeled key-value pairs), or more complex
  combinations. Terraform will reject a value of the wrong type with
  a clear error — this is a real safety net for beginners.
- **`description`** — a human-readable note explaining what this
  variable is for. Not required, but genuinely important for anyone
  (including future-you) reading the code later.
- **`default`** — the value used if nobody overrides it. Optional —
  if you omit `default`, Terraform will **stop and ask you to type a
  value** every time you run `plan`/`apply`, unless you supply one
  another way.

### The four ways to actually supply a variable's value

```bash
# 1. Command-line flag
terraform apply -var="location=westus"

# 2. A .tfvars file (create a file, e.g. myvalues.tfvars)
#    location = "westus"
terraform apply -var-file="myvalues.tfvars"

# 3. Environment variable (note the required TF_VAR_ prefix)
export TF_VAR_location="westus"
terraform apply

# 4. A file literally named terraform.tfvars in the same folder —
#    Terraform loads this automatically, no flag needed
```

---

## MINI PROJECT 2 — Rebuild Project 1 Using Variables

**Goal:** take Mini Project 1 and replace every hardcoded value with a
variable.

**Steps:**
1. Create `variables.tf` with variables for: `location`,
   `resource_group_name`, `storage_account_name`
2. Update `main.tf` to use `var.location`, `var.resource_group_name`,
   `var.storage_account_name` instead of hardcoded text
3. Run `terraform plan` with the defaults — confirm it still works
4. Run `terraform plan -var="location=westeurope"` — confirm the plan
   now shows `westeurope` instead of your default
5. Create a `dev.tfvars` file with different values, and run
   `terraform plan -var-file="dev.tfvars"` — confirm those values win

---
---

# 6. Outputs — Getting Information Back Out

### Explain it like you've never coded

After Terraform creates something in Azure, it often generates values
you didn't specify yourself — a resource's unique ID, an
auto-assigned IP address, a connection string. An **output** is how
you tell Terraform "after you're done, show me this specific value on
screen" — or, more importantly in real projects, "hand this value to
another piece of code that needs it" (like a different Terraform
module, or a script).

```hcl
output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "storage_account_id" {
  value = azurerm_storage_account.sa.id
}
```

After `terraform apply`, you'll see:
```
Outputs:

resource_group_name = "rg-mini-project"
storage_account_id = "/subscriptions/.../resourceGroups/..."
```

You can also view outputs anytime after a successful apply, without
re-running the whole plan:
```bash
terraform output
terraform output resource_group_name    # just one specific output
```

### Marking sensitive outputs

```hcl
output "primary_connection_string" {
  value     = azurerm_storage_account.sa.primary_connection_string
  sensitive = true
}
```

`sensitive = true` hides the real value from the terminal output
(shows `(sensitive value)` instead) — critical for anything
resembling a password, key, or connection string, so it doesn't
accidentally end up in a screenshot, a CI/CD log, or a chat message.

---

## MINI PROJECT 3 — Add Outputs to Project 2

**Goal:** expose useful information after deployment.

**Steps:**
1. Add outputs for: the resource group's `id`, the storage account's
   `name`, and the storage account's `primary_connection_string`
   (marked `sensitive`)
2. Run `terraform apply`
3. Run `terraform output` and confirm the connection string shows as
   hidden, but the other two show real values
4. Run `terraform output storage_account_name` alone — confirm it
   shows just that one value

---
---

# 7. The State File — Terraform's Memory

### Explain it like you've never coded

This is the concept beginners skip past too quickly, and it causes
real confusion later, so slow down here.

When you run `terraform apply`, Terraform doesn't just create things
in Azure and forget about them — it writes down, in a file called
`terraform.tfstate`, **exactly what it created and what settings it
used**. This file is Terraform's memory of reality.

Why does this matter? Because on your *next* `terraform plan`,
Terraform doesn't re-ask Azure "what exists right now" from scratch —
it compares three things:
1. What your `.tf` code says *should* exist
2. What the state file says *currently* exists (as far as Terraform
   last knew)
3. (Sometimes) what Azure itself actually reports exists

Based on comparing these, Terraform calculates the minimum set of
changes needed — this is why `terraform plan` can tell you "1 to add,
0 to change, 0 to destroy" instead of blindly recreating everything
every single time.

### Where does the state file live?

By default, it's a plain file called `terraform.tfstate`, sitting
right there in your project folder. For solo learning projects,
that's fine. **For real team projects, this is dangerous** — if two
people run `terraform apply` from their own separate copies of the
state file at the same time, they can corrupt each other's
understanding of reality. This is why enterprises use **remote
state** — storing the state file in a shared location instead, most
commonly, for Azure projects, inside an Azure Storage Account itself:

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "sttfstateshared001"
    container_name        = "tfstate"
    key                    = "myproject.tfstate"
  }
}
```

This tells Terraform: "don't keep the state file locally — store it
inside this specific Azure Storage Account, in this specific
container, under this specific filename." Now every team member
reads/writes the *same* state file, and Azure Storage's built-in
locking mechanism prevents two people from applying changes at
exactly the same moment.

**Beginner note:** setting up a remote backend requires that the
storage account already exist *before* you can use it as a backend
for this project — which creates a bit of a chicken-and-egg situation
many teams solve by having one small, separate Terraform project
whose only job is to create the "state storage" infrastructure
itself, deployed once, manually, before anything else.

### Commands for inspecting state

```bash
terraform state list              # show everything Terraform is tracking
terraform state show <resource>   # show full details of one tracked resource
terraform show                    # show the entire current state, human-readable
```

**Important safety rule:** never hand-edit the `.tfstate` file
directly in a text editor. It's technically a JSON file, and it's
tempting to think "I'll just fix this one value," but doing so can
silently corrupt Terraform's understanding of reality in ways that
cause serious problems later. If you genuinely need to change what
Terraform thinks exists, use proper commands like `terraform state
rm` or `terraform import` instead.

---

## MINI PROJECT 4 — Observe State in Action

**Goal:** actually watch the state file work, so it stops being
abstract.

**Steps:**
1. Using Project 3's code, run `terraform apply`
2. Run `terraform state list` — confirm you see your resource group
   and storage account listed
3. Open `terraform.tfstate` in a text editor (just to look, don't
   edit it) — notice it's a big JSON file with all your resources'
   full details recorded
4. In the Azure Portal, manually rename a **tag** on your resource
   group (something small, not the resource itself)
5. Run `terraform plan` again — Terraform will detect this "drift"
   (a difference between what it expected and what's actually there)
   and show you it wants to change the tag back to match your code —
   this is Terraform noticing that reality no longer matches its
   memory, and correcting it

---
---

# 8. `count` — Repeating a Resource N Times

### Explain it like you've never coded

Imagine you need 3 identical storage accounts. Without `count`,
you'd write the same `resource` block three times, changing only the
name each time — tedious and error-prone. `count` lets you say "make
this resource block N times" in one place.

```hcl
resource "azurerm_storage_account" "sa" {
  count                    = 3
  name                     = "sademo${count.index}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}
```

`count = 3` tells Terraform "create three copies of this resource."
Inside the block, `count.index` gives you the position of each copy,
starting at `0` — so this creates `sademo0`, `sademo1`, `sademo2`.

### Referencing a specific instance, or all of them

```hcl
# One specific instance
output "first_storage_name" {
  value = azurerm_storage_account.sa[0].name
}

# ALL instances, as a list, using the splat operator [*]
output "all_storage_names" {
  value = azurerm_storage_account.sa[*].name
}
```

The `[*]` (called the "splat operator") means "grab this attribute
from every single instance, and give it back to me as a list."

### The real danger of `count` — worth understanding before you use it

`count` identifies each copy purely by its **numeric position**
(`0`, `1`, `2`...). If you remove the *middle* item from a list that
drives your count, Terraform doesn't understand "the middle one is
gone" — it sees that position `1` now has different data than before,
and may decide to destroy and recreate resources at every position
after the gap, even ones that logically shouldn't have changed at
all. This is the single biggest reason `for_each` (next section) is
usually the better choice when the items being created have distinct
identities (names) rather than just being "three of the same thing."

---

## MINI PROJECT 5 — Deploy 3 Identical Storage Accounts

**Goal:** use `count` to avoid repeating code.

**Steps:**
1. Add a `count = 3` storage account resource using the pattern above
2. Run `terraform plan` — confirm it shows 3 storage accounts to add
3. `terraform apply`
4. Change `count` to `2` and run `terraform plan` again — observe
   which specific instance Terraform proposes to destroy (this
   demonstrates the "position-based identity" issue described above)

---
---

# 9. `for_each` — Repeating a Resource Per Item in a Collection

### Explain it like you've never coded

`for_each` solves the same "don't repeat yourself" problem as
`count`, but instead of a plain number, it loops over a **map** or a
**set** — meaning each copy is identified by a meaningful key (a
name), not just a number.

```hcl
variable "storage_accounts" {
  type = set(string)
  default = ["web", "app", "backup"]
}

resource "azurerm_storage_account" "sa" {
  for_each                 = var.storage_accounts
  name                     = "sademo${each.value}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}
```

Inside the block, `each.value` gives you the current item (and if
you're looping over a **map** instead of a set, `each.key` gives you
the map's key while `each.value` gives you that key's value).

### Example with a map (more common in real projects)

```hcl
variable "storage_configs" {
  type = map(string)
  default = {
    web    = "LRS"
    app    = "GRS"
    backup = "RAGRS"
  }
}

resource "azurerm_storage_account" "sa" {
  for_each                 = var.storage_configs
  name                     = "sademo${each.key}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = each.value   # "LRS", "GRS", or "RAGRS" depending on the key
}
```

Here `each.key` is `"web"`/`"app"`/`"backup"`, and `each.value` is
that specific storage account's replication type.

### Referencing a specific instance

```hcl
output "web_storage_name" {
  value = azurerm_storage_account.sa["web"].name
}

output "all_storage_names" {
  value = { for k, v in azurerm_storage_account.sa : k => v.name }
}
```

Notice: with `for_each`, you reference a specific instance by its
**key** (`"web"`), not a number — and if you remove `"app"` from the
middle of your map, Terraform correctly understands "only the `app`
one is gone," and leaves `web` and `backup` completely untouched. This
is the core advantage over `count`.

---
---

# 10. `count` vs `for_each` — When to Use Which

| Situation | Use |
|---|---|
| You need "N identical copies" and truly don't care about individual identity | `count` |
| Each item has a meaningful name/identity (subnets, teams, environments) | `for_each` |
| Your list of items might have items removed from the *middle* later | `for_each` (avoids the position-shift problem) |
| You're looping over a simple list of numbers just to repeat something a fixed number of times | `count` |
| You're looping over a map, or a list where each entry needs a different configuration | `for_each` |

**A practical rule many experienced Terraform users follow:** default
to `for_each` unless you have a specific reason to use `count`. The
"identical, interchangeable copies" scenario `count` is genuinely
good for is rarer in real infrastructure than it first appears —
almost everything (subnets, VMs, storage accounts) ends up needing a
distinct name or configuration eventually, at which point `for_each`
was the right choice from the start.

---

## MINI PROJECT 6 — Rebuild Project 5 Using `for_each`

**Goal:** directly compare the two approaches on the same problem.

**Steps:**
1. Take Mini Project 5 (the `count`-based storage accounts) and
   rewrite it using `for_each` with a `set(string)` of three names
   (e.g. `["web", "app", "backup"]`)
2. Run `terraform plan`, confirm 3 resources are created, each named
   after its key rather than a number
3. Remove the **middle** item (`"app"`) from your set and run
   `terraform plan` again — confirm ONLY that one storage account is
   proposed for destruction, and the other two show no changes at
   all — compare this directly against what happened in Mini Project 5

---
---

# 11. The `lifecycle` Block — Controlling How Resources Are Replaced

### Explain it like you've never coded

Sometimes Terraform's default behavior for updating or replacing a
resource isn't what you want. The `lifecycle` block, placed inside
any `resource`, lets you override specific behaviors around
creation, updates, and destruction.

```hcl
resource "azurerm_storage_account" "sa" {
  name                     = "sademo001"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  lifecycle {
    prevent_destroy = true
  }
}
```

### The four lifecycle settings you'll actually use

**`prevent_destroy = true`** — refuses to let Terraform delete this
resource, even if your code changes in a way that would normally
require destroying and recreating it, and even if someone runs
`terraform destroy`. Terraform will error out instead. Use this for
things that would be catastrophic to accidentally delete — a
production database, critical storage.

```hcl
lifecycle {
  prevent_destroy = true
}
```

**`create_before_destroy = true`** — normally, when a resource must
be replaced (some changes can't be applied in-place and require a
full destroy-then-recreate), Terraform destroys the old one *first*,
then creates the new one. This can cause downtime. Setting this flag
flips the order: Terraform creates the *new* resource first, and only
destroys the old one once the new one exists successfully.

```hcl
lifecycle {
  create_before_destroy = true
}
```

**`ignore_changes = [...]`** — tells Terraform to stop caring about
changes to specific arguments, even if they drift from what your code
says. Extremely useful for values that legitimately change outside
Terraform's control — for example, if an Azure auto-scaling feature
changes a VM's instance count on its own, and you don't want Terraform
to fight it back to your original number every single run.

```hcl
lifecycle {
  ignore_changes = [tags["LastModifiedBy"]]
}
```

**`replace_triggered_by = [...]`** — forces a resource to be replaced
whenever a *different* resource or value changes, even if this
resource's own arguments didn't change at all. Advanced, but useful
for forcing a VM extension to redeploy whenever a script file's
content changes (similar to the `filesha256()` pattern from earlier
guides).

### A realistic combination

```hcl
resource "azurerm_storage_account" "sa" {
  name                     = "saprodcritical001"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "GRS"

  lifecycle {
    prevent_destroy        = true
    create_before_destroy  = true
    ignore_changes          = [tags]
  }
}
```

**Beginner warning:** `prevent_destroy` and `create_before_destroy`
can conflict in confusing ways with `count`/`for_each` in certain
scenarios, and `ignore_changes` arguments must reference actual
attribute names in your resource — a typo here fails silently in
older Terraform versions in ways that are hard to notice. Test
lifecycle changes carefully with `terraform plan` before trusting them
in anything important.

---

## MINI PROJECT 7 — Protect a Resource From Accidental Deletion

**Goal:** experience `prevent_destroy` actually stopping you.

**Steps:**
1. Add `lifecycle { prevent_destroy = true }` to your resource group
   from any earlier project
2. Run `terraform apply`
3. Now try `terraform destroy` — confirm Terraform refuses and shows
   an error explaining why
4. Remove the `lifecycle` block, run `terraform apply` again (this
   updates the resource to no longer be protected)
5. Now run `terraform destroy` — confirm it succeeds this time

---
---

# 12. Constraints & Validation — Enforcing Rules on Your Inputs

### Explain it like you've never coded

We touched on this earlier when correcting the `environment`
variable example, but let's build the full picture. "Constraints" in
Terraform come in two layers:

**Layer 1 — Type constraints** (built into the `type` argument):

```hcl
variable "instance_count" {
  type = number   # rejects anything that isn't a valid number
}

variable "is_production" {
  type = bool     # rejects anything that isn't true/false
}

variable "allowed_regions" {
  type = list(string)   # rejects anything that isn't a list of text values
}

variable "tags" {
  type = map(string)    # rejects anything that isn't key-value text pairs
}
```

This is the most basic safety net — Terraform simply refuses to
accept the wrong *shape* of data at all, with a clear error message,
before your code even runs.

**Layer 2 — Custom `validation` blocks** (business-logic rules on top
of the type):

```hcl
variable "environment" {
  type    = string
  default = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}
```

A `type` constraint alone would accept `"banana"` as a valid string —
it IS a string, after all. The `validation` block adds a *business
rule* on top: "yes, it's a valid string, but is it one of the specific
values we actually allow?"

You can have **multiple validation blocks** on one variable, each
checking something different, each with its own tailored error
message:

```hcl
variable "vm_size" {
  type    = string
  default = "standard_D2s_v3"

  validation {
    condition     = length(var.vm_size) >= 2 && length(var.vm_size) <= 30
    error_message = "vm_size must be between 2 and 30 characters."
  }

  validation {
    condition     = strcontains(lower(var.vm_size), "standard")
    error_message = "vm_size must contain the word 'standard'."
  }
}
```

**Why split these into two blocks instead of one combined
condition?** Because each gets its own precise error message. If you
combined both rules with `&&` into one `condition`, a user violating
*either* rule sees the exact same generic message — leaving them
guessing which problem they actually have.

### `precondition` and `postcondition` — validation tied to resources, not just variables

Sometimes a rule depends on the relationship *between* things, not
just one variable in isolation — that's what `precondition` (checked
before a resource is created) and `postcondition` (checked after) are
for, placed inside a resource's `lifecycle` block:

```hcl
resource "azurerm_storage_account" "sa" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  lifecycle {
    precondition {
      condition     = length(var.storage_account_name) <= 24
      error_message = "Azure Storage Account names must be 24 characters or fewer."
    }
  }
}
```

---

## MINI PROJECT 8 — Build a Fully Validated Variable Set

**Goal:** create a variables file that would genuinely protect a team
from common mistakes.

**Steps:**
1. Create a `location` variable that only accepts `"eastus"`,
   `"westus"`, or `"westeurope"` (validation + `contains()`)
2. Create a `vm_size` variable that must be between 2-30 characters
   AND must start with the text `"standard"` (two separate validation
   blocks)
3. Create an `environment` variable, and add a `precondition` inside a
   resource's `lifecycle` block checking that if `environment ==
   "prod"`, a separate `enable_backup` variable must be `true`
   (this connects two variables' logic together — read the Terraform
   docs on `precondition` syntax if you get stuck, this is
   intentionally a stretch)
4. Test every rule by deliberately passing invalid values and reading
   the exact error message Terraform gives you

---
---

# 13. Locals & Functions — Recap + Reference Table

You've already covered this in depth in earlier guides in this
conversation, so this section is intentionally a compact reference
rather than a full re-explanation. Refer back to the dedicated
"Terraform Locals — Deep Dive" and "Enterprise Functions" guides for
the full walkthroughs.

### The one-line recap

```hcl
locals {
  clean_name = lower(replace(var.project_name, " ", "-"))
}
```

`locals` = a named, reusable internal calculation. `local.name` = how
you reference it. Cannot be overridden from outside the module —
unlike `variable`, there's no `-var` flag or `.tfvars` entry for a
local.

### The functions you'll use constantly, one-line reminders

| Function | One-line reminder |
|---|---|
| `lower()` / `upper()` | force casing |
| `replace()` | find & replace |
| `format()` | template a string |
| `merge()` | combine maps, later argument wins |
| `lookup()` | safe map read with fallback |
| `coalesce()` | first non-null/non-empty **value** wins |
| `try()` | first expression that **doesn't error** wins |
| `cidrsubnets()` | carve VNet address space into subnets |
| `jsonencode()` / `jsondecode()` | object ↔ JSON |
| `length()` | count items/characters |
| `contains()` | is value in this list |

---
---

# 14. Data Sources — Reading Things Terraform Didn't Create

### Explain it like you've never coded

Everything so far has been about Terraform *creating* new things. But
often you need to reference something that **already exists** in
Azure — maybe a shared virtual network your networking team manages
separately, or an existing resource group you don't own. A `data`
block reads information about existing infrastructure, without
managing or changing it.

```hcl
data "azurerm_resource_group" "existing" {
  name = "rg-shared-networking"
}

resource "azurerm_storage_account" "sa" {
  name                     = "sademo001"
  resource_group_name      = data.azurerm_resource_group.existing.name
  location                 = data.azurerm_resource_group.existing.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}
```

**The core distinction:** `resource` blocks show up in your state file
as things Terraform *manages* — it will try to update or delete them
if your code changes. `data` blocks are **read-only** — Terraform
looks up the current real values but never tries to change that
resource group itself. This is exactly the tool for "I need to use
something that belongs to a different team/project."

---
---

# 15. Modules — Packaging Code for Reuse

### Explain it like you've never coded

Imagine every one of your mini projects so far had to redefine
"resource group + storage account + tags" from scratch each time. A
**module** lets you package a group of resources into a reusable
unit, like a function in other programming languages — write it once,
call it many times with different inputs.

### A minimal module structure

```
my-project/
  main.tf              <- calls the module
  modules/
    storage/
      main.tf           <- the module's actual resources
      variables.tf       <- the module's inputs
      outputs.tf          <- the module's outputs
```

`modules/storage/main.tf`:
```hcl
resource "azurerm_storage_account" "sa" {
  name                     = var.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}
```

`modules/storage/variables.tf`:
```hcl
variable "storage_account_name" { type = string }
variable "resource_group_name"  { type = string }
variable "location"              { type = string }
```

`modules/storage/outputs.tf`:
```hcl
output "storage_account_id" {
  value = azurerm_storage_account.sa.id
}
```

Root `main.tf` (calling the module):
```hcl
resource "azurerm_resource_group" "rg" {
  name     = "rg-mini-project"
  location = "eastus"
}

module "storage" {
  source                = "./modules/storage"
  storage_account_name  = "sademo001"
  resource_group_name   = azurerm_resource_group.rg.name
  location               = azurerm_resource_group.rg.location
}

output "storage_id" {
  value = module.storage.storage_account_id
}
```

Notice: to reference something a module produced, you use
`module.<module_label>.<output_name>` — the same dot-notation pattern
as everything else in Terraform.

**Beginner note:** don't reach for modules too early. Writing your
first several projects as flat, single-file configurations (like
every mini project above) is the right way to actually learn what's
happening. Modules become genuinely valuable once you notice yourself
copy-pasting the *same group* of resources across multiple projects —
that repetition is the actual signal that it's time to extract a
module.

---
---

# 16. Capstone Project — Everything Combined

**Goal:** one project using every concept from this entire guide.

**Requirements:**
1. A `provider.tf` with proper version constraints (Section 3)
2. A `variables.tf` with at least 5 variables, including:
   - One with a custom `validation` block (Section 12)
   - One `map(string)` used to drive a `for_each` (Section 9)
3. A `locals.tf` computing at least one cleaned/derived name using
   string functions (Section 13)
4. A resource group, created once (not looped)
5. A set of 2-3 storage accounts created via `for_each` from your map
   variable (Section 9), each with different `account_replication_type`
   values pulled from the map
6. A `lifecycle` block on the resource group with `prevent_destroy =
   true` (Section 11)
7. A `data` block reading an existing resource (can be the resource
   group you just created, referenced as if it were external, just to
   practice the syntax) (Section 14)
8. At least 3 outputs, one of which is marked `sensitive` (Section 6)
9. Successfully run `terraform init`, `plan`, and `apply`
10. Remove the `prevent_destroy` lifecycle rule, then successfully run
    `terraform destroy` to clean everything up

If you can build this from the section descriptions alone, without
looking back at the earlier code samples, you've genuinely absorbed
the material in this guide.

---
---

# 17. Command Cheat Sheet

```bash
# Setup
terraform init                    # download providers, set up the project (run once per folder)
terraform init -upgrade            # re-download providers, allowing newer versions within constraints

# The core loop
terraform plan                     # preview changes without applying them
terraform plan -var="key=value"     # preview with a variable override
terraform plan -var-file="x.tfvars"  # preview using a specific .tfvars file
terraform apply                     # apply changes (will ask for confirmation)
terraform apply -auto-approve        # apply without the yes/no prompt (use carefully)
terraform destroy                    # delete everything this project manages

# Inspecting state
terraform state list                 # list everything currently tracked
terraform state show <resource>       # show full detail of one tracked resource
terraform show                         # show the whole current state

# Code quality
terraform fmt                          # auto-format your .tf files to standard style
terraform validate                      # check for syntax errors without contacting Azure

# Exploration / learning
terraform console                        # interactive expression tester (great for learning functions)
terraform output                          # show all outputs from the last apply
terraform output <name>                    # show one specific output

# Azure CLI (used alongside Terraform)
az login                                    # authenticate your terminal to Azure
az account show                              # confirm which subscription is active
az account list --output table                # list all subscriptions you have access to
```

---

## Your Suggested Path Through This Guide

Don't try to absorb this in one sitting. A realistic pace for someone
with zero coding background:

- **Days 1-2:** Sections 0-4 (setup through resources) + Mini Project 1
- **Days 3-4:** Sections 5-7 (variables, outputs, state) + Mini Projects 2-4
- **Days 5-6:** Sections 8-10 (count/for_each) + Mini Projects 5-6
- **Day 7:** Section 11 (lifecycle) + Mini Project 7
- **Day 8:** Section 12 (constraints) + Mini Project 8
- **Day 9:** Sections 13-15 (locals/functions recap, data sources, modules)
- **Day 10+:** Section 16, the capstone — take your time, don't rush this one

By the time you finish the capstone unassisted, you will genuinely
know more practical Terraform than a large share of people who've
been "using" it for months by copy-pasting from Stack Overflow without
understanding why any of it works.
