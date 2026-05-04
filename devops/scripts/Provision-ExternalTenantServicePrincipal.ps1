param(
    [Parameter(Mandatory = $true)]
    [string]$MainTenantId,

    [Parameter(Mandatory = $true)]
    [string]$MainTenantAppTagQualifier,

    [Parameter(Mandatory = $true)]
    [string]$ExternalTenantId
)

$ErrorActionPreference = "Stop"

# --- Query main tenant for all apps matching the tag qualifier ---

Write-Host "Acquiring access token for main tenant '$MainTenantId'..."
$mainTokenResponse = az account get-access-token --tenant $MainTenantId --resource-type ms-graph | ConvertFrom-Json
if (-not $mainTokenResponse.accessToken) {
    Write-Error "Failed to acquire access token for main tenant '$MainTenantId'."
}

$mainHeaders = @{
    Authorization  = "Bearer $($mainTokenResponse.accessToken)"
    "Content-Type" = "application/json"
}

Write-Host "Querying applications with tag '$MainTenantAppTagQualifier' in main tenant..."
$appsUri = "https://graph.microsoft.com/v1.0/applications?`$filter=tags/any(t:t eq '$MainTenantAppTagQualifier')&`$select=appId,displayName"
$appsResponse = Invoke-RestMethod -Uri $appsUri -Headers $mainHeaders -Method Get

$apps = $appsResponse.value
if ($apps.Count -eq 0) {
    Write-Host "No applications found with tag '$MainTenantAppTagQualifier'. Nothing to provision."
    exit 0
}

Write-Host "Found $($apps.Count) application(s) to provision."

# --- Acquire token for external tenant ---

Write-Host "Acquiring access token for external tenant '$ExternalTenantId'..."
$extTokenResponse = az account get-access-token --tenant $ExternalTenantId --resource-type ms-graph | ConvertFrom-Json
if (-not $extTokenResponse.accessToken) {
    Write-Error "Failed to acquire access token for external tenant '$ExternalTenantId'."
}

$extHeaders = @{
    Authorization  = "Bearer $($extTokenResponse.accessToken)"
    "Content-Type" = "application/json"
}

# --- Provision each app in the external tenant ---

foreach ($app in $apps) {
    $appId = $app.appId
    $displayName = $app.displayName

    Write-Host "Checking service principal for app '$displayName' ($appId) in tenant '$ExternalTenantId'..."

    $filterUri = "https://graph.microsoft.com/v1.0/servicePrincipals?`$filter=appId eq '$appId'"
    $existing = Invoke-RestMethod -Uri $filterUri -Headers $extHeaders -Method Get

    if ($existing.value.Count -gt 0) {
        Write-Host "  Already exists (objectId: $($existing.value[0].id)). Skipping."
        continue
    }

    Write-Host "  Not found. Provisioning..."
    $body = @{ appId = $appId } | ConvertTo-Json
    $created = Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/servicePrincipals" -Headers $extHeaders -Method Post -Body $body
    Write-Host "  Created (objectId: $($created.id))."
}

Write-Host "Done."
