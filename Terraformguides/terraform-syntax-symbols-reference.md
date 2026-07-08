# Terraform Syntax Decoder — Braces, Brackets, Parentheses & Naming Rules
## A Beginner's Reference for "Which Symbol Goes Here?"

---

## Why This Guide Exists

You worked out something genuinely useful on your own: that Azure
resource arguments tend to hint at their own shape through their
name — plural names usually want a list, singular names usually want
a single value. That instinct is worth keeping. This guide takes that
starting point and builds it into a complete reference: every bracket,
brace, and parenthesis Terraform uses, what each one actually means,
and a repeatable way to check yourself instead of guessing — since you
asked for exactly that, a system rather than trial and error.

Written assuming zero prior coding background. Every symbol gets a
plain-English explanation before any code.

---

## Table of Contents

1. The Building Blocks at a Glance
2. Curly Braces `{ }` — Two Completely Different Jobs
3. Square Brackets `[ ]` — Four Different Jobs
4. Parentheses `( )` — Two Jobs
5. The Singular vs Plural Naming Convention
6. The "Exception" Explained Properly
7. Reading the Official Docs — Required, Optional, Computed
8. Dot Notation — How to Read `a.b.c`
9. The `=` vs `=>` Confusion
10. Putting It All Together — A Step-by-Step Mental Checklist
11. Full Worked Example, Annotated Line by Line
12. Common Symbol Mistakes and Their Exact Error Messages
13. Complete Cheat Sheet

---

## 1. The Building Blocks at a Glance

Before the details, here is every symbol this guide covers, with a
one-line reminder of its job. You don't need to memorize this table —
just know it's here to jump back to.

| Symbol | Plain-English job |
|---|---|
| `{ }` | Wraps either a **block** (a labeled section of config) or a **map/object value** |
| `[ ]` | Wraps either a **list value**, a **list type**, an **index**, or the **splat** shortcut |
| `( )` | Wraps the **inputs to a function**, or the **inner type** of a list/map/object type |
| `" "` | Wraps a literal **string** (text) |
| `${ }` | Inserts a value **inside** a string |
| `%{ }` | Inserts a loop or if/else **inside** a string |
| `=` | Assigns a value to an argument |
| `=>` | Only appears inside a `for` expression building a map — separates the key from the value |
| `.` | Walks down into a nested value (an object's field, a resource's attribute) |

---

## 2. Curly Braces `{ }` — Two Completely Different Jobs

This is the single biggest source of confusion for beginners, because
the *same* symbol does two unrelated things depending on context.

### Job 1 — Defining a block

A **block** is a labeled section of configuration — think of it as a
labeled folder holding a group of related settings.

```hcl
resource "azurerm_resource_group" "rg" {
  name     = "my-rg"
  location = "eastus"
}
```

Here, `{ }` marks the start and end of everything that belongs to
*this specific resource*. You recognize a block because it always
comes right after one or more **quoted labels** (`"azurerm_resource_group"`,
`"rg"`) — the labels tell you what kind of thing you're defining and
what to call this particular instance of it.

Other block types you'll see constantly: `variable "x" { }`,
`locals { }` (no label needed here), `output "x" { }`,
`provider "azurerm" { }`, `module "x" { }`.

### Job 2 — Writing a map/object value

The exact same `{ }` symbol also wraps a **map** — a collection of
`key = value` pairs, with no block labels in front of it:

```hcl
locals {
  common_tags = {
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}
```

Here, `common_tags` is being *given the value* of a map. Notice there
are no quoted labels sitting directly before this `{` — it's simply
appearing on the right-hand side of an `=` sign, as a value, not as
the start of a new named block.

### How to tell which one you're looking at

Ask: **is this `{` immediately preceded by an `=` sign, or by a quoted
label / bare block name?**

```hcl
resource "azurerm_resource_group" "rg" {    # preceded by labels -> BLOCK
  tags = {                                   # preceded by "=" -> MAP VALUE
    Environment = "dev"
  }
}
```

---

## 3. Square Brackets `[ ]` — Four Different Jobs

### Job 1 — A list value

The straightforward one — a literal collection of items, in order,
separated by commas:

```hcl
address_prefixes = ["10.0.1.0/24"]
dns_servers      = ["1.1.1.1", "8.8.8.8"]
```

A list with only one item still needs the brackets — `["10.0.1.0/24"]`
is a list containing one string; `"10.0.1.0/24"` alone (no brackets)
is just a string, a completely different thing to Terraform even
though a human reading it might think "well, there's only one value
either way." This distinction is exactly the singular/plural rule
covered in Section 5.

### Job 2 — Part of a type constraint

When you *declare* a variable, you often state what type of value it's
allowed to hold. If that type is a list, you'll see `list(...)` — note
this specific use is actually parentheses wrapping the word `list`,
not square brackets on their own (covered fully in Section 4) — but
you'll also see plain square brackets used to describe a **tuple**
type, a fixed-length list where each position can be a different type:

```hcl
variable "network_config" {
  type = tuple([string, string, number])
}
```

### Job 3 — Indexing (picking one item out of a list)

Square brackets containing a *number* pick out one specific item from
a list, counting from `0`:

```hcl
var.subnet_cidr_blocks[0]   # the FIRST item in the list
var.subnet_cidr_blocks[1]   # the SECOND item
```

### Job 4 — The splat expression `[*]`

A square bracket containing just an asterisk is special shorthand
meaning "grab this same thing from every item in the collection at
once":

```hcl
azurerm_subnet.example[*].id
```

This says: "from every subnet that was created, give me its `id`, as
a list." Covered in full depth, with its real limitations, in this
series' expressions reference guide — the short version: it only works
on lists, not on maps.

---

## 4. Parentheses `( )` — Two Jobs

### Job 1 — Calling a function

Parentheses immediately after a word mean "run this function, using
whatever is inside the parentheses as its input":

```hcl
lower("MyStorageAccount")
length(var.subnet_cidr_blocks)
lookup(local.vm_sizes, var.environment, "Standard_B1s")
```

The word right before the `(` is the function's name. Everything
between the parentheses (separated by commas if there's more than one)
is what you're handing that function to work with.

### Job 2 — Wrapping the "inner type" in a type constraint

When declaring a variable's type, several type keywords take
parentheses describing what's *inside* the collection:

```hcl
variable "subnet_cidr_blocks" {
  type = list(string)     # a list, where every item is a string
}

variable "vm_sizes" {
  type = map(string)      # a map, where every value is a string
}

variable "network_settings" {
  type = object({
    cidr = string
    dns  = list(string)
  })
}
```

This looks similar to a function call (Job 1) but means something
different: `list(string)` isn't "run the function called list, passing
in the word string" — it's "the type is a list, and specifically a
list of strings." Terraform's type-constraint language reuses the same
parentheses symbol for this, which is exactly why it can look
confusing at first — the way to tell them apart is context: this
specific pattern only ever appears on the right-hand side of
`type = `, never as a plain value elsewhere in your code.

### A brief third case — grouping

Parentheses can also simply group part of an expression to control
evaluation order, the same as in ordinary arithmetic:

```hcl
priority = 100 + (index * 10)
```

This is the least common use you'll encounter as a beginner, included
for completeness.

---

## 5. The Singular vs Plural Naming Convention

This is your own Rule 1, validated and refined. It is genuinely
useful — worth keeping as your first instinct — with one important
precision added: **this is a naming convention followed by the people
who wrote the Azure provider, not a grammar rule enforced by the
Terraform language itself.** HCL (Terraform's language) has no idea
what an English plural is — it doesn't parse word endings or check
grammar. The *provider authors* chose to name plural-shaped arguments
with plural-sounding words, consistently enough that it becomes a
reliable pattern to lean on — but it's a human convention, not a
built-in language rule, which matters because conventions can have
exceptions (Section 6) in a way that actual language rules can't.

With that precision in place, the pattern itself holds up well:

**Plural-sounding name → expects `[ ]`**

```hcl
address_prefixes       = ["10.0.1.0/24"]
network_interface_ids  = [azurerm_network_interface.nic.id]
dns_servers             = ["1.1.1.1", "8.8.8.8"]
```

**Singular-sounding name → no `[ ]`**

```hcl
priority             = 100
location              = "southindia"
resource_group_name   = "msvan-dev-rg"
```

A useful mental image: a plural name is a **bucket** — even if you're
only putting one thing in it today, it's still shaped like a
container, and Terraform expects you to hand it a container (`[ ]`),
not the bare item. A singular name expects you to hand over the item
itself, with nothing wrapped around it.

---

## 6. The "Exception" Explained Properly

Your example — `address_space` on the Virtual Network resource — is
worth examining closely, because it teaches the actual limit of the
grammar heuristic better than any rule that always works would.

```hcl
resource "azurerm_virtual_network" "vnet" {
  address_space = ["10.0.0.0/16"]   # still needs brackets, despite sounding singular
}
```

"Space" is grammatically singular — there's no natural plural "spaces"
implied by the word the way "prefixes" or "servers" clearly signal
more-than-one. But a Virtual Network can genuinely be assigned more
than one independent address range (`["10.0.0.0/16", "172.16.0.0/16"]`),
so the underlying *type* is a list regardless of how the English word
"reads." This isn't really an exception to a formal rule — there was
never a formal rule, only a convention — it's a case where the
convention's usual signal (plural word = list) and the actual
underlying type happen to point in different directions.

**A second real example worth knowing, in the opposite direction:**
Azure Subnets have both an older, singular `address_prefix` argument
(now deprecated) and the current, plural `address_prefixes` — and even
though the current plural version is a list type, in everyday use you
almost always put exactly **one** CIDR block in it:

```hcl
resource "azurerm_subnet" "subnet" {
  address_prefixes = ["10.0.1.0/24"]   # a list containing just one item — still needs [ ]
}
```

This is the precise, important distinction: "is the *type* a list"
and "will I actually put more than one value in it" are two separate
questions. A plural-named, list-typed argument might, in practice,
almost always hold a single item — the brackets are still required
because the *type* is a list, independent of how many items you
happen to be putting in it today.

**The takeaway:** treat the grammar heuristic as a fast first guess,
correct maybe 95% of the time as you already estimated — but for
anything you're not fully sure about, or anything expensive to get
wrong, confirm against the actual schema. That's Section 7.

---

## 7. Reading the Official Docs — Required, Optional, Computed

Every resource's page on the Terraform Registry
(`registry.terraform.io`) has an "Argument Reference" section listing
every field, with three pieces of information for each one: whether
you must provide it, and what type it expects.

**`(Required)`** — you must set this, or Terraform refuses to proceed
with an error telling you it's missing.

**`(Optional)`** — you may leave this out; Terraform (or Azure) will
use a sensible default if you don't set it.

**`(Computed)`** — worth adding since it's easy to miss and wasn't in
your original notes: this means the value is generated *by Azure*
after the resource is created — you never set it yourself, you only
*read* it afterward (in an output, or as a reference from another
resource). A resource's `id` is the classic example — you never type
in an `id` value; Azure assigns one, and Terraform makes it available
to you afterward.

**The type shown in parentheses tells you the bracket question directly:**

```
priority            (Required) (Number)              -> no brackets
source_port_ranges  (Optional) (List of String)       -> needs [ ]
tags                (Optional) (Map of String)        -> needs { }
location             (Required) (String)                -> no brackets
```

Whenever the grammar heuristic from Section 5 leaves you unsure, this
is the actual source of truth — not a guess, not a convention, the
literal type the provider's own code expects.

---

## 8. Dot Notation — How to Read `a.b.c`

You'll see chains of words connected by periods constantly. Each dot
means "go one level deeper into this thing." Reading left to right:

```hcl
azurerm_resource_group.rg.location
```

- `azurerm_resource_group` — the *type* of resource
- `.rg` — the *specific instance* you named (the local label you chose)
- `.location` — the *specific attribute* you want from that instance

The same pattern applies everywhere:

```hcl
var.environment              # a variable named "environment"
local.common_tags            # a local value named "common_tags"
data.azurerm_subnet.exsub.id # a data source's specific attribute
each.value.vm_size           # inside a for_each, one field of the current item
count.index                  # the built-in current-iteration number
```

If a resource uses `count` or `for_each`, you need one extra step
before the final attribute — an index or a key — exactly as covered in
Section 3's indexing rules:

```hcl
azurerm_subnet.example[0].id        # count-based: numeric index
azurerm_subnet.example["10.0.1.0/24"].id   # for_each-based: key
```

---

## 9. The `=` vs `=>` Confusion

Ordinary argument assignment always uses a single `=`:

```hcl
name     = "my-rg"
priority = 100
```

The two-character `=>` only appears in one specific place: inside a
`for` expression that's building a **map** (not a list). It separates
what becomes the new key from what becomes the new value:

```hcl
{for name, size in var.vm_sizes : name => upper(size)}
```

If you're not writing a `for` expression that produces a map, you will
never need `=>` — seeing it anywhere else in your own code is a strong
sign something's been copied from the wrong context.

---

## 10. Putting It All Together — A Step-by-Step Mental Checklist

When you're staring at an argument and unsure what to type, work
through these in order:

1. **Do I actually know this argument's exact type?** If yes, skip to
   step 4.
2. **Guess from the name** — does it sound plural (a container word)
   or singular (one specific thing)? This gets you the right answer
   most of the time, immediately, with no lookup needed.
3. **Still unsure, or is this something important/expensive to get
   wrong?** Open the Terraform Registry page for this exact resource,
   find the argument in the Argument Reference table, and read its
   type directly.
4. **Write the value:**
   - Type says `(String)` or `(Number)` or `(Bool)` → no brackets, just
     the raw value
   - Type says `(List of ...)` or `(Set of ...)` → wrap in `[ ]`, even
     if you're only providing one item
   - Type says `(Map of ...)` → wrap in `{ }` as `key = value` pairs

---

## 11. Full Worked Example, Annotated Line by Line

```hcl
resource "azurerm_network_security_group" "nsg" {   # BLOCK: labels before {, type=NSG, local name=nsg
  name                = "example-nsg"                 # singular name -> plain string, no brackets
  location             = azurerm_resource_group.rg.location   # dot notation: type.instance.attribute
  resource_group_name  = azurerm_resource_group.rg.name          # singular -> plain string

  security_rule {                                        # a NESTED block (no quoted label needed here)
    name                       = "allow-http"             # singular
    priority                   = 100                       # singular, Number type -> no quotes, no brackets
    direction                   = "Inbound"                   # singular string
    access                       = "Allow"                     # singular string
    protocol                     = "Tcp"                        # singular string
    source_port_range           = "*"                          # SINGULAR name -> single string, not a list
    destination_port_range      = "80"                         # also singular
    source_address_prefix       = "*"                          # singular ("prefix", not "prefixes")
    destination_address_prefix  = "*"                          # singular
  }

  tags = {                                                 # { } as a MAP VALUE, not a block (preceded by "=")
    Environment = "dev"                                     # key = value pair inside the map
    ManagedBy   = "Terraform"
  }
}
```

Notice `source_port_range` and `source_address_prefix` inside
`security_rule` are deliberately **singular** here (unlike the plural,
list-typed `address_prefixes` you'd see on a Subnet resource) — this
is a real Azure NSG rule field, and it's a good demonstration that the
same-sounding word (`prefix`) can be singular in one resource's schema
and plural in another's. This is exactly why Section 7's "check the
actual docs for this specific resource" step matters — the heuristic
is about the specific argument in front of you, not the word in isolation.

---

## 12. Common Symbol Mistakes and Their Exact Error Messages

**Forgetting brackets on a list-typed argument**

```hcl
address_prefixes = "10.0.1.0/24"     # missing [ ]
```
```
Error: Incorrect attribute value type
Inappropriate value for attribute "address_prefixes": list of string required.
```

**Adding brackets to a singular string argument**

```hcl
location = ["eastus"]     # brackets don't belong here
```
```
Error: Incorrect attribute value type
Inappropriate value for attribute "location": string required.
```

**Using `{ }` where a block was expected, with no preceding labels**

```hcl
"azurerm_resource_group" "rg" {   # missing the "resource" keyword before the labels
  name = "my-rg"
}
```
```
Error: Invalid block definition
```

**Mixing up `=` and `=>` outside a map-producing for expression**

```hcl
tags = {
  Environment => "dev"    # wrong symbol for a plain map
}
```
```
Error: Invalid character
```
(A plain map uses `=`, exactly like any other argument assignment —
`=>` belongs only inside a `for` expression building a map, as shown
in Section 9.)

---

## 13. Complete Cheat Sheet

```
{ }  — two jobs, tell apart by what comes right before the {
  preceded by quoted labels        -> BLOCK       resource "type" "name" { }
  preceded by "="                    -> MAP VALUE    tags = { key = "value" }

[ ]  — four jobs
  a literal list value               ["a", "b"]
  a tuple type constraint             list(string) / tuple([string, number])
  picking one item out (index)       var.list[0]
  splat — grab from every item        resource.name[*].attribute

( )  — two jobs
  calling a function                  lower("TEXT")
  the inner type in a type constraint list(string), map(number), object({...})

SINGULAR name -> plain value, no brackets    location = "eastus"
PLURAL name   -> needs [ ]                     dns_servers = ["1.1.1.1"]
  (a naming CONVENTION the provider authors follow — not a hard
   language rule — always confirm with the docs when unsure)

DOCS TYPE COLUMN -> the real source of truth
  (String) / (Number) / (Bool)   -> no brackets
  (List of ...) / (Set of ...)    -> [ ]
  (Map of ...)                      -> { }
  (Computed)                        -> you never SET this — Azure fills it in

DOT NOTATION
  type.instance_name.attribute        (a resource you created)
  data.type.instance_name.attribute   (a data source you read)
  var.name / local.name                (a variable or local)
  each.key / each.value / count.index  (inside a loop)

=  normal assignment, everywhere
=> ONLY inside a for-expression building a MAP: {for k,v in x : k => v}
```

---

*This reference covers: the two distinct meanings of curly braces
(block definitions versus map/object values) and how to tell them
apart by context, the four uses of square brackets (list values, tuple
type constraints, index access, and the splat expression), the two
uses of parentheses (function calls and type-constraint inner types,
plus brief expression grouping), a validated and precisely-reframed
version of the singular-versus-plural naming convention (clarified as
a provider-author convention rather than a formal language rule), a
detailed explanation of the address_space/address_prefixes "exception"
and what it actually demonstrates, reading Required/Optional/Computed
annotations and type columns in official Terraform Registry
documentation, dot notation for resources/data sources/variables/
locals/loop variables, the equals-sign versus map-arrow distinction, a
repeatable step-by-step decision checklist, a fully annotated
line-by-line worked example using a real Azure NSG resource, and the
exact error messages produced by the most common bracket-related
mistakes.*
