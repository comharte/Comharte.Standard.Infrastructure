param(
    [Parameter(Mandatory = $true)]
    [string]$KeyVaultUri,

    [Parameter(Mandatory = $true)]
    [string]$CertificateName
)

$ErrorActionPreference = 'Stop'

Write-Host "Retrieving certificate '$CertificateName' from '$KeyVaultUri'..."

$vaultName = if ($KeyVaultUri -match '^https?://([^.]+)\.') { $Matches[1] } else { $KeyVaultUri }

$secret = Get-AzKeyVaultSecret -VaultName $vaultName -Name $CertificateName -AsPlainText

if (-not $secret) {
    throw "Certificate '$CertificateName' not found in Key Vault."
}

$certBytes = [Convert]::FromBase64String($secret)
$cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new(
    $certBytes,
    [string]::Empty,
    [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::UserKeySet -bor
    [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::PersistKeySet -bor
    [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable
)

$store = [System.Security.Cryptography.X509Certificates.X509Store]::new(
    [System.Security.Cryptography.X509Certificates.StoreName]::My,
    [System.Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser
)

$store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)

try {
    $store.Add($cert)
    Write-Host "Certificate installed successfully. Thumbprint: $($cert.Thumbprint)"
}
finally {
    $store.Close()
}
