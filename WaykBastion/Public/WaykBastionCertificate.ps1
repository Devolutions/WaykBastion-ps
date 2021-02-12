
. "$PSScriptRoot/../Private/CertificateHelper.ps1"

function Import-WaykBastionCertificate
{
    [CmdletBinding()]
    param(
        [string] $ConfigPath,
        [string] $CertificateFile,
        [string] $PrivateKeyFile,
        [string] $Password
    )

    $ConfigPath = Find-WaykBastionConfig -ConfigPath:$ConfigPath

    $config = Get-WaykBastionConfig -ConfigPath:$ConfigPath

    $result = Get-PemCertificate -CertificateFile:$CertificateFile `
        -PrivateKeyFile:$PrivateKeyFile -Password:$Password
        
    $CertificateData = $result.Certificate
    $PrivateKeyData = $result.PrivateKey

    [string[]] $PemChain = Split-PemChain -Label 'CERTIFICATE' -PemData $CertificateData

    if ($PemChain.Count -eq 1) {
        Write-Warning "The certificate chain includes only one certificate (leaf certificate)."
        Write-Warning "The complete chain should also include the intermediate CA certificate."
    }

    $TraefikPath = Join-Path $ConfigPath "traefik"
    New-Item -Path $TraefikPath -ItemType "Directory" -Force | Out-Null

    $TraefikPemFile = Join-Path $TraefikPath "den-server.pem"
    $TraeficKeyFile = Join-Path $TraefikPath "den-server.key"

    Set-Content -Path $TraefikPemFile -Value $CertificateData -Force
    Set-Content -Path $TraeficKeyFile -Value $PrivateKeyData -Force
}
