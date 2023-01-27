. $PSScriptRoot\Utils.ps1

$caHome = "$ConfigPath\root-ca"
$caHomeWSL = ConvertTo-WSLPath $caHome

<#
.DESCRIPTION
Create a new root certificate authority for development and import it
to the user's trusted root certificate store.

.PARAMETER Domain
The domain for which this certificate authority is allowed to sign certificates.
#>
function New-RootCA() {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory, Position = 0)]
    [string]$Domain
  )

  if (-not (Test-Path "$caHome\private")) {
    New-Item "$caHome\certs", "$caHome\db", "$caHome\private" -ItemType Directory 1> $null
    New-Item "$caHome\db\index" -ItemType File 1> $null
  }

  $cert = Get-ChildItem -Path Cert:\CurrentUser\Root -SSLServerAuthentication -DnsName $Domain

  if ($cert) {
    Write-Verbose 'Using existing certificate'

    $password = [System.Security.SecureString]::new()
    Export-PfxCertificate -Cert $cert -FilePath "$caHome\certs\tls.p12" -Password $password 1> $null

    wsl --exec openssl pkcs12 `
      -in "$caHomeWSL/certs/tls.p12" `
      -out "$caHomeWSL/certs/tls.crt" `
      -nokeys `
      -noenc `
      -password 'pass:'

    wsl --exec openssl pkcs12 `
      -in "$caHomeWSL/certs/tls.p12" `
      -out "$caHomeWSL/private/tls.key" `
      -nocerts `
      -noenc `
      -password 'pass:'

    return
  }

  wsl --exec "$WSLScriptRoot/create-root-ca.sh" --domain $Domain --home $caHomeWSL

  Import-PfxCertificate -FilePath "$caHome\certs\tls.p12" -CertStoreLocation Cert:\CurrentUser\Root -Exportable 1> $null
}
