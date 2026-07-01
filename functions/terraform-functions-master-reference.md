# The Complete Terraform Functions Reference
## Every Built-in Function Used Across the 28 Days of Azure Terraform Series
### Master Compilation Guide | Azure Examples Throughout

---

## Before You Start

This is a **master reference guide** pulling together every Terraform
built-in function used across Days 1 through 17, explained from
scratch, with a note on exactly where each one appeared and why.

Each function entry follows the same structure:
```
WHAT IT DOES  -> plain description
SYNTAX        -> the exact call pattern
AZURE EXAMPLE -> a real snippet from this series
WHICH DAY     -> where it first appeared
GOTCHA        -> the mistake that came up with it (including real ones
                 from the video transcripts) and how to avoid it
```

A note before you rely on any specific behavior claim below: Terraform's
function set has evolved across provider/core versions, and a few
functions mentioned here (`strcontains`, `startswith`, `endswith`) were
added in relatively recent Terraform core releases. If you're on an
older Terraform version, verify a function exists in your version's
docs before depending on it — don't assume everything here is available
in every Terraform installation.

---

## Table of Contents

1. How Terraform Functions Work
2. Function Nesting
3. Numeric Functions
4. String Functions
5. Collection Functions
6. Type Conversion Functions
7. Encoding & File Functions
8. Date & Time Functions
9. Testing Functions with `terraform console`
10. Complete Function Index (Alphabetical)
11. Functions Organized by Problem Solved
12. Master Cheat Sheet

---

## 1. How Terraform Functions Work

A **function** is a named, built-in operation that takes one or more
input values and returns a single output value.

```hcl
function_name(input1, input2, ...)
```

**Critical rule:** Terraform does not support user-defined functions.
You are limited to the built-in library. Complex logic is built by
combining functions together (nesting) or using `for` expressions —
not by writing your own function.

Functions can be used almost anywhere a value is expected: inside
`locals`, resource arguments, `output` blocks, and `validation` /
`precondition` conditions.

---

## 2. Function Nesting

You wrap one function call inside another — the inner one evaluates
first, and its result becomes the input to the outer one.

```hcl
lower(replace(var.project_name, " ", "-"))
```

Reading inside-out:
```
1. replace(var.project_name, " ", "-")   ->  "Project-Alpha"
2. lower("Project-Alpha")                 ->  "project-alpha"
```

A three-level example:
```hcl
substr(
  lower(
    replace(var.storage_account_name, " ", "")
  ),
  0, 23
)
```
1. `replace(...)` removes spaces
2. `lower(...)` lowercases the result
3. `substr(...)` truncates to 23 characters

---

## 3. Numeric Functions

### `max()`
**Does:** Returns the largest value from a set of numbers.
**Syntax:** `max(number, number, ...)` or `max(list...)`
**Example:**
```hcl
locals {
  positive_costs = [for c in [-500, 75, -200, 150] : abs(c)]
  max_cost       = max(local.positive_costs...)   # -> 500
}
```
**Gotcha:** `max()` cannot take a list directly — you must expand it
with `...`:
```hcl
max(local.positive_costs)     # Error: tuple with 4 elements, number required
max(local.positive_costs...)  # Correct
```

### `min()`
**Does:** Returns the smallest value.
**Syntax:** `min(number, number, ...)` or `min(list...)`
**Example:** `min(local.positive_costs...)` → `75`
**Gotcha:** Same `...` expansion requirement as `max()`.

### `abs()`
**Does:** Returns the absolute (always-positive) value of a number.
**Syntax:** `abs(number)`
**Example:** `abs(-500)` → `500`

### `ceil()`
**Does:** Rounds a number up to the nearest whole integer.
**Syntax:** `ceil(number)`
**Example:** `ceil(2.1)` → `3` — useful for calculating "how many VMs
do I need" from a fractional capacity calculation.

### `floor()`
**Does:** Rounds a number down to the nearest whole integer.
**Syntax:** `floor(number)`
**Example:** `floor(4.9)` → `4`
**Gotcha:** `ceil` and `floor` are opposites — mixing them up in
capacity planning produces off-by-one errors.

### `length()` (also a collection function)
**Does:** Returns the character count of a string, or the element
count of a list/map/set.
**Syntax:** `length(value)`
**Example:**
```hcl
resource "azurerm_storage_account" "example" {
  count = length(var.storage_account_names)   # dynamic count from a list
}
```
**Gotcha:** On a string it counts characters, not words:
`length("Standard_D2s_v3")` → `15`.

---

## 4. String Functions

### `lower()`
**Does:** Converts a string to lowercase.
**Syntax:** `lower(string)`
**Example:** `lower(replace(var.project_name, " ", "-"))` →
`"project-alpha-resource"`
**Note:** Azure Storage Account names require all-lowercase, so this
function pairs constantly with storage account naming logic.

### `upper()`
**Does:** Converts a string to uppercase.
**Syntax:** `upper(string)`
**Example:** `upper(var.environment)` → `"DEV"`

### `replace()`
**Does:** Finds every occurrence of a substring and replaces it —
anywhere in the string, including the middle.
**Syntax:** `replace(string, substring_to_find, replacement)`
**Example:** `replace("Project Alpha", " ", "-")` → `"Project-Alpha"`
**Gotcha:** This is the function to reach for when `trim()` doesn't
do what you expect (see below).

### `trim()`
**Does:** Removes specified characters from the **start and end only**
— it does not touch the middle of the string.
**Syntax:** `trim(string, characters_to_remove)`
**Example:** `trim("!!alert!!", "!")` → `"alert"`
**Gotcha (a real mistake worth knowing):** `trim("h!ell!o", "!")`
returns `"h!ell!o"` unchanged — the `!` in the middle is untouched.
People expect `trim` to strip a character everywhere; it doesn't.
`replace()` is the correct tool for removing characters from anywhere
in a string.

### `trimprefix()`
**Does:** Removes a specific prefix, only if it matches exactly.
**Syntax:** `trimprefix(string, prefix)`
**Example:** `trimprefix("rg-myapp-prod", "rg-")` → `"myapp-prod"`
**Gotcha:** Silently returns the string unchanged if there's no match
— no error is raised.

### `trimsuffix()`
**Does:** Removes a specific suffix, only if it matches exactly.
**Syntax:** `trimsuffix(string, suffix)`
**Example:** `trimsuffix("myapp-prod-rg", "-rg")` → `"myapp-prod"`

### `substr()`
**Does:** Extracts a portion of a string starting at a given position,
for a given length.
**Syntax:** `substr(string, start_offset, length)`
**Example:** `substr(var.storage_account_name, 0, 23)` — enforces
Azure's 24-character storage account name limit.
**Gotcha:** The offset is zero-based — position `0` is the first
character.

### `split()`
**Does:** Breaks a string into a list, cutting at every occurrence of
a separator.
**Syntax:** `split(separator, string)` — **separator comes first**
**Example:** `split(",", "80,443,3306")` → `["80", "443", "3306"]`
**Gotcha (a documented real mistake):** Calling it backwards —
`split("80,443,3306", ",")` — treats the entire port string as the
separator and produces a single-element list, not the split you
expect. Memory trick: name the "knife" (separator) first, then the
thing you're cutting.

### `join()`
**Does:** The inverse of `split()` — combines a list into a single
string, inserting a separator between elements.
**Syntax:** `join(separator, list)`
**Example:** `join(",", ["80", "443", "3306"])` → `"80,443,3306"`
**Gotcha:** Produces a string. If a downstream resource actually needs
a map (e.g., for a `for_each` on a dynamic block), `join()` is the
wrong tool — you need a `for` expression producing a map instead.

### `chomp()`
**Does:** Removes a trailing newline character from the end of a
string.
**Syntax:** `chomp(string)`
**Example:** `chomp("hello\n")` → `"hello"`

### `format()`
**Does:** Builds a string from a template with placeholders
(`%s` for strings, `%d` for numbers) — similar to `printf`.
**Syntax:** `format(format_string, value1, value2, ...)`
**Example:**
```hcl
format("%s%s@%s", "m", "scott", "company.onmicrosoft.com")
# -> "mscott@company.onmicrosoft.com"
```
**Gotcha:** The number and order of `%s`/`%d` placeholders must match
the arguments that follow, in order.

### `strcontains()`
**Does:** Checks whether a string contains a substring — returns
`true`/`false`.
**Syntax:** `strcontains(string, substring)`
**Example:** `strcontains(lower(var.vm_size), "standard")`
**Gotcha:** Case-sensitive, so it's normally paired with `lower()`.
This is a different function from `contains()` (below), which
operates on collections, not strings — using `contains()` on a plain
string produces an "argument must be list/set/tuple" error.

### `startswith()`
**Does:** Checks whether a string begins with a given prefix.
**Syntax:** `startswith(string, prefix)`
**Example:** `startswith("rg-production", "rg-")` → `true`
**Note:** Available in Terraform 1.5+; verify version if targeting
older installations.

### `endswith()`
**Does:** Checks whether a string ends with a given suffix.
**Syntax:** `endswith(string, suffix)`
**Example:**
```hcl
validation {
  condition = endswith(var.backup_name, "-backup") || endswith(var.backup_name, "_backup")
}
```
**Note:** Also a Terraform 1.5+ addition.

---

## 5. Collection Functions

### `merge()`
**Does:** Combines two or more maps into one. On a key collision, the
value from the **last** map argument wins.
**Syntax:** `merge(map1, map2, ...)`
**Example:**
```hcl
merge({env="staging"}, {env="prod", owner="alice"})
# -> {env="prod", owner="alice"}
```
**Gotcha:** Argument order matters — `merge(A, B)` is not the same as
`merge(B, A)` when keys overlap.

### `concat()`
**Does:** Combines two or more lists into one longer list. Does not
remove duplicates.
**Syntax:** `concat(list1, list2, ...)`
**Example:**
```hcl
concat(["East US","West US","East US"], ["Central US"])
# -> ["East US","West US","East US","Central US"]
```
**Gotcha:** Duplicates remain — pair with `toset()` if you need
uniqueness.

### `contains()`
**Does:** Checks whether a value exists inside a list, set, or tuple.
**Syntax:** `contains(collection, value)`
**Example:**
```hcl
condition = contains(["dev", "staging", "prod"], var.environment)
```
**Gotcha:** Does not work on plain strings — for substring checks
inside a string, use `strcontains()` instead.

### `distinct()`
**Does:** Removes duplicate values from a list, preserving order and
keeping the first occurrence.
**Syntax:** `distinct(list)`
**Example:** `distinct(["a","b","a","c","b"])` → `["a","b","c"]`

### `flatten()`
**Does:** Collapses one level of nesting in a list-of-lists.
**Syntax:** `flatten(list_of_lists)`
**Example:** `flatten([["a","b"],["c","d"]])` → `["a","b","c","d"]`
**Gotcha:** Only flattens one level per call.

### `keys()`
**Does:** Returns a list of a map's keys, in alphabetical order.
**Syntax:** `keys(map)`
**Example:** `keys({env="prod", team="sre"})` → `["env","team"]`

### `values()`
**Does:** Returns a list of a map's values, in the order matching
`keys()`.
**Syntax:** `values(map)`
**Example:** `values({env="prod", team="sre"})` → `["prod","sre"]`

### `lookup()`
**Does:** Safely retrieves a value from a map by key, with a fallback
default if the key doesn't exist.
**Syntax:** `lookup(map, key, default_value)`
**Example:**
```hcl
lookup(var.vm_sizes, var.environment, "Standard_D2s_v3")
```
**Gotcha:** Without the third (fallback) argument, `lookup()` errors
if the key is missing — always supply a default in production code.

### `element()`
**Does:** Retrieves an item from a list by index position.
**Syntax:** `element(list, index)`
**Example:**
```hcl
element(["10.0.0.0/16", "10.0.1.0", 24], 0)   # -> "10.0.0.0/16"
```

---

## 6. Type Conversion Functions

### `tostring()`
Converts a compatible value to a string. `tostring(80)` → `"80"`.

### `tonumber()`
Converts a compatible string to a number. `tonumber("80")` → `80`.
Errors if the string isn't numeric.

### `tobool()`
Converts a compatible string to a boolean. Only accepts exact
`"true"`/`"false"`; `tobool("yes")` errors.

### `tolist()`
Converts a set or tuple into an ordered list. Note: converting a set
to a list sorts it — original insertion order is not guaranteed.

### `toset()`
Converts a list into a set, removing duplicates and discarding
ordering. **Critical use case:** `for_each` requires a map or set —
it rejects lists outright, so `toset(var.names)` is the standard fix
when you have a `list(string)` variable.

### `tomap()`
Converts a compatible object into a map. All resulting values must
share a compatible type.

---

## 7. Encoding & File Functions

### `file()`
**Does:** Reads a file's entire content and returns it as a string.
**Syntax:** `file(path)`
**Example:** `file("${path.module}/users.csv")`
**Gotcha:** Prefer `${path.module}/filename` over a bare relative path
so the reference works regardless of which directory `terraform` is
invoked from.

### `filebase64()`
**Does:** Reads a file and base64-encodes its content — required for
Azure's `custom_data` (cloud-init) field.
**Syntax:** `filebase64(path)`
**Example:** `custom_data = filebase64("${path.module}/user_data.sh")`
**Gotcha:** Passing raw script text into `custom_data` without base64
encoding will fail or be misinterpreted by the platform.

### `fileexists()`
**Does:** Returns `true`/`false` depending on whether a file exists
at a given path.
**Syntax:** `fileexists(path)`
**Use case:** Fail fast inside a `validation` block before attempting
to read a possibly-missing file.

### `dirname()`
**Does:** Extracts the directory portion of a path, discarding the
filename.
**Syntax:** `dirname(path)`
**Example:** `dirname("./config/main.tf")` → `"./config"`

### `csvdecode()`
**Does:** Parses CSV text into a list of maps, using the header row
as each map's keys.
**Syntax:** `csvdecode(csv_string)`
**Example:**
```hcl
locals {
  users = csvdecode(file("${path.module}/users.csv"))
}
```
**Gotcha:** Requires the raw text content, not a path — always pair
with `file()`: `csvdecode(file("./users.csv"))`, not
`csvdecode("./users.csv")`.

### `jsondecode()`
**Does:** Parses a JSON string into a Terraform object/map accessible
with dot notation.
**Syntax:** `jsondecode(json_string)`
**Example:** `jsondecode(file("./config.json")).app_name`

### `sensitive()` / `nonsensitive()`
**Does:** `sensitive()` marks a value as sensitive so it's hidden in
plan/apply terminal output. `nonsensitive()` temporarily reveals a
sensitive value so it can be used in operations that don't accept
sensitive input directly (like `jsondecode()`).
**Syntax:** `sensitive(value)` / `nonsensitive(value)`
**Gotcha — important correction:** Marking a value `sensitive` hides
it from terminal/log output; it does **not** encrypt it in the state
file. The state file still contains the plain value. Securing the
state file itself (remote backend, access controls, encryption at
rest) is a separate and necessary step — `sensitive()` is not a
substitute for that.

---

## 8. Date & Time Functions

### `timestamp()`
**Does:** Returns the current UTC date/time as an ISO 8601 string.
**Syntax:** `timestamp()`
**Gotcha:** Evaluated at **apply** time, not plan time. Any output
depending on it will show `(known after apply)` during `terraform
plan` — this is expected, not an error.

### `formatdate()`
**Does:** Formats a timestamp string into a specified layout.
**Syntax:** `formatdate(format_string, timestamp_string)`
**Format codes:** `YYYY`/`YY` (year), `MM`/`MMM` (month), `DD` (day),
`hh` (hour), `mm` (minutes), `ss` (seconds).
**Example:** `formatdate("DD-MM-YYYY", timestamp())` → `"15-01-2024"`
**Gotcha:** Same apply-time-only caveat as `timestamp()` — expect
`(known after apply)` in plan output.

---

## 9. Testing Functions with `terraform console`

Before writing a function into a `.tf` file, test it interactively.

```powershell
Set-Location "C:\projects\your-project"
terraform console
```

```
> max(2, 4, 1)
4

> split(",", "80,443,3306")
tolist([
  "80",
  "443",
  "3306",
])

> exit
```

This catches argument-order mistakes (like `split()`) before they end
up in a real configuration and cost you a `plan`/`apply` debugging cycle.

---

## 10. Complete Function Index (Alphabetical)

```
abs()          Numeric
ceil()         Numeric
chomp()        String
concat()       Collection
contains()     Collection
csvdecode()    File/Encoding
dirname()      File
distinct()     Collection
element()      Collection
endswith()     String        (Terraform 1.5+)
file()         File
filebase64()   File
fileexists()   File
flatten()      Collection
floor()        Numeric
format()       String
formatdate()   Date/Time
join()         String
jsondecode()   File/Encoding
keys()         Collection
length()       Numeric/Collection
lookup()       Collection
lower()        String
max()          Numeric
merge()        Collection
min()          Numeric
nonsensitive() Sensitivity
replace()      String
sensitive()    Sensitivity
split()        String
startswith()   String        (Terraform 1.5+)
strcontains()  String
substr()       String
timestamp()    Date/Time
tobool()       Type Conversion
tolist()       Type Conversion
tomap()        Type Conversion
tonumber()     Type Conversion
tostring()     Type Conversion
toset()        Type Conversion/Collection
trim()         String
trimprefix()   String
trimsuffix()   String
upper()        String
values()       Collection
```

---

## 11. Functions Organized by Problem Solved

**Building a valid Azure resource name:**
`lower()`, `replace()`, `substr()`, `format()`

**Validating a variable before creating anything:**
`contains()`, `strcontains()`, `length()`, `startswith()`,
`endswith()`, `fileexists()`

**Combining data from multiple sources:**
`merge()` (maps), `concat()` (lists), `toset()` (dedupe)

**Reading external data into Terraform:**
`file()`, `filebase64()`, `csvdecode()`, `jsondecode()`

**Reshaping data so `for_each` will accept it:**
`toset()`, `tomap()`, or a `for` expression:
`{ for item in var.list : item.key_field => item }`

**Protecting sensitive values:**
`sensitive()`, `nonsensitive()` — remembering this hides output, it
does not encrypt state

**Working with dates for tagging/naming:**
`timestamp()`, `formatdate()` — both apply-time only

---

## 12. Master Cheat Sheet

```
NUMERIC
  max(a,b,c...) / max(list...)   highest value (needs ... for a list)
  min(a,b,c...) / min(list...)   lowest value
  abs(n)   ceil(n)   floor(n)
  length(string_or_collection)

STRING
  lower(s)  upper(s)
  replace(s, old, new)          replaces ANYWHERE in the string
  trim(s, chars)                 removes from START/END ONLY
  trimprefix(s, pre) / trimsuffix(s, suf)
  substr(s, offset, len)         zero-based offset
  split(sep, s)                  SEPARATOR FIRST
  join(sep, list)
  format("%s-%s", a, b)          %s=string, %d=number
  strcontains(s, sub)             string contains? (not for collections)
  startswith(s, pre) / endswith(s, suf)

COLLECTION
  merge(m1, m2, ...)             later map wins on key conflict
  concat(l1, l2, ...)            no dedup
  contains(list, val)             collection membership (not strings)
  distinct(list)   flatten(nested)
  keys(map)   values(map)
  lookup(map, key, default)       ALWAYS provide the default
  element(list, index)

TYPE CONVERSION
  tostring()  tonumber()  tobool()  tolist()  toset()  tomap()
  toset() is required prep for for_each on list-typed variables

FILE / ENCODING
  file(path)             raw text
  filebase64(path)        base64 (Azure custom_data requires this)
  fileexists(path)
  dirname(path)
  csvdecode(csv_text)      pair with file()
  jsondecode(json_text)
  sensitive(v) / nonsensitive(v)   hides OUTPUT, does NOT encrypt state

DATE & TIME
  timestamp()                     apply-time only
  formatdate(fmt, timestamp)       apply-time only

TOP GOTCHAS
  1. split(separator, string) — separator first, always
  2. trim() only touches start/end — use replace() for the middle
  3. contains() needs a collection — strcontains() is for strings
  4. for_each needs map/set — wrap list variables with toset()
  5. max()/min() need ... to expand a list argument
  6. sensitive() hides output; it does not encrypt the state file
  7. timestamp()/formatdate() show "known after apply" in plan output —
     that's expected, not a bug
```

---

*This reference compiles the Terraform built-in functions referenced
across Days 1-17 of the 28 Days of Azure Terraform series, based on
the guides built for that series and the mistakes demonstrated in the
underlying video transcripts. Function availability (particularly
`strcontains`, `startswith`, `endswith`) depends on your Terraform
version — check the official Terraform functions documentation for
your specific version before relying on any of these in production.*
