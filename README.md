# Comharte Infrastructure Global

Terraform Infrastructure-as-Code for Comharte's multi-environment Azure platform. Provisions global shared infrastructure, per-environment-group resources, networking, and reusable application modules for backend services and frontend web apps.

Licensed under the [Apache License 2.0](LICENSE).

---

## Overview

```
┌─────────────────────────────────────────────────────────┐
│                        global                           │
│         Container Registry, Resource Groups             │
└───────────────────────┬─────────────────────────────────┘
                        │ remote state
          ┌─────────────┴──────────────┐
          │                            │
┌─────────▼──────────┐      ┌─────────▼──────────┐
│  environment-group │      │     networking      │
│  SQL · Service Bus │      │  VNet · App Gateway │
│  Key Vault · CAE   │      │  Public IP · Subnet │
└─────────┬──────────┘      └────────────────────┘
          │ remote state
    ┌─────┴──────┐
    │            │
┌───▼────┐  ┌───▼─────┐
│apps-   │  │apps-web │
│service │  │         │
│        │  │ hosting │
└────────┘  └─────────┘
```

Resources are split into layers:

| Layer | Module | What it provisions |
|---|---|---|
| Global | `global` | Container Registry |
| Environment group | `environment-group` | SQL Server, Service Bus, Container App Environment, Key Vault, Log Analytics |
| Networking | `networking` | VNet, subnet, public IP, Application Gateway |
| App — backend | `apps-service` | Managed identity, AAD app registration, SQL database, Service Bus topics, Key Vault secrets |
| App — frontend | `apps-web` + `apps-web-hosting` | Container App, managed identity, AAD app registration, Key Vault secrets |

All resources are created in the **home tenant**.

---

## Prerequisites

### 1. Terraform State Backend

Run the [`init`](#init) module first to provision the resource group, storage account, and state containers.

### 2. Azure DevOps

- **Service connection** per environment group (e.g. `azure-nonprod`) with Contributor access on the target subscription
- **Variable groups** — see [Variable Groups](#variable-groups) below
- **Environment** `global-infra-<environment_group>` with an approval gate configured for production

---

## Modules

### `init`

Bootstraps a new Azure subscription. Run once before any other module — provisions the remote state backend that all other modules depend on.

| Variable | Description | Default |
|---|---|---|
| `organization_code` | Full org code used in resource naming (e.g. `comharte`) | — |
| `resources_location` | Azure region for all resources | `westeurope` |
| `environment_groups` | Map of environment group names to their constituent environments | `{ nonprod = ["dev", "test"], prod = ["prod"] }` |

**Resources:** resource groups (global + per env group), storage account, state containers, `devops-deployments` managed identity, custom subscription-read role.

**Managed identity permissions:**

| Scope | Role |
|---|---|
| Storage account | Storage Blob Data Contributor |
| Subscription | Custom subscription-read role |
| Per env group resource group | Contributor, Key Vault Secrets Officer, Key Vault Certificates Officer, User Access Administrator, Network Contributor |
| Global infrastructure resource group | Contributor, User Access Administrator, Network Contributor |
| Microsoft Graph | Application.ReadWrite.All |
| AAD Directory | Directory Readers |

**Usage:**

```bash
az login
az account set --subscription <subscription-id>
terraform init
terraform plan -var="organization_code=<org_code>"
terraform apply -var="organization_code=<org_code>"
```

> State is stored locally on first run since the remote backend does not yet exist.

**State:** local only (bootstraps the backend used by all other modules).

---

### `global`

Provisions the Container Registry shared across all environments.

| Variable | Description |
|---|---|
| `organization_code` | Full org code for resource naming (e.g. `comharte`) |
| `organization_short_code` | Short code for length-constrained resources (e.g. `cht`) |
| `resources_location` | Azure region (default: `westeurope`) |

**State key:** `terraform-states-global/global.tfstate`

---

### `environment-group`

Provisions per-environment-group shared infrastructure. Typically deployed once for `nonprod` and once for `prod`.

| Variable | Description |
|---|---|
| `organization_code` | Used to locate global remote state |
| `environment_group` | e.g. `nonprod`, `prod` |
| `is_production` | Controls production-specific behaviour (default: `false`) |

**Resources:** SQL Server (AAD-only auth), Service Bus (Standard), Container App Environment, Log Analytics Workspace (30-day retention), Key Vault (RBAC), self-signed certificate (auto-renewed).

**State key:** `terraform-states-<environment_group>/<environment_group>.tfstate`

---

### `networking`

Provisions the virtual network and Application Gateway. Routing rules are generated dynamically from an `apps` variable that maps public hostnames to backend FQDNs.

| Variable | Description |
|---|---|
| `organization_code` | Used in resource naming and to locate global remote state |
| `apps` | List of app routing objects — public URL, routings map (`path → backend FQDN`) |

**Resources:** VNet (`10.0.0.0/8`), AGW subnet (`10.0.0.0/24`), Standard static public IP, Application Gateway (Basic, capacity 1) with host-based listeners and path-based routing.

**State key:** `terraform-states-global/networking.tfstate`

---

### `apps-service`

Reusable module for a single backend API service. Consumed once per app per environment.

| Variable | Description |
|---|---|
| `organization_code` | Locates global and environment-group remote state |
| `environment_group` | e.g. `nonprod`, `prod` |
| `environment` | e.g. `dev`, `test`, `prod` |
| `app_name` | Used in resource naming and as the container image name |

**Resources:** User-assigned managed identity, ACR pull role assignment, AAD application + service principal (non-prod), Application Insights, SQL database (Basic SKU), Service Bus topics and subscription, Key Vault secrets for all configuration.

**State key:** `terraform-states-<environment_group>/apps-service-<app_name>-<environment>.tfstate`

---

### `apps-web`

Reusable module for a single frontend web application. Wraps `apps-web-hosting` and adds AAD app registration wired up to backend service scopes.

| Variable | Description |
|---|---|
| `organization_code` | Locates global and environment-group remote state |
| `environment_group` | e.g. `nonprod`, `prod` |
| `environment` | e.g. `dev`, `test`, `prod` |
| `app_name` | Used in naming and as the container image name |
| `image_tag` | Docker image tag to deploy |
| `with_hosting` | Whether to deploy the Container App (default: `true`) |
| `api_service_names` | List of backend service names this app has API access to |

**State key:** `terraform-states-<environment_group>/apps-web-<app_name>-<environment>.tfstate`

---

### `apps-web-hosting`

Sub-module used by `apps-web`. Provisions the Container App and supporting resources.

| Variable | Description |
|---|---|
| `app_fully_qualified_name` | Full resource name |
| `resource_group_name` | Deployment target resource group |
| `location` | Azure region |
| `container_registry_login_server` | ACR login endpoint |
| `container_registry_id` | ACR resource ID |
| `container_app_environment_id` | Target Container App Environment |
| `key_vault_id` | Key Vault for storing the app FQDN secret |
| `app_name` | Container image name |
| `image_tag` | Container image tag |

---

## CI/CD Pipelines

Pipeline templates live in `devops/templates/` and are consumed by application repos via Azure DevOps repository resource references (`@infraGlobal`).

### `infrastructure-global-deploy.yml`

Deploys the `global` module (Container Registry).

| Parameter | Description |
|---|---|
| `serviceConnection` | Azure DevOps service connection |
| `backendResourceGroup` | Resource group for Terraform state storage |
| `backendStorageAccount` | Storage account for Terraform state |
| `organizationCode` | Full org code |
| `organizationShortCode` | Short org code |

### `infrastructure-environment-group-deploy.yml`

Deploys the `environment-group` module. Run once per environment group.

Accepts all global parameters plus `environmentGroup`.

### `networking-deploy.yml`

Deploys the `networking` module. Requires a pre-generated services networking file that maps app public URLs to backend FQDNs. A helper script (`devops/scripts/networking-rebuild-services-networking-file.ps1`) generates this file by reading Key Vault secrets.

### `apps-service-infra-deploy.yml`

Deploys the `apps-service` module for a single app and environment. After `terraform apply`, the pipeline:

1. Installs `sqlcmd`
2. Opens a temporary SQL Server firewall rule for the pipeline agent IP
3. Creates SQL database users for the managed identity, service principal, and admin UPNs
4. Assigns `db_owner` to each user
5. Removes the firewall rule

### `apps-web-build.yml` / `apps-web-deploy.yml`

Build and deploy pipeline templates for frontend web applications.

---

## Variable Groups

Variable groups follow the convention `infrastructure-global-<environment_group>` and contain the parameters required by the pipeline templates above. Create one group per environment group in Azure DevOps Library.

---

## Naming Conventions

| Resource type | Pattern |
|---|---|
| Resource group | `<organization_code>-infrastructure-global[-<environment_group>]` |
| SQL Server | `<organization_code>-sql-<environment_group>` |
| Service Bus | `<organization_code>-sb-<environment_group>` |
| Container App Environment | `<organization_code>-cae-<environment_group>` |
| Log Analytics Workspace | `<organization_code>-law-<environment_group>` |
| Key Vault | `<organization_short_code>-kv-<environment_group>` |
| App Gateway | `<organization_code>-agw` |
| Virtual Network | `<organization_code>-vnet` |
| Container Registry | `<organization_code>acr` |
| App (fully qualified) | `<environment>-<organization_code>-<app_name>-<type>` |

---

## License

Copyright 2024 Comharte

Licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE) for the full text.
