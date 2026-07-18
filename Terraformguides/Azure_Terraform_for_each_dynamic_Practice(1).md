# Azure Terraform Practice Projects (`for_each` & `dynamic`)

> **Instructions:** Implement the projects using Terraform. Do **not**
> hardcode repeated resources. Use variables, `for_each`, and `dynamic`
> where appropriate.

## Project 1 -- Deploy Multiple Resource Groups (`for_each`)

### Sample Input Data

  Key      Name          Location     Environment
  -------- ------------- ------------ -------------
  app      rg-app-dev    East US      dev
  db       rg-db-dev     East US      dev
  shared   rg-shared     Central US   shared
  prod     rg-app-prod   East US 2    prod

### Requirements

-   Create one variable containing the data above.
-   Deploy all resource groups using `for_each`.
-   Apply tags:
    -   owner = platform-team
    -   cost_center = IT
    -   environment = value from input

------------------------------------------------------------------------

## Project 2 -- Storage Accounts with Dynamic Network Rules

### Sample Input Data

  Name          Tier       Replication   Allowed IPs
  ------------- ---------- ------------- ----------------------
  stapp001      Standard   LRS           10.0.0.10, 10.0.0.20
  stlogs001     Standard   GRS           *(none)*
  stbackup001   Standard   ZRS           172.16.1.15

### Requirements

-   Create all storage accounts using `for_each`.
-   Generate `network_rules` with a `dynamic` block.
-   Skip IP rules when none are supplied.
-   Enable HTTPS traffic only.

------------------------------------------------------------------------

## Project 3 -- Virtual Networks with Dynamic Subnets

### Sample Input Data

**VNet: vnet-dev** - Address Space: 10.10.0.0/16 - Subnets - web →
10.10.1.0/24 → Microsoft.Storage - app → 10.10.2.0/24 →
Microsoft.KeyVault - db → 10.10.3.0/24 → none

**VNet: vnet-prod** - Address Space: 10.20.0.0/16 - Subnets - web →
10.20.1.0/24 → Microsoft.Storage - app → 10.20.2.0/24 → Microsoft.Sql -
management → 10.20.10.0/24 → Microsoft.KeyVault

### Requirements

-   Deploy both VNets using `for_each`.
-   Create subnet blocks with `dynamic`.
-   Service endpoints should be optional.
-   All configuration must come from variables.

## Bonus Challenges

-   Add validation to prevent duplicate names.
-   Make tags reusable through a locals block.
-   Support adding another VNet by editing only the variable data.
