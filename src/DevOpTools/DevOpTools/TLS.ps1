. $PSScriptRoot\WSL.ps1

$name = 'root_ca'
$caHome = Join-Path $env:DEV_OP_TOOLS_HOME root_ca
$caHomeWsl = ConvertTo-WSLPath -Path $caHome

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

  wsl --exec "$WSLScriptRoot/create_root_ca.sh" --domain $Domain --home $caHomeWsl

  # $certPath = Join-Path $caHome "$name.pfx"
  # Import-PfxCertificate -FilePath $certPath -CertStoreLocation Cert:\CurrentUser\My -Exportable 1> $null
}

function Import-RootCA() {
  $certPath = Join-Path $caHome "$name.pfx"
  Import-PfxCertificate -FilePath $certPath -CertStoreLocation Cert:\CurrentUser\Root 1> $null
}
