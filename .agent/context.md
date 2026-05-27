# Comharte.Standard.Infrastructure — Agent Context

## Design Philosophy

This infrastructure is designed to be cost-effective and operationally lean for organisations up to medium scale, while remaining structured for growth. Architecture decisions favour minimising running costs — Basic SKUs, scale-to-zero Container Apps, shared environment-group resources — without compromising the layered design that enables future evolution. The separation of global, environment-group, and per-app concerns means individual components can be upgraded independently as requirements mature — for example, moving to a Standard_v2 Application Gateway, introducing zone-redundant resources, or promoting environment groups to dedicated VNets — without rearchitecting the platform. When suggesting changes or additions, default to cost-conscious options unless the user explicitly requests higher availability or performance tiers.

---

## .agent Structure

This directory contains agent guidance files for working with this repository.

| File | Responsibility |
|---|---|
| `context.md` | Repository overview — module structure, dependencies, naming conventions, pipelines |
| `init.md` | From-scratch initialization — bootstrapping Azure resources and Azure DevOps setup |

---

## Purpose

Terraform IaC for Comharte's Azure platform. Provisions all shared infrastructure — networking, app environments, and per-app resources — across global and environment-group scopes.

---

## Repository Layout

```
terraform/         — Terraform modules (one folder per module)
devops/
  deployments/     — Azure DevOps pipeline templates (one per module)
  scripts/         — PowerShell helper scripts
```

---

## Terraform Modules

### Dependency order (deploy top to bottom)

| Module | Scope | Reads remote state from | Key resources |
|---|---|---|---|
| `global-admin` | global | *(none — foundation)* | Resource group, managed identity for deployments |
| `global` | global | `global-admin` | ACR, VNet (`10.0.0.0/8`), AGW subnet (`10.0.0.0/24`), global Key Vault, static public IP |
| `environment-group` | per environment group | `global` | Resource group, SQL Server, Service Bus, CAE subnet, internal CAE, Log Analytics, environment Key Vault, self-signed cert |
| `environment-group-network-routing` | per environment group | `global`, `environment-group` | Nginx Container App; writes Nginx FQDN to global Key Vault as `<environment_group>-reverse-proxy` |
| `global-network-routing` | global | `global` + Key Vault secrets | Application Gateway (Basic); routes HTTPS/HTTP listeners to environment-group backend pools via Nginx FQDNs |
| `apps-web` | per app × environment | `environment-group` | Container App (optional via `with_hosting`), Entra app registration + service principal, API access grants |
| `apps-web-hosting` | submodule of `apps-web` | *(variables from parent)* | Container App resource, Key Vault secret for image tag |
| `apps-service` | per app × environment group | `environment-group` | Managed identity, Entra app registration, SQL DB, Service Bus topics/subscription, App Insights, Key Vault secrets, `apps-service-configuration-defaults` submodule |
| `apps-service-configuration-defaults` | submodule of `apps-service` | *(variables from parent)* | Default Key Vault config secrets shared by all services |

### Remote state convention

- **Global state container:** `terraform-states-global`
  - `global-admin.tfstate`, `global.tfstate`
- **Per-environment-group container:** `terraform-states-<environment_group>`
  - `environment-group.tfstate`
- All state uses Azure AD auth (`use_azuread_auth = true`)
- Backend inputs passed via pipeline variables: `backendResourceGroup`, `backendStorageAccount`

### Submodule pattern

Parent modules call submodules via `source = "../<submodule>"` and pass all required values as variables — submodules never read remote state directly (exception noted in T0011: `apps-service-configuration-defaults` currently reads `key_vault_id` from environment-group state redundantly).

---

## Naming Conventions

| Resource type | Pattern |
|---|---|
| Global resources | `<organization_name>-<type>-global` |
| Environment-group resources | `<organization_code>-<type>-<environment_group>` |
| App resources | `<environment>-<app_name>-<web\|service>` |
| Key Vault secrets | `<app_fully_qualified_name>--<ConfigSection>--<Key>` |
| Reverse proxy secret | `<environment_group>-reverse-proxy` (written by `environment-group-network-routing`, read by `global-network-routing`) |

`organization_name` = full name (used in resource names requiring uniqueness).
`organization_code` = short code (used in Key Vault names, cert names, etc.).

Both sourced from `global-admin` remote state outputs.

---

## Networking Architecture

```
Internet → Static Public IP → Application Gateway (Basic, global)
                                    ↓ routes by hostname
                         Nginx Container App (per environment-group, internal CAE)
                                    ↓ routes by path/subdomain
                         App Container Apps (internal CAE, scale to zero)
```

- VNet: `10.0.0.0/8` (global)
- AGW subnet: `10.0.0.0/24`
- CAE subnets: one per environment group, CIDR passed via `var.cae_subnet_cidr` (must not overlap)
- CAE is internal (`internal_load_balancer_enabled = true`, `public_network_access = "Disabled"`)
- SSL terminates at AGW; plain HTTP internally
- `global-network-routing` variable `listeners` maps `https://<hostname>` → `<environment_group>`

---

## DevOps Pipelines

Templates live in `devops/deployments/`. Each template runs init → plan → apply for one module.

| Template | Module |
|---|---|
| `global-deploy.yml` | `terraform/global` |
| `global-network-routing-deploy.yml` | `terraform/global-network-routing` |
| `environment-group-deploy.yml` | `terraform/environment-group` |
| `environment-group-network-routing-deploy.yml` | `terraform/environment-group-network-routing` |
| `apps-web-deploy.yml` | `terraform/apps-web` |
| `apps-service-deploy.yml` | `terraform/apps-service` |

Pipeline inputs: `serviceConnection`, `backendResourceGroup`, `backendStorageAccount` (+ module-specific vars).

Pipelines run from: `https://dev.azure.com/comharte/Comharte.DevOps/_build`

**`az repos pr create`:** `--detect false --organization https://dev.azure.com/comharte --project Comharte.Standard --repository Comharte.Standard.Infrastructure`
