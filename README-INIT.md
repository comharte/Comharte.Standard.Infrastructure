# Infrastructure Initialization

One-time setup steps to bootstrap a new organization on Azure. Run in order.

## Prerequisites

- Azure CLI installed and logged in (`az login`)
- Terraform installed
- Sufficient Azure permissions (Owner on the subscription)

---

## Step 1 — Global Admin

Provisions the foundational global infrastructure and assigns DevOps deployment permissions.

**What it creates:**
- Resource group: `{org}-infrastructure-global`
- Storage account: `{org}tfstates` + `terraform-states-global` container
- Managed identity: `{org}-devops-deployments`
- Container Registry: `{org}acr`
- Subscription-level RBAC for the managed identity (Contributor, User Access Administrator, Network Contributor, Key Vault Secrets Officer, Key Vault Certificates Officer, Storage Blob Data Contributor)

**Run:**
```powershell
./devops/scripts/global-admin-deploy.ps1 -OrganizationCode comharte -OrganizationShortCode cht
```

---

## Step 2 — Environment Group Admin

Run once per environment group (e.g. `nonprod`, `prod`).

**What it creates:**
- Resource group: `{org}-infrastructure-global-{env-group}`
- Terraform state container: `terraform-states-{env-group}`

**Run:**
```powershell
./devops/scripts/global-admin-deploy.ps1  # already handles nonprod/prod via pipeline
```

> After this step, register the `{org}-devops-deployments` managed identity as the service connection in Azure DevOps. All subsequent deployments run through pipelines using that identity.

---

## Step 3 — Environment Group

Run via pipeline: `environment-group-deploy` per environment group.

**What it creates:**
- VNet + CAE subnet (delegated to `Microsoft.App/environments`)
- Internal Container Apps Environment
- Log Analytics Workspace
- Key Vault

---

## Step 4 — Global Routing

Run via pipeline: `network-routing-deploy`.

**What it creates:**
- AGW subnet + public IP
- Nginx Container App (routing layer)
- Application Gateway (HTTPS termination, routes to Nginx)

---

## Step 5 — App Deployments

Run per-app pipelines to deploy Container Apps into the environment group CAE. Internal FQDNs are written to Key Vault after each deployment.

---

## Deployment Order Summary

```
global-admin-deploy.ps1
    └── environment-group-deploy (pipeline, per env-group)
            └── app-deploy pipelines
            └── network-routing-deploy (pipeline, per env-group)
                    └── DNS cutover
```
