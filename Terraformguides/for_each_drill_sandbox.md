# `for_each` Drill Sandbox
## Zero Cost. Zero Azure. Zero Waiting. Just Reps.

---

## Why This Exists

Azure applies take 2-20 minutes and cost real money. That is a
terrible environment for building muscle memory — you type one
thing, wait five minutes, and by the time you see the result
you've forgotten what you were testing.

This sandbox uses `local_file` — a Terraform resource that just
creates plain text files on your own computer. `terraform apply`
finishes in **under one second**. No Azure login needed. No cost.
No waiting. You can run this drill 50 times in the next hour if
you want to.

**Do these drills in order. Do not skip to Azure until Drill 4
feels boring, not confusing.**

---

## Setup (One Time)

```powershell
mkdir C:\Practice\for-each-drills
cd C:\Practice\for-each-drills
```

```hcl
# providers.tf — same for every drill in this sandbox
terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}
```

---

## DRILL 1 — `for_each` with a SET (the absolute simplest form)

**Goal:** Create 3 text files, one per name, using ONE resource block.

```hcl
# main.tf
resource "local_file" "greeting" {
  for_each = toset(["alice", "bob", "carol"])
  filename = "${path.module}/output/${each.value}.txt"
  content  = "Hello, ${each.value}!"
}
```

**Before you run it — predict on paper:**
1. How many files will be created?
2. What will each filename be?
3. What will be written inside `alice.txt`?

**Now run it:**
```powershell
terraform init
terraform apply -auto-approve
```

**Check your prediction:**
```powershell
Get-ChildItem output
Get-Content output\alice.txt
```

**The actual drill — do this 5 times, changing ONE thing each time:**

```
Round 1: Change the set to 4 names instead of 3. Predict, run, check.
Round 2: Remove "bob" from the set. Predict what happens to bob.txt
         BEFORE running. Run terraform apply -auto-approve. Was
         bob.txt actually deleted?
Round 3: Change each.value to each.key in BOTH places. Run it.
         Compare the output to Round 1 — is anything different?
         (Answer should be: no difference, because in a set they're identical)
Round 4: Rename the resource label from "greeting" to "hello".
         Predict what terraform plan shows before running it.
Round 5: Delete the whole file, undo everything: terraform destroy -auto-approve
```

**Stop and answer before moving on:**
Write one sentence, in your own words, explaining why `each.key`
and `each.value` were identical in this drill. If you can't
answer this in one sentence, redo Drill 1 rounds 1-3 again before
continuing.

---

## DRILL 2 — `for_each` with a MAP (key ≠ value)

**Goal:** Same file-creation idea, but now each file's NAME and
its CONTENT are two different pieces of information.

```hcl
# main.tf — replace Drill 1's content with this
resource "local_file" "greeting" {
  for_each = {
    "alice" = "Software Engineer"
    "bob"   = "Product Manager"
    "carol" = "Designer"
  }
  filename = "${path.module}/output/${each.key}.txt"
  content  = "${each.key} works as a ${each.value}."
}
```

**Before you run it — predict on paper:**
1. What will `alice.txt` contain, word for word?
2. If you swapped `each.key` and `each.value` in the `content`
   line only (not the filename), what would `alice.txt` say instead?

**Run it, check your prediction:**
```powershell
terraform destroy -auto-approve    # clean slate from Drill 1 first
terraform apply -auto-approve
Get-Content output\alice.txt
```

**The actual drill — 5 rounds:**

```
Round 1: Add a 4th person to the map. Predict the new file's
         content before running.
Round 2: Change "carol"'s value to something with a space and a
         number, like "Senior Designer II". Does it work fine?
         (It should — map values can be any valid string)
Round 3: DELIBERATELY swap each.key and each.value in the
         filename line only: filename = "${each.value}.txt"
         Run terraform plan. What error, if any, do you get?
         (Hint: think about what "Software Engineer.txt" as a
         filename with a space in it would even mean)
Round 4: Fix Round 3's mistake, revert filename back to each.key.
Round 5: terraform destroy -auto-approve
```

**Stop and answer before moving on:**
In your own words: what is the practical difference between
`each.key` and `each.value` when using a map? Write it as if
explaining to someone who has never seen Terraform.

---

## DRILL 3 — `for_each` with `map(object({...}))`

**Goal:** Each item now needs THREE pieces of information, not
just a name and one value.

```hcl
# main.tf — replace again
resource "local_file" "profile" {
  for_each = {
    "alice" = {
      role  = "Software Engineer"
      years = 5
    }
    "bob" = {
      role  = "Product Manager"
      years = 8
    }
  }
  filename = "${path.module}/output/${each.key}.txt"
  content  = "${each.key} is a ${each.value.role} with ${each.value.years} years experience."
}
```

**Before you run it — predict:**
1. Write out, word for word, what `alice.txt` will contain.
2. What happens if you try `each.value.role` but you named the
   field `job_title` instead of `role` in the object? Predict the
   error category (not exact wording) — will it fail at `plan` or at `apply`?

**Run it:**
```powershell
terraform apply -auto-approve
Get-Content output\alice.txt
```

**The actual drill — 4 rounds:**

```
Round 1: Add a 3rd field to each object, like "department".
         Update the content line to include it. Predict, run, check.
Round 2: Deliberately misspell "role" as "rol" in ONE person's
         object only (leave the other correct). Run terraform plan.
         Read the actual error message word for word — where does
         it point you to?
Round 3: Fix the typo from Round 2.
Round 4: terraform destroy -auto-approve
```

**Stop and answer:**
Explain in one sentence why `each.value` in this drill is
different from `each.value` in Drill 2, even though both are
called `each.value`.

---

## DRILL 4 — `dynamic` Block (the one that trips everyone)

**Goal:** ONE file, with MULTIPLE repeated sections inside it —
not multiple separate files. This is the resource-vs-nested-block
distinction, made physical.

`local_file` doesn't have a nested block type, so we'll use a
different local resource to demonstrate this exact mechanic —
`local_file` with a templated content built using a `for`
expression first, which mirrors the mental model, then the true
`dynamic` block syntax using a real (free) resource type.

### Part A — The Concept, Using a `for` Expression First

```hcl
resource "local_file" "team_roster" {
  filename = "${path.module}/output/roster.txt"

  content = join("\n", [
    for name, info in var.team : "${name}: ${info.role} (${info.years} yrs)"
  ])
}

variable "team" {
  type = map(object({
    role  = string
    years = number
  }))
  default = {
    "alice" = { role = "Engineer", years = 5 }
    "bob"   = { role = "Manager", years = 8 }
    "carol" = { role = "Designer", years = 3 }
  }
}
```

**Run it:**
```powershell
terraform apply -auto-approve
Get-Content output\roster.txt
```

You should see THREE LINES inside ONE FILE. This is the exact
shape of what `dynamic` does inside a resource — one resource,
multiple repeated pieces of content inside it — except `dynamic`
generates repeated Terraform BLOCKS instead of repeated TEXT LINES.

### Part B — True `dynamic` Block, Using `random_pet` (Free, No Azure)

```hcl
terraform {
  required_providers {
    local  = { source = "hashicorp/local", version = "~> 2.0" }
    random = { source = "hashicorp/random", version = "~> 3.0" }
  }
}

resource "random_pet" "team_pets" {
  for_each = var.team
  prefix   = each.key
}
```

This isn't quite `dynamic` yet — it's still resource-level
`for_each`, which you already understand from Drills 1-3. To see
a TRUE `dynamic` block, we need a resource that actually HAS a
repeatable nested block type. `local_file` doesn't have one.
**This is exactly why `dynamic` felt more abstract in the Azure
guide** — it only makes sense on resources complex enough to have
nested repeatable blocks, and none of the free local resources
have this. NSGs, Action Groups, and Application Gateways do.

### Part C — Bridging Back to Azure, Now With Drills 1-3 Solid

Now that `each.key`/`each.value` and `map(object)` feel automatic
from Drills 1-3, re-read this ONE piece from the original guide,
slowly, out loud if it helps:

```hcl
resource "azurerm_network_security_group" "nsg" {
  # ... other config ...

  dynamic "security_rule" {              # ← label = "security_rule"
    for_each = var.firewall_rules        # ← SAME for_each you already know

    content {
      name     = security_rule.key       # ← NOT each.key — matches the label above
      priority = security_rule.value.priority
    }
  }
}
```

**The only genuinely new thing in `dynamic` — everything else is
Drill 1-3 knowledge — is this single fact:**

```
Resource-level for_each  → the iterator is called "each"
dynamic block for_each    → the iterator is called <whatever you
                             labeled the dynamic block>
```

That's it. That's the entire delta between what you already know
and what confused you. Not a new concept — a renamed variable,
for a structural reason (multiple dynamic blocks in one resource
need to be told apart).

---

## Self-Check — Are You Ready to Go Back to Azure?

Answer these five questions from memory, no looking back at the guide:

```
1. for_each = toset([...]) — what type of collection is this?
2. In a map, is each.key always different from each.value? Always
   the same? Depends?
3. You have: metric_alerts = { "cpu-high" = { severity = 2 } }
   How do you access the number 2 inside a for_each resource?
4. True or false: a dynamic block creates multiple separate
   Azure resources.
5. Inside a dynamic "email_receiver" block's content{}, what do
   you type instead of each.key?
```

**Answers:**
```
1. A set (converted from a list via toset())
2. Depends — same in a set, different in a map
3. each.value.severity
4. FALSE — it creates multiple blocks inside ONE resource
5. email_receiver.key
```

If you got all 5 right without looking, you're ready — go back to
any MRB project with a `for_each` or `dynamic` and it should feel
noticeably calmer than before. If you missed any, redo that
specific drill (1 for Q1-2, 3 for Q3, 4 for Q4-5) two more times.

---

## The Honest Truth About Why This Was Hard

`for_each` and `dynamic` are not intuitive the first, second, or
even fifth time — for anyone. What makes them click is not a
better explanation (you already had a good one), it's **enough
reps with instant feedback** that your brain stops treating
`each.key` as something to look up and starts treating it as
something you just know, the way you don't think about which
hand holds a fork anymore.

This sandbox costs nothing and takes seconds per iteration.
Use it as many times as you need — there is no "you should be
past this by now." Muscle memory has its own timeline.

---

*Standalone practice sandbox — no Azure account, no cost, no
cleanup needed beyond deleting the local `output/` folder.*
