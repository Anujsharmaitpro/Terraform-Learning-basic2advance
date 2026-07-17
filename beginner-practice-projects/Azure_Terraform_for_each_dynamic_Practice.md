# Azure Terraform Practice Projects

## Project 1: Multiple Resource Groups (for_each)

**Goal:** Practice `for_each`.

### Requirements

-   Create a variable containing 4 resource groups.
-   Each resource group should have:
    -   Name
    -   Location
    -   Tags
-   Deploy all resource groups using `for_each`.

------------------------------------------------------------------------

## Project 2: Storage Accounts with Dynamic Network Rules

**Goal:** Practice `for_each` + `dynamic`.

### Requirements

-   Create 3 storage accounts using `for_each`.
-   Each storage account has different:
    -   Name
    -   Tier
    -   Replication type
-   Add a `dynamic` block for `network_rules`.
-   Some storage accounts should have multiple allowed IPs, others none.

------------------------------------------------------------------------

## Project 3: Virtual Networks and Subnets

**Goal:** Combine `for_each` and `dynamic`.

### Requirements

-   Create 2 virtual networks using `for_each`.
-   Each VNet has:
    -   Address space
    -   Multiple subnets
-   Generate subnet blocks using a `dynamic` block.
-   Each subnet should have:
    -   Name
    -   Address prefix
    -   Optional service endpoints

**Challenge** - Keep the input entirely variable-driven. - Avoid
duplicate resource blocks.
