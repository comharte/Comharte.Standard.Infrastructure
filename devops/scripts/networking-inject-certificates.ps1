param(
    [Parameter(Mandatory)][string]$KeyVault,
    [Parameter(Mandatory)][string]$Certificates,
    [Parameter(Mandatory)][string]$OutputFile
)

$ErrorActionPreference = 'Stop'

$certNames = $Certificates -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }

$result = @{}

foreach ($certName in $certNames) {
    Write-Host "Reading certificate '$certName' from Key Vault '$KeyVault'..."

    $secretValue = az keyvault secret show --vault-name $KeyVault --name $certName --query "value" -o tsv

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to read certificate '$certName' from Key Vault '$KeyVault'"
        exit 1
    }

    $result[$certName] = @{
        data     = $secretValue.Trim()
        password = ""
    }

    Write-Host "[OK] Loaded certificate '$certName'"
}

$output = @{ ssl_certificates = $result } | ConvertTo-Json -Depth 5

$output | Set-Content $OutputFile -Encoding UTF8

Write-Host "[OK] Written to $OutputFile"
