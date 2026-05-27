# Comharte.Standard.Infrastructure

Terraform IaC for Comharte's Azure platform. Provisions all shared infrastructure — networking, app environments, and per-app resources — across global and environment-group scopes.

Licensed under the [Apache License 2.0](LICENSE).

---

## Architecture

```
Internet → Static Public IP → Application Gateway (Basic, global)
                                    ↓ routes by hostname
                         Nginx Container App (per environment-group, internal CAE)
                                    ↓ routes by path/subdomain
                         App Container Apps (internal CAE, scale to zero)
```

---

## Modules

### Dependency order

| Module | Scope | Reads remote state from | Key resources |
|---|---|---|---|
| `global-admin` | global | *(none — foundation)* | Resource group, managed identity for deployments |
| `global` | global | `global-admin` | ACR, VNet (`10.0.0.0/8`), AGW subnet (`10.0.0.0/24`), global Key Vault, static public IP |
| `environment-group` | per environment group | `global` | Resource group, SQL Server, Service Bus, CAE subnet, internal CAE, Log Analytics, environment Key Vault, self-signed cert |
| `environment-group-network-routing` | per environment group | `global`, `environment-group` | Nginx Container App; writes Nginx FQDN to global Key Vault as `<environment_group>-reverse-proxy` |
| `global-network-routing` | global | `global` + Key Vault secrets | Application Gateway (Basic); routes HTTPS/HTTP listeners to environment-group backend pools via Nginx FQDNs |
| `apps-web` | per app × environment | `environment-group` | Container App (optional via `with_hosting`), Entra app registration + service principal, API access grants |
| `apps-service` | per app × environment group | `environment-group` | Managed identity, Entra app registration, SQL DB, Service Bus topics/subscription, App Insights, Key Vault secrets |

### Remote state

- **Global:** `terraform-states-global` — `global-admin.tfstate`, `global.tfstate`
- **Per environment group:** `terraform-states-<environment_group>` — `environment-group.tfstate`
- All state uses Azure AD auth (`use_azuread_auth = true`)
- Backend inputs passed via pipeline variables: `backendResourceGroup`, `backendStorageAccount`

---

## Initialization

For from-scratch setup in a new Azure environment, see [`.agent/init.md`](.agent/init.md).

---

## CI/CD Pipelines

Pipeline templates live in `devops/deployments/`. Each template runs init → plan → apply for one module. Pipelines run from `https://dev.azure.com/comharte/Comharte.DevOps/_build`.

| Template | Module |
|---|---|
| `global-deploy.yml` | `terraform/global` |
| `global-network-routing-deploy.yml` | `terraform/global-network-routing` |
| `environment-group-deploy.yml` | `terraform/environment-group` |
| `environment-group-network-routing-deploy.yml` | `terraform/environment-group-network-routing` |
| `apps-web-deploy.yml` | `terraform/apps-web` |
| `apps-service-deploy.yml` | `terraform/apps-service` |

Common pipeline inputs: `serviceConnection`, `backendResourceGroup`, `backendStorageAccount`.

---

## Naming Conventions

| Resource type | Pattern |
|---|---|
| Global resources | `<organization_name>-<type>-global` |
| Environment-group resources | `<organization_code>-<type>-<environment_group>` |
| App resources | `<environment>-<app_name>-<web\|service>` |
| Key Vault secrets | `<app_fully_qualified_name>--<ConfigSection>--<Key>` |
| Reverse proxy secret | `<environment_group>-reverse-proxy` |

`organization_name` = full name (used in resource names requiring uniqueness).
`organization_code` = short code (used in Key Vault names, cert names, etc.).

---

## License

Copyright 2024 Comharte

Licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE) for the full text.
