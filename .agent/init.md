# Infrastructure Initialization — From Scratch

Agent instructions for bootstrapping Comharte infrastructure in a new Azure environment.

---

## Prerequisites

- Azure subscription with **Owner** role (required to assign subscription-level RBAC)
- Azure CLI installed and authenticated:
  ```powershell
  az login
  az account set --subscription <subscription-id>
  ```
- Terraform installed (version matching `devops/deployments/*.yml` — currently `1.14.8`)

---

## Step 1 — Run global-admin-deploy.ps1

This script bootstraps the foundational Azure resources that everything else depends on. It must run locally because the Terraform state backend does not exist yet — there is nowhere to store state until this step creates it.

**What it does:**

1. Creates resource group `infrastructure-global` in Azure
2. Creates storage account `<OrganizationName>tfstates` with blob container `terraform-states-global` — this becomes the Terraform remote state backend for all subsequent modules
3. Runs `terraform/global-admin` which provisions:
   - Managed identity `<OrganizationName>-devops-deployments` — this identity is used by all Azure DevOps pipelines instead of a service principal, avoiding credential rotation
   - Container Registry `<OrganizationName>acr` — shared ACR for all environments
   - Subscription-level RBAC for the managed identity: Contributor, User Access Administrator, Network Contributor, Key Vault Secrets Officer, Key Vault Certificates Officer, Storage Blob Data Contributor

**Download and run the script:**
```powershell
Invoke-WebRequest `
    -Uri "https://dev.azure.com/comharte/Comharte.Standard/_apis/git/repositories/Comharte.Standard.Infrastructure/items?path=/devops/scripts/global-admin-deploy.ps1&api-version=7.1&download=true" `
    -OutFile "global-admin-deploy.ps1"

.\global-admin-deploy.ps1 `
    -OrganizationName <full-org-name> `
    -OrganizationCode <short-org-code>
```

| Parameter | Description | Example |
|---|---|---|
| `OrganizationName` | Full name, used in resource naming | `comharte` |
| `OrganizationCode` | Short code for length-constrained resources (e.g. Key Vault names) | `cht` |
| `Location` | Azure region (default: `westeurope`) | `westeurope` |

**Note the following outputs** — they are needed in the steps below:

```powershell
terraform -chdir="terraform/global-admin" output devops_deployments_client_id
terraform -chdir="terraform/global-admin" output devops_deployments_principal_id
```

---

## Step 2 — Create Azure DevOps Project

Create a project in Azure DevOps (`https://dev.azure.com/<org>`) to centralize all infrastructure and application builds and deployments. All subsequent deployment steps run through pipelines in this project — nothing else is deployed locally after Step 1.

The project name is up to the organization. At this stage it only needs to exist — it will host the service connections and variable groups created in the steps below. Repository import and pipeline setup happen later.

---

## Step 3 — Create Azure Resource Manager Service Connection

**Why:** Azure DevOps pipelines need permission to create and manage Azure resources (resource groups, VNets, Key Vaults, Container Apps, etc.) on behalf of the organization. Rather than storing a client secret, Workload Identity Federation is used — Azure DevOps proves its identity to Azure AD using a short-lived token, with no credentials to rotate or leak.

**How:**

In Azure DevOps → Project Settings → Service Connections → New → **Azure Resource Manager** → **Workload Identity Federation (manual)**:

| Field | Value |
|---|---|
| Subscription ID | `<azure-subscription-id>` |
| Subscription Name | `<azure-subscription-name>` |
| Service Principal ID | `devops_deployments_client_id` from Step 1 |
| Tenant ID | Azure AD tenant ID |
| Name | `azure-resource-manager` |

After saving, Azure DevOps displays an **Issuer** and **Subject identifier**. These must be registered as a federated credential on the managed identity in Azure Portal:

1. Azure Portal → Managed Identities → `<OrganizationName>-devops-deployments` → Federated credentials → Add
2. Federated credential scenario: **Other**
3. Issuer: paste from Azure DevOps
4. Subject identifier: paste from Azure DevOps
5. Name: `azure-devops-pipelines`

Once the federated credential is saved, verify the service connection in Azure DevOps. Grant access to all pipelines.

---

## Step 4 — Create Docker Registry Service Connection

**Why:** Application build pipelines push container images to ACR. A Docker Registry service connection gives pipelines authenticated access to push and pull images without embedding ACR credentials in pipeline variables. It uses the same `devops-deployments` managed identity, so there are no separate credentials to manage.

In Azure DevOps → Project Settings → Service Connections → New → **Docker Registry** → **Others**:

| Field | Value |
|---|---|
| Docker Registry | `https://<OrganizationName>acr.azurecr.io` |
| Docker ID | `devops_deployments_client_id` from Step 1 |
| Authentication type | Service Principal |
| Name | `acr-<OrganizationName>` |

> The `devops-deployments` identity has **AcrPull** and **AcrPush** roles on the registry via the subscription-level Contributor assignment from Step 1.

Grant access to all pipelines.

