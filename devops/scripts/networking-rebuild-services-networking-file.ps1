param(
    [Parameter(Mandatory)][string]$NetworkingFile,
    [Parameter(Mandatory)][string]$KeyVaults,
    [Parameter(Mandatory)][string]$OutputFile
)

$content = Get-Content $NetworkingFile -Raw

$kvList = $KeyVaults -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }

foreach ($vault in $kvList) {
    Write-Host "Reading secrets from Key Vault: $vault"

    $secretNames = az keyvault secret list --vault-name $vault --query "[].name" -o tsv

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to list secrets from Key Vault: $vault"
        exit 1
    }

    foreach ($secretName in $secretNames) {
        $secretName = $secretName.Trim()
        if (-not $secretName) { continue }

        $placeholder = "<$secretName>"

        if ($content -notmatch [regex]::Escape($placeholder)) { continue }

        Write-Host "Resolving: $placeholder"

        $secretValue = az keyvault secret show --vault-name $vault --name $secretName --query "value" -o tsv

        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to read secret '$secretName' from vault '$vault'"
            exit 1
        }

        $content = $content -replace [regex]::Escape($placeholder), $secretValue
    }
}

$content | Set-Content $OutputFile -Encoding UTF8

Write-Host "[OK] Written to $OutputFile"
Write-Host "--- apps.auto.tfvars.json ---"
Get-Content $OutputFile | Write-Host
