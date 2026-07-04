# Terraform + Azure DevOps — Multi-Environment AKS CI/CD Pipeline
## Deep-Dive Learning Guide — Day 26 / 28 Days of Easy Terraform
### Capstone Project | Beginner-First Edition | PowerShell Throughout

---

## Before You Start

This is Day 26 — a capstone project combining nearly everything from
the first 25 days into one real-time build: custom Terraform modules
(Day 20) provisioning AKS clusters for two environments, wired into an
Azure DevOps CI/CD pipeline with Git branching, environment-isolated
state files (Day 4), and a separate destroy pipeline.

The source video is unusually valuable precisely because it's
unedited — every error, every permission problem, every YAML
indentation mistake is left in. That's genuinely useful for learning
how real troubleshooting looks. This guide keeps that spirit but adds
something the live recording couldn't: a step back to identify which
fixes were actually correct engineering decisions versus which were
expedient workarounds worth reconsidering. The biggest one, flagged
directly rather than glossed over: granting the pipeline's service
principal the subscription-wide **Owner** role got the demo working,
but it's considerably broader access than the task actually needs —
Section 12 explains the more precise, least-privilege alternative.

---

## Table of Contents

1. What This Project Actually Builds
2. The Branching Strategy — Feature Branch, Explained Correctly
3. Why Two Separate State Files, Not One
4. Prerequisites Setup — PowerShell Version
5. The Terraform Module Structure — Recap
6. Azure Pipelines YAML — The Correct Hierarchy
7. Triggers: Branches and Paths, Correct Syntax
8. The Branch/Success Condition Expression, Correct Syntax
9. Why Every Job Reinstalls Terraform — Ephemeral Agents
10. The Real Permission Problem — What Was Actually Needed
11. Why "Owner" Is Broader Than Necessary
12. A More Precise Fix: Scoped Role Assignment Instead of Owner
13. SSH Public Keys in Git — What's Actually Sensitive
14. The Naming-Consistency Bug — A Root-Cause Lesson
15. The Destroy Pipeline — Parameters and Deliberate No-Trigger
16. A Missing Safety Net Worth Adding
17. Verifying the Clusters
18. Complete Reference Pipeline YAML
19. Common Mistakes
20. Practice Exercises
21. Summary Reference

---

## 1. What This Project Actually Builds

Two independent environments — Dev and Staging — each consisting of a
Resource Group, a Service Principal, a Key Vault (storing that Service
Principal's credentials as secrets), and an AKS cluster, all
provisioned through the custom Terraform modules first built in
**Day 20**. On top of that infrastructure layer, an Azure DevOps
pipeline automatically provisions Dev whenever code merges to the main
branch, then provisions Staging if Dev succeeds — and a second,
manually-triggered pipeline tears either environment down on demand.

Nothing here is a new *Terraform* concept beyond Day 20's modules —
what's genuinely new is wiring Terraform into a real CI/CD system with
branch-based automation, which is exactly the gap between "I can run
`terraform apply` myself" and "my team can safely collaborate on
infrastructure changes."

---

## 2. The Branching Strategy — Feature Branch, Explained Correctly

The video correctly distinguishes a few common strategies:

**Feature branch** — every change gets its own short-lived branch,
spawned from `main`, merged back via a reviewed pull request, then
deleted. This is what the project uses.

**Trunk-based development** — similar in spirit, but branches are
kept extremely short-lived (often hours, not days), suited to teams
deploying many times per day.

**Git Flow / GitHub Flow** — other named conventions with their own
specific branch-naming and merge rules, mentioned but not used here.

The mechanics demonstrated: create `feature/feature101` from `main`,
make changes, open a pull request, get it reviewed and merged, and the
merge event itself is what triggers the pipeline against `main` — not
the earlier commits on the feature branch, which only run the
*validation* stage (Section 8 explains exactly why).

---

## 3. Why Two Separate State Files, Not One

Directly extending **Day 4**'s remote-backend lesson: this project
uses two separate Storage Accounts (one holding Dev's state, one
holding Staging's), each with its own blob container and state file
key. The video's stated reasoning is worth restating plainly because
it's exactly right: keeping environments' state files physically
separate means an accidental mistake, corruption, or unintended change
while working on one environment's state cannot touch the other's.
This is the same blast-radius-reduction logic behind Day 20's
resource-group-scoped role assignment — isolate the failure domain so
one mistake doesn't cascade.

---

## 4. Prerequisites Setup — PowerShell Version

The video's prep script is Bash, running Azure CLI commands locally —
these translate directly to PowerShell since nothing here executes on
a remote VM (unlike Day 23's stress-test scenario):

```powershell
# prerequisites.ps1

$rgName        = "terraform-state-rg"
$devStorageAcct   = "tfdevbackend$(Get-Random -Maximum 9999)"
$stageStorageAcct = "tfstagebackend$(Get-Random -Maximum 9999)"
$location      = "eastus"

az group create --name $rgName --location $location

az storage account create `
  --name $devStorageAcct `
  --resource-group $rgName `
  --location $location `
  --sku Standard_LRS

az storage container create `
  --name "tfstate" `
  --account-name $devStorageAcct `
  --auth-mode login

az storage account create `
  --name $stageStorageAcct `
  --resource-group $rgName `
  --location $location `
  --sku Standard_LRS

az storage container create `
  --name "tfstate" `
  --account-name $stageStorageAcct `
  --auth-mode login

Write-Host "Dev backend storage account:     $devStorageAcct"
Write-Host "Staging backend storage account: $stageStorageAcct"
```

```powershell
.\prerequisites.ps1
```

Note the deliberate naming discipline here — both storage account
names are generated from the same script using the same variable
pattern, rather than typed by hand in two separate places. Section 14
covers exactly what goes wrong when that discipline slips.

---

## 5. The Terraform Module Structure — Recap

This project reuses the exact `service_principal`, `keyvault`, and
`aks` module structure built in **Day 20** — same resource types
(`azuread_application`, `azuread_service_principal`,
`azurerm_key_vault`, `azurerm_kubernetes_cluster`), same module-calling
pattern (`module "service_principal" { source = "../modules/service_principal" ... }`).
If any of that structure is unfamiliar, Day 20's guide covers it in
full detail, including the same Managed-Identity-versus-Service-Principal
tradeoff discussion that applies here too — this project uses the
Service-Principal-with-Key-Vault-stored-secret pattern throughout,
which Day 20 already flagged as functional but not the current
Microsoft-recommended default for new AKS clusters.

---

## 6. Azure Pipelines YAML — The Correct Hierarchy

The video builds this interactively through the web editor's
autocomplete, hitting several indentation errors along the way. Worth
presenting the correct structural hierarchy cleanly, since getting
this nesting right is the entire battle with Azure Pipelines YAML:

```yaml
trigger:
  branches:
    include:
      - main
      - feature/*
  paths:
    include:
      - lessons/day26

stages:
  - stage: Validate
    jobs:
      - job: TFValidate
        pool:
          vmImage: 'ubuntu-latest'
        steps:
          - task: TerraformInstaller@1
            inputs:
              terraformVersion: 'latest'
          - task: TerraformTaskV4@4
            inputs:
              provider: 'azurerm'
              command: 'init'
              workingDirectory: '$(System.DefaultWorkingDirectory)/lessons/day26/dev'
              backendServiceArm: '<service-connection-name>'
              backendAzureRmResourceGroupName: 'terraform-state-rg'
              backendAzureRmStorageAccountName: '<dev-storage-account>'
              backendAzureRmContainerName: 'tfstate'
              backendAzureRmKey: 'dev.terraform.tfstate'
          - task: TerraformTaskV4@4
            inputs:
              provider: 'azurerm'
              command: 'validate'
              workingDirectory: '$(System.DefaultWorkingDirectory)/lessons/day26/dev'
```

The critical nesting rule, stated explicitly because it's exactly
where the video's manual edits repeatedly broke: **`stages` contains a
list of `stage`s → each `stage` contains a list of `jobs` → each `job`
has one `pool` and a list of `steps` → each `steps` entry is one
`task`.** Every level down adds exactly one indentation increment
(commonly two spaces in YAML), and `pool` and `steps` must sit at the
*same* indentation level, both direct children of their `job` — not
`steps` nested inside `pool`, which was one of the specific errors
the video hit.

---

## 7. Triggers: Branches and Paths, Correct Syntax

```yaml
trigger:
  branches:
    include:
      - main
      - feature/*
  paths:
    include:
      - lessons/day26
```

`branches.include` restricts which branch pushes can trigger the
pipeline at all — without `feature/*` included, pushes to feature
branches wouldn't trigger even the validation stage. `paths.include`
further restricts triggering to only pushes that actually touch files
under `lessons/day26` — exactly the guard the video describes wanting,
so an unrelated README edit elsewhere in the repository doesn't
needlessly trigger this pipeline.

---

## 8. The Branch/Success Condition Expression, Correct Syntax

This is the piece that determines whether the *stage* itself runs,
distinct from the trigger (which determines whether the *pipeline*
runs at all):

```yaml
stages:
  - stage: DevDeploy
    condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
    jobs:
      # ...
```

Reading this precisely: `succeeded()` checks the previous stage
completed without failure; `eq(variables['Build.SourceBranch'], 'refs/heads/main')`
checks the pipeline is running against the `main` branch specifically
— note the exact string `refs/heads/main`, not just `main`, since
that's the full ref format Azure Pipelines' built-in variable actually
contains. `and(...)` combines both conditions, requiring *both* to be
true. This is exactly why, in the video, pushing to the feature branch
correctly ran only the Validate stage and skipped DevDeploy/StageDeploy
entirely — the trigger fired (feature branches are included), but this
condition correctly evaluated to false until the merge into `main` happened.

---

## 9. Why Every Job Reinstalls Terraform — Ephemeral Agents

The video's repetition of the Terraform-installer task in every single
job is not redundant busywork — it reflects a genuine architectural
fact worth understanding precisely: **each `job` in Azure Pipelines
runs on a freshly provisioned agent instance** (Microsoft-hosted agents
are ephemeral virtual machines, torn down after the job completes).
Nothing installed in one job's agent — not Terraform, not any tool —
persists into the next job, even within the same pipeline run and even
within the same stage if jobs are split. This is different from
*steps* within the same job, which do share one continuous agent
session. That's precisely why the Terraform installer task has to
repeat per job, but not per step within a job.

---

## 10. The Real Permission Problem — What Was Actually Needed

The video's Service Principal error cascade resolves to two genuinely
separate permission gaps, worth untangling clearly since the live
troubleshooting jumps between them:

**Gap 1 — Creating the App Registration/Service Principal itself.**
Terraform's `azuread_application` and `azuread_service_principal`
resources call the Microsoft Graph API, which requires the *calling*
identity (the pipeline's own service connection Service Principal) to
hold the **`Application.ReadWrite.All`** Graph API application
permission, with **admin consent granted** — exactly what the video
adds via Entra ID → App registrations → API permissions → Microsoft
Graph → Application permissions, then the separate "Grant admin
consent" step. Both parts are required — adding the permission alone,
without granting consent, produces exactly the "insufficient
privileges" error the video hits on the *first* retry after adding
the permission.

**Gap 2 — Assigning Azure RBAC roles to the newly created Service
Principal.** Once Terraform successfully creates the "inner" Service
Principal (the one meant to manage the AKS cluster itself), the
`azurerm_role_assignment` resource needs to grant it roles
(Contributor, Key Vault Administrator). *Assigning* a role is itself a
privileged action — the identity doing the assigning (again, the
pipeline's own service connection Service Principal) needs sufficient
Azure RBAC permission to create role assignments, which is a
different permission model entirely from the Graph API permission in
Gap 1. This is the error that ultimately led to granting Owner.

---

## 11. Why "Owner" Is Broader Than Necessary

Worth stating plainly rather than treating the video's fix as simply
"the solution": the **Owner** role at subscription scope grants
*every* permission Contributor grants, plus the ability to manage
access control itself — assign or revoke *any* role to *any*
principal, on *any* resource, anywhere in the subscription. For a
pipeline whose actual job is "create a Resource Group, an AKS cluster,
a Key Vault, and assign two specific roles to one specific Service
Principal," Owner is dramatically more access than the task requires.

This matters practically, not just as an abstract principle: if this
pipeline's Service Principal credential were ever leaked or misused,
Owner-level access means the blast radius is the entire subscription
— every resource, every other team's infrastructure, and the ability
to grant *itself* (or anything else) even more access. This is exactly
the least-privilege concern Day 20 raised about subscription-wide
Contributor scoping, one severity level worse.

---

## 12. A More Precise Fix: Scoped Role Assignment Instead of Owner

The specific, narrower permission actually needed for Gap 2 is Azure's
built-in **User Access Administrator** role — which grants exactly the
"can assign RBAC roles" capability, without bundling in Owner's full
resource-management authority — and it should be scoped to the
specific Resource Group(s) this pipeline manages, not the whole
subscription:

```powershell
$pipelineSpObjectId = az ad sp show --id "<pipeline-service-principal-app-id>" --query "id" -o tsv

az role assignment create `
  --assignee $pipelineSpObjectId `
  --role "User Access Administrator" `
  --scope "/subscriptions/<sub-id>/resourceGroups/dev-rg"

az role assignment create `
  --assignee $pipelineSpObjectId `
  --role "User Access Administrator" `
  --scope "/subscriptions/<sub-id>/resourceGroups/staging-rg"
```

Combined with the existing Contributor role (also ideally scoped to
just these two resource groups, following Day 20's Section 12
guidance rather than the subscription root), this gives the pipeline
exactly: permission to create/manage resources within Dev and Staging,
and permission to assign roles *within those same resource groups* —
without the ability to touch any other team's infrastructure or grant
itself broader access elsewhere. This is more setup effort than
clicking "Owner," but it's the difference between a scoped, auditable
CI/CD credential and one that's functionally equivalent to a
subscription administrator account.

---

## 13. SSH Public Keys in Git — What's Actually Sensitive

The video hedges that committing the SSH public key to the repository
"is not a good practice," which is worth making more precise rather
than leaving as a vague caution: **a public key is not secret by
design** — it's meant to be shared; that's the entire point of
public-key cryptography. Committing `id_rsa.pub` to a repository does
not expose anything an attacker could use to impersonate you or
decrypt anything, unlike committing the corresponding *private* key,
which would be a genuine, serious credential leak.

The real, more precise concern with committing a hardcoded public key
is **reproducibility and rotation**, not confidentiality: every
environment ends up trusting the exact same fixed key pair, checked
into source control, with no clean way to rotate it without a code
change, and no way to give each environment its own distinct key.
Day 20 already covered the better pattern for exactly this reason —
generating the key pair with Terraform's own `tls_private_key`
resource, so each environment/apply can have its own key without any
file needing to exist on disk (or in the repository) beforehand:

```hcl
resource "tls_private_key" "aks_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Then reference tls_private_key.aks_ssh.public_key_openssh
# instead of file("~/.ssh/id_rsa.pub")
```

---

## 14. The Naming-Consistency Bug — A Root-Cause Lesson

Near the end, the pipeline fails with a "resource not found" error
tracing back to a mismatch between the folder name (`staging`), a
backend storage account name using `stage`, and a pipeline parameter
value also using `stage` — three places that needed to agree, and
didn't, entirely from manual typing under time pressure across a long
session.

This is worth treating as the single most instructive bug in the
entire video, because it's not really a Terraform or Azure DevOps
problem — it's exactly the failure mode Day 5 and Day 6 built entire
lessons around preventing: **hardcoding the same logical value (an
environment name) as a literal string in multiple, disconnected
places** (a folder name, a storage account name, a pipeline
parameter, a backend key) creates as many opportunities for drift as
there are places it's typed. The fix applied in the video — renaming
the folder to match — treats the symptom. The actual structural fix is
ensuring the environment name exists as **one single source of
truth** (a pipeline parameter, as Section 15 shows) that's referenced
everywhere else needs it, rather than independently retyped:

```yaml
parameters:
  - name: environment
    type: string
    default: dev
    values:
      - dev
      - staging
```

```yaml
workingDirectory: '$(System.DefaultWorkingDirectory)/lessons/day26/${{ parameters.environment }}'
backendAzureRmKey: '${{ parameters.environment }}.terraform.tfstate'
```

With the folder name, backend key, and any other reference all
derived from `${{ parameters.environment }}`, a mismatch like the
video's `stage` vs `staging` typo becomes structurally impossible for
that specific class of value — there's exactly one place to get it wrong.

---

## 15. The Destroy Pipeline — Parameters and Deliberate No-Trigger

```yaml
trigger: none

parameters:
  - name: environment
    type: string
    default: dev
    values:
      - dev
      - staging

stages:
  - stage: PlanDestroy
    jobs:
      - job: Init
        pool:
          vmImage: 'ubuntu-latest'
        steps:
          - task: TerraformInstaller@1
            inputs:
              terraformVersion: 'latest'
          - task: TerraformTaskV4@4
            inputs:
              provider: 'azurerm'
              command: 'init'
              workingDirectory: '$(System.DefaultWorkingDirectory)/lessons/day26/${{ parameters.environment }}'
              backendServiceArm: '<service-connection-name>'
              backendAzureRmResourceGroupName: 'terraform-state-rg'
              backendAzureRmStorageAccountName: '<storage-account-for-this-env>'
              backendAzureRmContainerName: 'tfstate'
              backendAzureRmKey: '${{ parameters.environment }}.terraform.tfstate'
          - task: TerraformTaskV4@4
            inputs:
              provider: 'azurerm'
              command: 'plan'
              workingDirectory: '$(System.DefaultWorkingDirectory)/lessons/day26/${{ parameters.environment }}'

  - stage: DestroyEnvironment
    jobs:
      - job: Destroy
        pool:
          vmImage: 'ubuntu-latest'
        steps:
          - task: TerraformInstaller@1
            inputs:
              terraformVersion: 'latest'
          - task: TerraformTaskV4@4
            inputs:
              provider: 'azurerm'
              command: 'destroy'
              workingDirectory: '$(System.DefaultWorkingDirectory)/lessons/day26/${{ parameters.environment }}'
              commandOptions: '-auto-approve'
```

`trigger: none` is a deliberate, correct choice worth confirming
explicitly: a destroy pipeline should never fire automatically from a
code push — someone should always actively choose to run it, with a
specific environment parameter selected at run time, exactly as the
video sets up.

---

## 16. A Missing Safety Net Worth Adding

Worth flagging as a genuine gap in the demonstrated design, not
covered in the source video: this destroy pipeline requires someone to
*remember* to run it manually to avoid ongoing AKS cluster costs for
environments left running overnight or over a weekend. Two reasonable
mitigations, neither implemented here but both straightforward
additions:

**Azure Pipelines scheduled triggers** — a `schedules:` block that
automatically runs the destroy pipeline for the Dev (and possibly
Staging) environment at a fixed time each day, so cost accumulation
doesn't depend on anyone remembering:

```yaml
schedules:
  - cron: "0 20 * * 1-5"
    displayName: "Nightly Dev teardown"
    branches:
      include:
        - main
    always: true
```

**Manual approval gates on the create pipelines**, using Azure
DevOps **Environments** with configured approval checks — so a human
explicitly confirms before Staging (or, in a real production setup,
Prod) actually provisions, rather than the fully automatic
merge-triggers-apply flow this demo uses throughout. The video itself
notes production deployment is "usually not automated" in real
organizations, but doesn't actually implement even a lightweight
approval gate for Staging in this specific demo — worth adding if
you're extending this project toward something closer to a real
team's workflow.

---

## 17. Verifying the Clusters

```powershell
az aks get-credentials --resource-group "dev-rg" --name "dev-aks-cluster"
kubectl get nodes
kubectl get pods --all-namespaces

az aks get-credentials --resource-group "staging-rg" --name "staging-aks-cluster" --overwrite-existing
kubectl get nodes
kubectl get pods --all-namespaces
```

The `--overwrite-existing` flag matters here specifically because,
without it, `az aks get-credentials` for the second cluster would
merge into the same local kubeconfig context list rather than replace
the active context — the video's manual `kubectl` context switch
between Dev and Staging is exactly what this flag automates safely.

---

## 18. Complete Reference Pipeline YAML

A consolidated, correctly-indented version combining Sections 6-8 and
14's naming-consistency fix:

```yaml
trigger:
  branches:
    include:
      - main
      - feature/*
  paths:
    include:
      - lessons/day26

parameters:
  - name: environment
    type: string
    default: dev
    values:
      - dev
      - staging

stages:
  - stage: Validate
    jobs:
      - job: TFValidate
        pool:
          vmImage: 'ubuntu-latest'
        steps:
          - task: TerraformInstaller@1
            inputs:
              terraformVersion: 'latest'
          - task: TerraformTaskV4@4
            inputs:
              provider: 'azurerm'
              command: 'init'
              workingDirectory: '$(System.DefaultWorkingDirectory)/lessons/day26/dev'
              backendServiceArm: '<service-connection-name>'
              backendAzureRmResourceGroupName: 'terraform-state-rg'
              backendAzureRmStorageAccountName: '<dev-storage-account>'
              backendAzureRmContainerName: 'tfstate'
              backendAzureRmKey: 'dev.terraform.tfstate'
          - task: TerraformTaskV4@4
            inputs:
              provider: 'azurerm'
              command: 'validate'
              workingDirectory: '$(System.DefaultWorkingDirectory)/lessons/day26/dev'

  - stage: DevDeploy
    condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
    jobs:
      - job: TerraformApplyDev
        pool:
          vmImage: 'ubuntu-latest'
        steps:
          - task: TerraformInstaller@1
            inputs:
              terraformVersion: 'latest'
          - task: TerraformTaskV4@4
            inputs:
              provider: 'azurerm'
              command: 'init'
              workingDirectory: '$(System.DefaultWorkingDirectory)/lessons/day26/dev'
              backendServiceArm: '<service-connection-name>'
              backendAzureRmResourceGroupName: 'terraform-state-rg'
              backendAzureRmStorageAccountName: '<dev-storage-account>'
              backendAzureRmContainerName: 'tfstate'
              backendAzureRmKey: 'dev.terraform.tfstate'
          - task: TerraformTaskV4@4
            inputs:
              provider: 'azurerm'
              command: 'apply'
              workingDirectory: '$(System.DefaultWorkingDirectory)/lessons/day26/dev'
              commandOptions: '-auto-approve'

  - stage: StagingDeploy
    condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
    jobs:
      - job: TerraformApplyStaging
        pool:
          vmImage: 'ubuntu-latest'
        steps:
          - task: TerraformInstaller@1
            inputs:
              terraformVersion: 'latest'
          - task: TerraformTaskV4@4
            inputs:
              provider: 'azurerm'
              command: 'init'
              workingDirectory: '$(System.DefaultWorkingDirectory)/lessons/day26/staging'
              backendServiceArm: '<service-connection-name>'
              backendAzureRmResourceGroupName: 'terraform-state-rg'
              backendAzureRmStorageAccountName: '<staging-storage-account>'
              backendAzureRmContainerName: 'tfstate'
              backendAzureRmKey: 'staging.terraform.tfstate'
          - task: TerraformTaskV4@4
            inputs:
              provider: 'azurerm'
              command: 'apply'
              workingDirectory: '$(System.DefaultWorkingDirectory)/lessons/day26/staging'
              commandOptions: '-auto-approve'
```

---

## 19. Common Mistakes

**Mistake 1 — Nesting `steps` inside `pool` instead of as a sibling.**
Section 6's hierarchy is the fix: `pool` and `steps` are both direct
children of `job`, at the same indentation level.

**Mistake 2 — Using `main` instead of `refs/heads/main` in a branch
condition.** Azure Pipelines' `Build.SourceBranch` variable contains
the full ref path; an exact-match `eq()` condition needs the full
string, not the short branch name.

**Mistake 3 — Granting Owner when User Access Administrator (scoped)
would suffice.** Section 11-12 — a meaningfully larger blast radius
for a task that doesn't need it.

**Mistake 4 — Retyping an environment name as a literal string in
multiple files/fields instead of deriving everything from one
parameter.** Section 14's root-cause lesson — this is what actually
caused the `stage`/`staging` mismatch late in the video.

**Mistake 5 — Assuming a tool installed in one job persists into the
next job.** Section 9 — each job gets a fresh agent; only steps
*within* the same job share state.

**Mistake 6 — Treating a committed SSH public key as a secrets leak.**
Section 13 — it isn't one; the real concern is rotation and
reproducibility, addressed more cleanly with `tls_private_key`.

---

## 20. Practice Exercises

**Exercise 1** — Explain precisely why granting Owner "worked" in the
video, but why User Access Administrator scoped to the two relevant
resource groups would have been the more correct fix.

*Answer:* The actual failing operation was the pipeline's service
principal attempting to *assign* RBAC roles to the newly created,
Terraform-managed service principal — which requires role-assignment
permission, not just resource-management permission. Owner happens to
include that capability (along with everything else in the
subscription), so it resolved the error. User Access Administrator
grants exactly the role-assignment capability needed, and scoping it
to the two specific resource groups (rather than the subscription
root) limits the pipeline's reach to only the infrastructure it's
actually meant to manage.

**Exercise 2** — A teammate's pipeline fails only on merges to `main`,
but succeeds when manually run against a feature branch with the
`condition` field temporarily removed. What does this suggest about
where to look first?

*Answer:* The `Build.SourceBranch` comparison in the stage's
`condition` field is a likely culprit — check whether it's comparing
against the exact string `refs/heads/main` rather than a shortened or
mistyped variant, since that's the specific expression controlling
whether the stage runs on `main` at all.

**Exercise 3** — Propose one concrete change to this project's design
that would reduce the risk of another `stage`/`staging`-style naming
mismatch recurring in a future edit.

*Answer:* Derive every environment-name-dependent value (folder path,
backend storage account, backend key, resource naming prefixes) from
a single pipeline parameter (as shown in Section 14 and used
throughout Section 15's destroy pipeline), rather than typing the
environment name as an independent literal string in each location —
reducing the number of places the value can drift out of sync to
exactly one.

---

## 21. Summary Reference

This capstone project combines Day 20's custom Terraform modules with
Azure DevOps multi-stage pipelines, branch-based triggering, and
environment-isolated remote state (Day 4) into one working CI/CD system.

Azure Pipelines YAML nests as: `stages` → `stage` → `jobs` → `job` →
`pool` + `steps` (siblings) → `steps` → individual `task` entries —
getting this hierarchy exactly right is the majority of the syntax battle.

Stage-level `condition` fields (branch/success checks) are independent
from the top-level `trigger` block — the trigger determines whether
the pipeline runs at all; the condition determines whether a specific
stage runs once it has.

Each pipeline `job` runs on a freshly provisioned, ephemeral agent —
nothing installed in one job persists into another, which is why
Terraform installation repeats in every job, not out of redundancy.

The permission cascade this project hits resolves into two genuinely
distinct gaps: Microsoft Graph `Application.ReadWrite.All` (with
admin consent) for creating app registrations/service principals, and
Azure RBAC role-assignment permission (User Access Administrator,
ideally resource-group-scoped) for assigning roles to the
Terraform-managed service principal — Owner resolves both by being
maximally broad, but a scoped User Access Administrator role achieves
the same result with meaningfully less standing access.

Committing an SSH *public* key to source control is not a
confidentiality risk (public keys aren't secret) — the real concern
with a hardcoded, checked-in key is reproducibility and rotation,
better addressed with Terraform's `tls_private_key` resource.

A single naming-consistency slip (an environment name typed
differently across a folder path, a storage account name, and a
pipeline parameter) caused the most time-consuming bug in the video —
deriving all environment-dependent values from one parameter, rather
than retyping the name in multiple places, structurally prevents that
category of error.

---

*Guide covers: multi-environment Terraform + Azure DevOps CI/CD
architecture, feature-branch and trunk-based branching strategies,
environment-isolated Terraform remote state (callback to Day 4),
PowerShell-based prerequisite backend provisioning, the Day 20 custom
module structure reused for this project, correct Azure Pipelines YAML
hierarchy (stages/jobs/pool/steps/task), trigger branches and paths
configuration, stage-level condition expressions using succeeded() and
Build.SourceBranch, why Azure Pipelines jobs run on ephemeral,
non-persistent agents, the two distinct permission gaps behind the
video's service-principal errors (Microsoft Graph
Application.ReadWrite.All with admin consent, and Azure RBAC
role-assignment permission), a direct critique of granting
subscription-wide Owner and the more precise User Access
Administrator alternative scoped to specific resource groups, the
accurate distinction between SSH public-key confidentiality (a
non-issue) and reproducibility/rotation (the real concern, addressed
via tls_private_key from Day 20), a root-cause analysis of the
dev/stage/staging naming-consistency bug and the single-source-of-truth
parameter-driven fix, the destroy pipeline's deliberate trigger: none
and parameterized environment selection, proposed scheduled
auto-teardown and manual approval gates as safety nets not present in
the original demo, and kubectl cluster verification including the
--overwrite-existing flag for switching between cluster contexts.*
