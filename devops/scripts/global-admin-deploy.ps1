param(
    [Parameter(Mandatory)][string] $OrganizationName,
    [Parameter(Mandatory)][string] $OrganizationCode,
    [string] $Location              = "westeurope",
    [string] $BackendResourceGroup  = "infrastructure-global",
    [string] $BackendStorageAccount = "${OrganizationName}tfstates",
    [string] $BackendContainerName  = "terraform-states-global",
    [string] $BackendKey            = "global-admin.tfstate"
)

$ErrorActionPreference = "Stop"
$terraformDir = "$PSScriptRoot/../../terraform/global-admin"

# --- Bootstrap (idempotent) ---

Write-Host "[1/2] Bootstrapping global infrastructure..."

$infraRg = "infrastructure-global"
az group create --name $infraRg --location $Location | Out-Null
Write-Host "  Resource group: $infraRg"

az storage account create `
    --name $BackendStorageAccount `
    --resource-group $infraRg `
    --location $Location `
    --sku Standard_LRS `
    --allow-blob-public-access false | Out-Null
Write-Host "  Storage account: $BackendStorageAccount"

az storage container create `
    --name $BackendContainerName `
    --account-name $BackendStorageAccount `
    --auth-mode login | Out-Null
Write-Host "  Container: $BackendContainerName"

# --- Terraform ---

Write-Host "[2/2] Running Terraform global-admin..."

terraform -chdir="$terraformDir" init `
    -backend-config="resource_group_name=$BackendResourceGroup" `
    -backend-config="storage_account_name=$BackendStorageAccount" `
    -backend-config="container_name=$BackendContainerName" `
    -backend-config="key=$BackendKey" `
    -backend-config="use_azuread_auth=true"

terraform -chdir="$terraformDir" plan `
    -var="organization_name=$OrganizationName" `
    -var="organization_code=$OrganizationCode" `
    -out="$terraformDir/tfplan"

terraform -chdir="$terraformDir" apply "$terraformDir/tfplan"

Remove-Item "$terraformDir/tfplan" -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "[OK] global-admin-deploy complete."
