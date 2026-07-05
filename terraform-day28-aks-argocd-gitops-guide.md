# Terraform Capstone — AKS with GitOps via Argo CD
## Deep-Dive Learning Guide — Day 28 (Final) / 28 Days of Easy Terraform
### Capstone Project | Beginner-First Edition | PowerShell Throughout

---

## Before You Start

This is Day 28, the final project in the series: Terraform provisions
an AKS cluster and its supporting infrastructure, then bootstraps
Argo CD onto that cluster to take over from there — every subsequent
application change flows through a separate Git repository (GitOps),
not through further `terraform apply` runs.

A few things in the source video are worth correcting precisely before
you build this yourself, because getting them wrong wastes real
troubleshooting time (exactly what happened live in the recording):
two Azure RBAC roles are named imprecisely and one is actually
unrelated to the problem it's credited with solving, and a
Kubernetes-native tool is referred to throughout by a name that isn't
its actual name, which would make it hard to find documentation for.
I'll flag each clearly rather than repeating the imprecision.

---

## Table of Contents

1. What GitOps Actually Means
2. The Full Architecture, Layer by Layer
3. Why Managed Identity Here Is the Right Call
4. Prerequisites and Service Principal Setup
5. A Correction: "Network Contributor," Not "Network Admin"
6. A Necessary Correction: What Managed Identity Operator Actually Does
7. The Environment Folder Structure
8. The Argo CD Application Manifest — Correct Field Names
9. Kustomize, Not "Customization"
10. Bootstrapping Argo CD with `null_resource` and `local-exec`
11. Setting Up the Remote Backend
12. Running the Deployment
13. Retrieving the Argo CD Admin Password Cleanly
14. A Security Note on Exposing Argo CD Publicly
15. External Secrets Operator and the Key Vault Secret Flow
16. Ingress Resource vs Ingress Controller
17. Local Domain Testing on Windows
18. Demonstrating Drift Detection
19. Rolling Out a New Version via GitOps
20. Common Mistakes
21. Practice Exercises
22. Summary Reference

---

## 1. What GitOps Actually Means

Two concepts to hold onto, exactly as the video frames them:

**Single source of truth** — the desired state of your application
(which container image, how many replicas, what configuration) lives
entirely in a Git repository, not in whatever happens to currently be
running on the cluster. The cluster is expected to *match* that
repository, not the other way around.

**Drift detection (and self-healing)** — a controller (Argo CD, in
this project) continuously compares what's actually running against
what the Git repository declares. If someone manually changes
something directly on the cluster — edits a deployment, changes a
replica count — that's "drift." Argo CD detects the mismatch and
reverts it back to match Git, rather than accepting the manual change
as the new truth. Section 18 shows exactly this happening.

The practical consequence: to change anything about the deployed
application, you commit a change to the Git repository. You do not
`kubectl edit` anything directly and expect it to stick.

---

## 2. The Full Architecture, Layer by Layer

**Infrastructure layer (provisioned by Terraform):** a Resource Group,
a Virtual Network, an AKS cluster (backed by a VMSS node pool), RBAC
role assignments, a Key Vault, and randomly generated database
credentials stored as Key Vault secrets.

**GitOps bootstrap layer (also driven by Terraform, via
`local-exec`):** Argo CD installed onto the cluster via Helm, plus the
External Secrets Operator, plus a `SecretStore` resource authorizing
that operator to read from the Key Vault.

**Application layer (managed by Argo CD from a *separate* Git
repository, not the Terraform repository):** a frontend (Node.js), a
backend, and a Postgres database, each as Kubernetes Deployments,
exposed internally via Services and externally via one Ingress
resource pointed at the frontend.

**Credential flow:** the AKS cluster's own Managed Identity
authenticates to Key Vault; the External Secrets Operator uses that
authenticated access to pull the database credentials out of Key
Vault and materialize them as native Kubernetes Secrets inside the
cluster — meaning the actual credential values never need to be
typed into any YAML file committed to Git.

---

## 3. Why Managed Identity Here Is the Right Call

Worth flagging positively rather than only correcting things: this
project's use of **Managed Identity** for the AKS cluster's
authentication to Key Vault is exactly the pattern **Day 20** and
**Day 22** each recommended as the *stronger* alternative to a
Service Principal with a stored, manually-rotated client secret. There
is no long-lived secret sitting in a workspace variable or a
Terraform state file for this specific credential path — Azure issues
and manages the identity's token lifecycle automatically. This project
gets that particular design decision right; the Service Principal used
elsewhere in this project is for the *Terraform deployment pipeline's own*
authentication (a different, legitimate use case — Day 3's original
reasoning still applies there), not for the cluster's runtime access to secrets.

---

## 4. Prerequisites and Service Principal Setup

```powershell
az login

$sub = az account show --query "id" -o tsv

$sp = az ad sp create-for-rbac `
  --name "terraform-aks-gitops-sp" `
  --role "Contributor" `
  --scopes "/subscriptions/$sub" | ConvertFrom-Json

$env:ARM_CLIENT_ID       = $sp.appId
$env:ARM_CLIENT_SECRET   = $sp.password
$env:ARM_TENANT_ID       = $sp.tenant
$env:ARM_SUBSCRIPTION_ID = $sub
```

**A note the video runs into directly:** Azure AD application
secrets have an expiration date (commonly defaulting to one or two
years, depending on how they're created). The video's mid-project
`invalid client secret` error traces back to exactly this — an older
Service Principal's secret had quietly expired. Worth checking this
proactively rather than discovering it via failure:

```powershell
az ad app credential list --id $sp.appId --query "[].endDateTime" -o table
```

If a secret is expired or close to it, generate a replacement rather
than waiting for it to fail:

```powershell
az ad app credential reset --id $sp.appId --append
```

---

## 5. A Correction: "Network Contributor," Not "Network Admin"

The video's own narration hedges between "network admin role" and
"network contributor role," uncertain which is correct. Worth
resolving this precisely: **there is no built-in Azure role called
"Network Admin."** The correct built-in role name is **Network
Contributor**, and it's the one this project actually needs (alongside
Contributor) for the Terraform-driving Service Principal to manage the
Virtual Network and subnet resources this project creates.

```powershell
$spObjectId = az ad sp show --id $sp.appId --query "id" -o tsv

az role assignment create `
  --assignee $spObjectId `
  --role "Network Contributor" `
  --scope "/subscriptions/$sub"
```

Scoping this to a specific resource group rather than the whole
subscription is preferable once you know which resource group this
project will use, consistent with the least-privilege guidance
established in Day 20 and reinforced in Day 26 and Day 27.

---

## 6. A Necessary Correction: What Managed Identity Operator Actually Does

This is the most consequential correction in this guide, because the
video credits this role with solving a problem it doesn't actually
address. The video assigns the **Managed Identity Operator** role and
describes it as being needed "to fetch the secrets from key vault and
to manage it." That description is inaccurate, and it's worth being
precise about what this role genuinely does, because conflating it
with a different capability could leave you thinking a real gap is
closed when it isn't.

**What Managed Identity Operator actually grants:** the ability for a
principal to *assign* a user-assigned managed identity to another
Azure resource (for example, associating a managed identity with a VM
or a Kubernetes workload). It is about the *assignment relationship*
between an identity and a resource, not about what that identity can
subsequently *do* once assigned.

**What actually grants the ability to read Key Vault secrets** is
entirely separate: either a Key Vault **access policy** (the older
model, granting explicit `Get`/`List` permissions on secrets to a
specific identity) or, on a Key Vault configured for RBAC-based
authorization instead, the built-in **Key Vault Secrets User** role.
This project's `main.tf` (as described in the video) does configure a
Key Vault access policy for the cluster's managed identity separately
from the Managed Identity Operator role assignment — so the actual
secret-reading permission *is* present in this project, just not
because of the role the video credits it to. If you're building a
similar project and something can create a managed identity
association but still can't read a Key Vault secret through it,
Managed Identity Operator is not the role to add — check the Key
Vault's access policy or RBAC role assignment instead.

```powershell
# Correct way to grant secret-read access via access policy (classic model)
az keyvault set-policy `
  --name "<key-vault-name>" `
  --object-id "<managed-identity-principal-id>" `
  --secret-permissions get list

# Or, on an RBAC-authorization-mode Key Vault, the equivalent role assignment
az role assignment create `
  --assignee "<managed-identity-principal-id>" `
  --role "Key Vault Secrets User" `
  --scope "/subscriptions/$sub/resourceGroups/<rg>/providers/Microsoft.KeyVault/vaults/<vault-name>"
```

---

## 7. The Environment Folder Structure

```
day28/
  dev/
    main.tf
    variables.tf
    outputs.tf
    provider.tf
    backend.tf
    terraform.tfvars       (local only — never committed)
    scripts/
      deploy-argocd-app.sh
      install-external-secrets.sh
      cleanup.sh
    manifest/
      argocd-application.yaml
  test/
    (identical structure)
  prod/
    (identical structure)
```

The video explicitly names this as one of several valid approaches —
duplicated folders with per-environment `backend.tf` and
`terraform.tfvars`, rather than a single shared root module calling
environment-parameterized child modules (the pattern Day 20 and Day 26
used instead). Both are legitimate; the duplicated-folder approach
trades some repetition for very explicit, easy-to-audit isolation
between environments — a defensible tradeoff, not a mistake, though
it does mean a structural change (adding a new resource type, say)
has to be manually repeated across `dev/`, `test/`, and `prod/` rather
than changed once in a shared module.

---

## 8. The Argo CD Application Manifest — Correct Field Names

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: three-tier-web-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/<your-username>/gitops-configs.git
    targetRevision: main
    path: three-tier-configs
  destination:
    server: https://kubernetes.default.svc
    namespace: three-tier-web-app-dev
  syncPolicy:
    automated:
      selfHeal: true
      prune: true
    syncOptions:
      - CreateNamespace=true
```

Field-by-field, since the video describes these correctly in concept
but loosely in exact naming: `spec.source.repoURL` and `path` together
tell Argo CD which Git repository and which subfolder within it to
treat as this application's desired state — note this is a
**separate** repository from the Terraform infrastructure code, by
design, since infrastructure provisioning and application deployment
are deliberately decoupled concerns in this architecture.
`syncPolicy.automated.selfHeal: true` is specifically the setting
responsible for the drift-reversal behavior demonstrated in Section
18 — without it, Argo CD would still *detect* drift and show the
application as "OutOfSync," but wouldn't automatically correct it.
`syncOptions: [CreateNamespace=true]` avoids needing to pre-create the
target namespace separately.

---

## 9. Kustomize, Not "Customization"

Worth a direct, standalone correction: the tool referenced throughout
the video as "customization" is actually **Kustomize** — a real,
specifically-named Kubernetes-native configuration management tool,
built into `kubectl` itself since Kubernetes 1.14 (`kubectl apply -k`).
This naming matters practically — searching for "customization tool
for Kubernetes" won't surface Kustomize's actual documentation, while
searching for "Kustomize" will.

Kustomize's actual purpose, described accurately in concept by the
video: rather than editing a value (an image tag, a namespace, a
common label) separately inside every individual YAML manifest, you
declare it once in a `kustomization.yaml` file, and Kustomize applies
that value consistently across every manifest it references when
generating the final output:

```yaml
# kustomization.yaml
namespace: three-tier-web-app-dev
commonLabels:
  environment: dev
images:
  - name: frontend
    newTag: v1
resources:
  - namespace.yaml
  - frontend/deployment.yaml
  - frontend/service.yaml
  - backend/deployment.yaml
  - backend/service.yaml
```

Changing `newTag: v1` to `newTag: v2` in this one file — exactly the
version bump demonstrated in Section 19 — updates the effective image
reference everywhere Kustomize generates output for, without touching
the individual `deployment.yaml` files directly.

---

## 10. Bootstrapping Argo CD with `null_resource` and `local-exec`

This directly reuses **Day 19**'s pattern — a `null_resource` running
a `local-exec` provisioner, used here specifically because installing
Argo CD via Helm and applying the initial application manifest aren't
things a native Terraform Azure resource type can do on their own:

```hcl
resource "null_resource" "deploy_argocd_app" {
  triggers = {
    cluster_id = azurerm_kubernetes_cluster.aks.id
  }

  provisioner "local-exec" {
    command = "bash ${path.module}/scripts/deploy-argocd-app.sh"
  }

  depends_on = [
    helm_release.argocd,
    azurerm_kubernetes_cluster.aks
  ]
}
```

Connecting directly to **Day 19**'s central caution: this is exactly
the kind of scenario where a provisioner is genuinely the right tool
rather than a last resort worth avoiding — there is no `azurerm_*` or
`kubernetes_*` Terraform resource type that installs an arbitrary Helm
chart and then waits for a custom health check the way this project's
script does; a `local-exec` calling a purpose-built script is a
reasonable, deliberate choice here, not something to feel guilty about
reaching for.

**PowerShell note:** the `deploy-argocd-app.sh` script itself is Bash,
executed via the `local-exec` provisioner's default shell. If you're
running Terraform from a Windows machine and want the equivalent
logic in PowerShell instead, the `local-exec` block would need an
explicit `interpreter` argument (covered in Day 19's guide), and the
script itself would need translating from Bash conditionals and
`kubectl`/`helm` invocations into PowerShell syntax — the underlying
`kubectl` and `helm` commands themselves are identical either way,
since those tools don't care which shell invokes them.

---

## 11. Setting Up the Remote Backend

```powershell
$suffix = -join ((97..122) | Get-Random -Count 6 | ForEach-Object {[char]$_})

az group create --name "rg-terraform-state" --location "eastus"

az storage account create `
  --name "tfstate$suffix" `
  --resource-group "rg-terraform-state" `
  --location "eastus" `
  --sku Standard_LRS

az storage container create `
  --name "tfstate" `
  --account-name "tfstate$suffix" `
  --auth-mode login

Write-Host "Update backend.tf with storage account: tfstate$suffix"
```

```hcl
# backend.tf
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "tfstateXXXXXX"   # match the generated name exactly
    container_name        = "tfstate"
    key                    = "dev.terraform.tfstate"
  }
}
```

Exactly the naming-consistency discipline **Day 26** flagged directly
— the resource group name, storage account name, and key must agree
across the script's output and the committed `backend.tf`, or you'll
hit the same class of "resource not found" error that project's
`stage`/`staging` mismatch caused.

---

## 12. Running the Deployment

```powershell
Set-Location "C:\projects\day28\dev"

terraform init
terraform validate
terraform plan
terraform apply --auto-approve
```

Expect roughly 15-20 resources and a genuinely long apply time (AKS
cluster provisioning alone commonly takes several minutes, and the
`local-exec` Argo CD bootstrap step waits for the cluster to be fully
ready before proceeding).

```powershell
az aks get-credentials --resource-group "<rg-name>" --name "<aks-cluster-name>"

kubectl get nodes
kubectl get namespaces
```

**PowerShell alias for `kubectl` (optional convenience, equivalent to
the video's Bash `alias k=kubectl`):**
```powershell
Set-Alias -Name k -Value kubectl
k get pods -n argocd
```

---

## 13. Retrieving the Argo CD Admin Password Cleanly

The video's live attempt to decode the admin password from a full
`kubectl get secret -o yaml` output accidentally included a stray
trailing character, which then caused a login failure until manually
trimmed. The cleaner, more precise approach — extracting *only* the
password field via JSONPath before decoding, rather than decoding an
entire YAML block by hand — avoids that exact class of copy-paste error:

```powershell
kubectl -n argocd get secret argocd-initial-admin-secret `
  -o jsonpath="{.data.password}" | `
  ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
```

This prints exactly the decoded password with no surrounding YAML
formatting, no trailing newline artifacts, and nothing extra to
accidentally include when copying it.

```powershell
kubectl get service argocd-server -n argocd
```

The default Argo CD username is **`admin`**; the password is the
value just decoded above.

---

## 14. A Security Note on Exposing Argo CD Publicly

Worth stating directly rather than leaving as a passing "you could
also keep it internal" aside: this project exposes the Argo CD server
itself on a public-facing external Load Balancer IP, reachable by
anyone on the internet, still using the **default `admin` account**.
For a learning demo this is a reasonable, low-stakes choice — but it's
worth being explicit that for anything beyond a demo, the
production-appropriate posture is different on two specific points:

- **Network exposure** — Argo CD's UI and API generally shouldn't be
  reachable from the public internet at all; an internal-only Load
  Balancer, a VPN, or a Bastion-style access pattern (Day 15) is the
  standard approach
- **Authentication** — the built-in `admin` account with a
  generated password is meant for initial bootstrap only; production
  setups integrate Argo CD with SSO (Entra ID, in an Azure context)
  and disable the local `admin` account entirely once SSO is confirmed working

Neither of these is implemented in this demo, and that's a reasonable
scope decision for a learning project — but it's worth knowing the gap
exists rather than assuming the demo's configuration is
production-ready as-is.

---

## 15. External Secrets Operator and the Key Vault Secret Flow

The video correctly identifies the core reasoning: native Kubernetes
Secrets are **base64-encoded, not encrypted** — anyone with read
access to the Secret object (or etcd, depending on your cluster's
encryption-at-rest configuration) can trivially decode the value.
That's not a secure place to be the *origin* of a credential, even
though Kubernetes Secrets remain a legitimate way for a *running pod*
to consume one.

The External Secrets Operator's role: it watches for a
`SecretProviderClass`/`ExternalSecret` resource declaring "fetch this
value from Key Vault," authenticates to Key Vault using the cluster's
Managed Identity (Section 3), retrieves the actual secret value, and
materializes it as a native Kubernetes Secret inside the cluster at
runtime — meaning the credential's actual value is never typed into
any file committed to either the Terraform repository or the GitOps
application repository. Both repositories only ever contain a
*reference* ("fetch the secret named `db-password` from this Key
Vault"), never the value itself.

---

## 16. Ingress Resource vs Ingress Controller

The video hits real confusion here worth resolving precisely, because
it's one of the most common points of confusion for anyone new to
Kubernetes networking: an **Ingress resource** (the YAML you write,
declaring routing rules like "requests to `app.local` should go to the
frontend Service") does **nothing on its own**. It's a declaration of
intent with no built-in engine to act on it. An **Ingress Controller**
(a separate, actually-running piece of software inside the cluster —
commonly NGINX Ingress Controller, or Azure's own Application Gateway
Ingress Controller) is what actually reads Ingress resources and
configures a real load balancer or proxy to implement the routing
they describe.

This project's Ingress resource, committed to the GitOps repository,
was genuinely correct from the moment it was added — the reason it
didn't work yet was that no Ingress *Controller* had been installed
onto the cluster at all, which is exactly what the video discovers and
fixes:

```powershell
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx `
  --namespace ingress-nginx `
  --create-namespace
```

Worth noting as a natural extension, consistent with the video's own
suggestion: this installation step could itself be folded into the
Terraform `local-exec` bootstrap (Section 10), alongside the Argo CD
and External Secrets Operator installation, so a fresh cluster is
fully ready for Ingress resources immediately after `terraform apply`
completes, rather than requiring this manual follow-up step every time.

---

## 17. Local Domain Testing on Windows

The video edits `/etc/hosts` (macOS/Linux) to map a local hostname to
the Ingress controller's external IP, for testing without owning a
real DNS domain. The equivalent file on Windows, and the PowerShell
approach to editing it:

```powershell
# Must run PowerShell as Administrator for this file
$hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"

$ingressIp = kubectl get service -n ingress-nginx ingress-nginx-controller `
  -o jsonpath="{.status.loadBalancer.ingress[0].ip}"

Add-Content -Path $hostsPath -Value "$ingressIp  app.local"

Get-Content $hostsPath | Select-String "app.local"
```

If you need to remove or update a stale entry (exactly the duplicate-entry
problem the video runs into):

```powershell
$content = Get-Content $hostsPath | Where-Object { $_ -notmatch "app.local" }
Set-Content -Path $hostsPath -Value $content
Add-Content -Path $hostsPath -Value "$ingressIp  app.local"
```

---

## 18. Demonstrating Drift Detection

The video's manual `kubectl edit deployment` attempt — trying to
change the frontend image tag directly on the cluster, bypassing
Git entirely — is a genuinely well-designed demonstration, worth
walking through precisely because it's the clearest possible proof
that GitOps self-healing works as intended: the manual edit briefly
took effect (a new pod started terminating/creating), but Argo CD's
continuous reconciliation loop detected the mismatch against the
Git-declared desired state and **reverted it automatically**, without
any human re-applying the original manifest. The deployment settled
back to exactly what the Git repository declared, not what the manual
`kubectl edit` had requested.

This is `syncPolicy.automated.selfHeal: true` (Section 8) doing
precisely its job — and it's worth internalizing as the core practical
payoff of GitOps: **the cluster cannot silently drift away from Git
for long**, whether the drift was accidental, unauthorized, or simply
someone forgetting to go through the proper change process.

---

## 19. Rolling Out a New Version via GitOps

The complete, correct change process this project demonstrates:

1. Edit `kustomization.yaml` in the GitOps repository, changing
   `newTag: v1` to `newTag: v2`
2. Commit and push that change
3. Argo CD's configured polling interval (a few minutes, by default)
   detects the Git repository has changed
4. Argo CD automatically syncs the new desired state to the cluster —
   no manual `kubectl apply`, no manual sync click required, because
   `syncPolicy.automated` was configured

```powershell
kubectl get application three-tier-web-app -n argocd
```

Reports sync status; watching this transition from "OutOfSync" to
"Synced" after the Git push, without any manual intervention, is the
visible proof the automated pipeline worked end to end.

For faster feedback during development than waiting for the polling
interval, a Git webhook configured to notify Argo CD immediately on
push is the standard production improvement — mentioned by the video
as an option, not implemented in this specific demo.

---

## 20. Common Mistakes

**Mistake 1 — Assuming Managed Identity Operator grants Key Vault
secret access.** Section 6 — it grants identity-assignment
capability, unrelated to secret-reading permission; use an access
policy or Key Vault Secrets User role for that instead.

**Mistake 2 — Searching for "Kubernetes customization tool" instead
of "Kustomize."** Section 9 — the actual tool name matters for finding
documentation and community help.

**Mistake 3 — Assuming an Ingress resource does something on its own
without an Ingress Controller installed.** Section 16 — they're two
genuinely separate things; both are required.

**Mistake 4 — Decoding a full `kubectl get secret -o yaml` output by
hand instead of extracting just the needed field via JSONPath first.**
Section 13 — the manual approach is exactly what introduced the
video's stray-character login failure.

**Mistake 5 — Trying to fix application drift with `kubectl edit`
instead of committing a change to the GitOps repository.** Section 18
— Argo CD's self-heal will simply revert it; the Git repository is the
only place changes should originate from.

**Mistake 6 — Not proactively checking Service Principal secret
expiration.** Section 4 — `az ad app credential list` before you need
it avoids discovering an expired secret via a failed `terraform init`/`apply`.

---

## 21. Practice Exercises

**Exercise 1** — A colleague assigns their AKS cluster's managed
identity the Managed Identity Operator role and is confused that it
still can't read a Key Vault secret. What's actually missing, and
which role or policy fixes it?

*Answer:* Managed Identity Operator only grants permission to assign a
managed identity to a resource — it says nothing about what that
identity can access afterward. The missing piece is a Key Vault
access policy (`Get`/`List` secret permissions) for that identity, or,
on an RBAC-mode Key Vault, the Key Vault Secrets User role.

**Exercise 2** — Explain why an Ingress resource committed to Git,
with no syntax errors, might still result in the application being
completely unreachable.

*Answer:* An Ingress resource only declares routing rules — it
requires a separately-installed Ingress Controller (such as NGINX
Ingress Controller) actually running in the cluster to read that
resource and configure real traffic routing. Without a controller
installed, the Ingress resource has nothing to act on it.

**Exercise 3** — Someone manually runs `kubectl scale deployment
frontend --replicas=5` directly against a cluster managed by Argo CD
with `selfHeal: true` configured. What happens, and why?

*Answer:* Argo CD's continuous reconciliation loop detects the
mismatch between the actual replica count (5) and the Git-declared
desired state (2, per the original manifest), and automatically
reverts it back to 2 — exactly the drift-detection and self-healing
behavior demonstrated in Section 18. To genuinely run 5 replicas, the
change must be committed to the Git repository instead.

---

## 22. Summary Reference

GitOps rests on two ideas: a Git repository as the single source of
truth for desired state, and continuous drift detection (with optional
automatic self-healing) reconciling the cluster back to match it.

This project correctly uses Managed Identity (not a stored Service
Principal secret) for the cluster's own authentication to Key Vault —
the stronger pattern Day 20 and Day 22 each recommended over a
manually-rotated client secret.

Two Azure RBAC role names are worth getting exactly right: **Network
Contributor** (not "Network Admin," which doesn't exist as a built-in
role), and **Managed Identity Operator**, which grants identity
*assignment* capability only — Key Vault secret access requires a
separate access policy or the Key Vault Secrets User role.

The Kubernetes-native configuration tool used throughout this project
is **Kustomize**, not "customization."

An Ingress resource and an Ingress Controller are two separate,
both-required things — a syntactically correct Ingress resource does
nothing at all without a controller installed to act on it.

---

*Guide covers: GitOps fundamentals (single source of truth, drift
detection, self-healing), the full AKS + Argo CD + External Secrets
Operator architecture, why Managed Identity is the correct choice here
versus the Service-Principal-with-stored-secret pattern used elsewhere
in this series (callback to Day 20/22), Service Principal setup and
proactive secret-expiration checking, a precise correction of the
"Network Admin" versus the actual built-in "Network Contributor" role,
a substantive correction distinguishing Managed Identity Operator
(identity assignment) from actual Key Vault secret-read permissions
(access policies or the Key Vault Secrets User role), the
duplicated-environment-folder Terraform structure as a valid
alternative to shared child modules, correct Argo CD Application
manifest field names (syncPolicy.automated.selfHeal, prune,
syncOptions), a naming correction identifying "customization" as
Kustomize, the null_resource/local-exec pattern for bootstrapping
Helm-based cluster add-ons (callback to Day 19), remote backend setup
with the same naming-consistency discipline flagged in Day 26, clean
JSONPath-based secret decoding versus manual YAML decoding, a direct
security note on publicly exposing Argo CD with default admin
credentials, the External Secrets Operator's actual credential flow,
a precise clarification of Ingress resource versus Ingress Controller
as two separate required components, PowerShell-based Windows hosts
file editing for local domain testing, a full walkthrough of the
video's live drift-detection demonstration, and the correct end-to-end
GitOps version-rollout process via Kustomize image tag changes.*
