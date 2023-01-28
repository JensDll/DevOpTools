. $PSScriptRoot\WSL.ps1

$caHome = Join-Path $env:DEV_OP_TOOLS_HOME root_ca
$caHomeWsl = ConvertTo-WSLPath -Path $caHome

$certs = Join-Path $caHome certs
$db = Join-Path $caHome db
$dbIndex = Join-Path $db index
$private = Join-Path $caHome private

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
    [switch]$Force
  )

  if (-not (Test-Path $private)) {
    New-Item $certs, $db, $private -ItemType Directory 1> $null
    $startIndex = (1..4 | ForEach-Object { '{0:X4}' -f (Get-Random -Max 0xFFFF) }) -join ''
    New-Item $dbIndex -ItemType File -Value $startIndex 1> $null
  }

  wsl --exec "$WSLScriptRoot/CA/create_root.sh" --home $caHomeWsl

  # Import-PfxCertificate -FilePath "$caHome/root_ca.pfx" -CertStoreLocation Cert:\CurrentUser\My -Exportable 1> $null
}

function Get-RootCACertificate() {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory, Position = 0)]
    [string]$Domain
  )

  wsl --exec "$WSLScriptRoot/CA/create_sub.sh" --home $caHomeWsl --domain $Domain
}

function Import-RootCA() {
  $certPath = Join-Path $caHome root_ca.pfx
  Import-PfxCertificate -FilePath $certPath -CertStoreLocation Cert:\CurrentUser\Root 1> $null
}
