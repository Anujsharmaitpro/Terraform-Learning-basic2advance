# `dynamic` Blocks — The Missing Prerequisite Step
## How to Know WHICH Sub-Block You're Allowed to Make Dynamic
**Addendum to: the for_each/dynamic guide + the dynamic drill sandbox**

---

## The Gap This Fixes

The original guide explained HOW to write a `dynamic` block once
you already know which nested block type you're targeting. It
never explained how you FIND that nested block type in the first
place. This is the actual first step — and skipping it is why
`dynamic` felt like guesswork rather than a repeatable process.

---

## The Rule, Stated Plainly

```
dynamic "block_name" { ... }

"block_name" is NOT something you invent.
It must be the EXACT name of a nested block that the resource's
own schema defines as repeatable.
```

You cannot make ANY argument or block "dynamic" — only specific
nested blocks that the resource type was built to accept multiple
times. Every Azure resource has its own list of which parts are
repeatable and which are not, and that list is defined by the
resource's schema, not by you.

---

## Where to Actually Find This — Terraform Registry

Every resource has a documentation page on the Terraform Registry
that explicitly lists its nested blocks and tells you whether each
one can repeat.

```
URL pattern:
https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/<resource_name>

Example for this exact resource:
https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_action_group
```

**What to look for on the page:**

1. Scroll to the **Arguments Reference** section
2. Nested blocks are usually shown with their own sub-heading
3. The description will say something like *"One or more
   `email_receiver` blocks as defined below"* — the phrase
   **"one or more"** or **"can be specified multiple times"**
   is your signal that `dynamic` is valid here
4. If it instead says *"A `blob_properties` block as defined
   below"* (singular, no "one or more"), that block can only
   appear ONCE — `dynamic` would be pointless there

---

## Worked Example — Your Exact Resource

**Resource:** `azurerm_monitor_action_group`

Checking its Registry page, the nested blocks are:

| Block Name | Repeatable? | `dynamic` Valid? |
|---|---|---|
| `email_receiver` | Yes — "one or more" | ✅ Yes |
| `sms_receiver` | Yes — "one or more" | ✅ Yes |
| `webhook_receiver` | Yes — "one or more" | ✅ Yes |
| `azure_app_push_receiver` | Yes — "one or more" | ✅ Yes |
| `arm_role_receiver` | Yes — "one or more" | ✅ Yes |

This is WHY your example worked correctly:

```hcl
resource "azurerm_monitor_action_group" "nci_action_gp" {
  # ... top-level arguments: name, location, short_name ...
  # these are single VALUES, not blocks — dynamic doesn't apply to them

  dynamic "email_receiver" {          # ← matches the schema exactly
    for_each = local.alert_email_receivers
    content {
      name          = email_receiver.key
      email_address = email_receiver.value
    }
  }
}
```

You correctly identified `email_receiver` as the target because
it's the part of this resource that's DESIGNED to repeat — the
action group can genuinely have 1, 5, or 20 email receivers.
`short_name`, by contrast, is a single string — there's exactly
one short name per action group, so `dynamic "short_name"` would
make no sense and Terraform would reject it.

---

## More Worked Examples — Building the Pattern Recognition

### `azurerm_network_security_group`

| Block Name | Repeatable? | `dynamic` Valid? |
|---|---|---|
| `security_rule` | Yes — "one or more" | ✅ Yes |

```hcl
resource "azurerm_network_security_group" "nsg" {
  name                = "..."
  location             = "..."
  resource_group_name  = "..."
  # security_rule is the only nested block this resource has

  dynamic "security_rule" {
    for_each = var.firewall_rules
    content {
      name                    = security_rule.key
      priority                = security_rule.value.priority
      # ...
    }
  }
}
```

### `azurerm_application_gateway`

This resource has SEVERAL repeatable blocks — you could
theoretically use `dynamic` on more than one within the same
resource:

| Block Name | Repeatable? | `dynamic` Valid? |
|---|---|---|
| `frontend_port` | Yes | ✅ Yes |
| `backend_address_pool` | Yes | ✅ Yes |
| `backend_http_settings` | Yes | ✅ Yes |
| `http_listener` | Yes | ✅ Yes |
| `request_routing_rule` | Yes | ✅ Yes |
| `sku` | No — exactly one required | ❌ No |
| `gateway_ip_configuration` | Yes (though usually only one is used) | ✅ Technically yes |

In MRB-009 you wrote each of these as a single static block
because your lab only needed ONE of each. But if Meridian needed
5 different routing rules for 5 different URL paths, you could
convert `request_routing_rule` to a `dynamic` block exactly the
same way you did for `email_receiver`.

### `azurerm_storage_account`

| Block Name | Repeatable? | `dynamic` Valid? |
|---|---|---|
| `blob_properties` | No — exactly one | ❌ No |
| `network_rules` | No — exactly one | ❌ No |

This resource has almost NO repeatable nested blocks — which is
exactly why you never used `dynamic` when building Storage
Accounts across the whole series. There was nothing to repeat.

### `azurerm_linux_virtual_machine`

| Block Name | Repeatable? | `dynamic` Valid? |
|---|---|---|
| `os_disk` | No — exactly one | ❌ No |
| `source_image_reference` | No — exactly one | ❌ No |
| `admin_ssh_key` | Yes — "one or more" (a VM CAN have multiple SSH keys) | ✅ Yes |

This is a good example of a resource where MOST blocks are
single-only, but ONE (`admin_ssh_key`) is genuinely repeatable —
if Meridian wanted to grant 3 different engineers SSH access to
the same VM using 3 different public keys, `dynamic "admin_ssh_key"`
would be the correct tool.

---

## The Actual Workflow — Use This Every Time

```
1. You know you need to repeat SOMETHING inside a resource.

2. Open the Terraform Registry page for that exact resource type.

3. Find the Arguments Reference section.

4. Look for the specific block you want to repeat. Check its
   description for "one or more" or "can be specified multiple
   times."

5. If it's repeatable → dynamic "exact_block_name" { for_each = ... }
   If it's NOT repeatable → you cannot use dynamic here. Either
   the resource only supports one, or you need a different
   resource/approach entirely.

6. Inside content{}, the field names you set must match the
   documented arguments for that specific nested block — check
   the docs page for what belongs inside email_receiver
   specifically (name, email_address, use_common_alert_schema),
   not arguments from some other block.
```

---

## Practice This Right Now — Free, No Azure Needed

Pick any resource from a project you've already built. Before
opening your old `.tf` file, go to its Registry page COLD and try
to answer these three questions from the documentation alone:

```
1. Which nested blocks does this resource have?
2. Which of those are repeatable ("one or more")?
3. Which are single-only?
```

**Good resources to practice this on**, all ones you've already
built:
```
azurerm_key_vault              → access_policy... wait, check if
                                   MRB used RBAC instead — good
                                   example of "this resource CAN
                                   have a repeatable block, but
                                   your architecture choice meant
                                   you didn't use it"
azurerm_monitor_metric_alert   → criteria and action — check if
                                   either is repeatable
azurerm_private_endpoint       → private_service_connection —
                                   repeatable or not?
```

Do this for 3-4 resources you've already built. You'll likely
find some surprises — resources where a block you assumed was
single-only is actually repeatable, or vice versa. That
recalibration IS the skill this addendum is trying to build.

---

*This closes the real gap in the original guide: `dynamic` isn't
just syntax to memorize, it's a two-step process — first
confirming via documentation that the block you want to repeat
is actually repeatable, THEN writing the dynamic block itself.
Skipping step one is why it felt like guesswork before.*
