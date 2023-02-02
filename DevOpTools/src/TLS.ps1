using namespace System.Security.Cryptography.X509Certificates

using module .\CertificateAuthority

<#
.DESCRIPTION
Creates a new root certificate authority (CA) if it doesn't exist.
#>
function New-RootCA() {
  [CmdletBinding()]
  param()

  if ([RootCertificateAuthority]::Exists()) {
    Write-Warning 'Root CA already exists (skipping)'
    return
  }

  $rootCa = [RootCertificateAuthority]::new()
  $rootCa.Create()
}

<#
.DESCRIPTION
Creates a new subordinate CA from the root CA,
if one with the given name doesn't exist.

.PARAMETER Name
The name of the new subordinate CA. It will be used a reference
in other command like New-Certificate.

.PARAMETER PermittedDNS
A list of DNS names that the subordinate CA is permitted to issue.
They will be added to the X.509v3 name constraints extension.
#>
function New-SubordinateCA() {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$Name,
    [string[]]$PermittedDNS
  )

  if (-not [RootCertificateAuthority]::Exists()) {
    throw 'Subordinate CA cannot be created without a root CA'
  }

  if ([SubordinateCertificateAuthority]::Exists($Name)) {
    Write-Warning "Subordinate CA with name '$Name' already exists (skipping)"
    return
  }

  $subCa = [SubordinateCertificateAuthority]::new($Name, $PermittedDNS)
  $subCa.Create()
}

<#
.DESCRIPTION
Returns the names of available subordinate certificate authorities (CAs).
#>
function Get-SubordinateCAName() {
  Get-ChildItem ([SubordinateCertificateAuthority]::BaseDir) -Name
}

<#
.DESCRIPTION
Creates a new X.509 certificate.

.PARAMETER Issuer
The name of the subordinate certificate authority (CA) to issue the certificate.

.PARAMETER Request
The path to the certificate signing request (CSR) config file.
It will be used by the openssl-req command.

.PARAMETER Type
The type of certificate. Valid values are 'server' and 'client'.

.PARAMETER Name
The name of the key ([name].key) and certificate ([name].crt) file.

.PARAMETER Destination
The directory where the key and certificate are created.
#>
function New-Certificate() {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [ValidateSet([SubordinateCertificateAuthorities])]
    [string] $Issuer,
    [Parameter(Mandatory)]
    [string] $Request,
    [ValidateSet('server', 'client')]
    [string] $Type = 'server',
    [string] $Name = 'tls',
    [string] $Destination = (Resolve-Path .)
  )

  if (-not (Test-Path $Request)) {
    throw "The request config file at '$Request' does not exist!"
  }

  if (-not (Test-Path $Destination)) {
    New-Item $Destination -ItemType Directory 1> $null
  }

  $rootCaDir = "$([RootCertificateAuthority]::BaseDir)\root_ca"
  $subCaDir = "$([SubordinateCertificateAuthority]::BaseDir)\$Issuer"

  try {
    $script = "$PSScriptRoot\CertificateAuthority\new_cert.sh" | ConvertTo-WSLPath
    bash "$script" --sub-ca-home (ConvertTo-WSLPath "$subCaDir") `
      --request (ConvertTo-WSLPath "$Request") `
      --destination (ConvertTo-WSLPath "$Destination") `
      --name $Name --type $Type

    Get-Content -Path "$subCaDir\ca.crt", "$rootCaDir\ca.crt" | Add-Content "$Destination\$Name.crt"
  } finally {
    Remove-Item "$Destination\$Name.csr" -ErrorAction Ignore
  }
}

<#
.DESCRIPTION
Removes the root CA's resources from the file system and
uninstalls the root certificate from the current user's trusted root store.
#>
function Remove-RootCa() {
  [CmdletBinding(SupportsShouldProcess)]
  param()
  Uninstall-RootCA
  Remove-Item "$([RootCertificateAuthority]::BaseDir)\root_ca" -Recurse -Force
}

<#
.DESCRIPTION
Removes the subordinate CA's resources with the given name from the file system.
#>
function Remove-SubordinateCA() {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(Mandatory, Position = 0)]
    [ValidateSet([SubordinateCertificateAuthorities])]
    [string]$Name
  )

  Remove-Item "$([SubordinateCertificateAuthority]::BaseDir)\$Name" -Recurse -Force
}

<#
.DESCRIPTION
Installs the root certificate into the current user's trusted root store.
#>
function Install-RootCA() {
  $certPath = Join-Path ([RootCertificateAuthority]::BaseDir) root_ca ca.crt
  If (Test-Path $certPath) {
    Install-Certificate -Path $certPath -StoreName Root -FriendlyName 'DevOpTools Development Root CA'
  }
}

<#
.DESCRIPTION
Uninstalls the root certificate from the current user's trusted root store.
#>
function Uninstall-RootCA() {
  $certPath = Join-Path ([RootCertificateAuthority]::BaseDir) root_ca ca.crt
  if (Test-Path $certPath) {
    Uninstall-Certificate -Path $certPath -StoreName Root
  }
}

function Install-Certificate() {
  [OutputType([X509Certificate2])]
  param(
    [Parameter(Mandatory)]
    [string]$Path,
    [Parameter(Mandatory)]
    [string]$StoreName,
    [string]$FriendlyName
  )

  $store = Open-X509Store -StoreName $StoreName -OpenFlags ([OpenFlags]::ReadWrite)

  try {
    $cert = [X509Certificate2]::new($Path)
    if ($FriendlyName -and $IsWindows) { $cert.FriendlyName = $FriendlyName }
    $store.Add($cert)
  } finally {
    $store.Close()
  }

  return $cert
}

function Uninstall-Certificate() {
  param(
    [Parameter(Mandatory)]
    [string]$Path,
    [Parameter(Mandatory)]
    [string]$StoreName
  )

  $store = Open-X509Store -StoreName $StoreName

  try {
    $cert = [X509Certificate2]::new($Path)
    $store.Remove($cert)
  } finally {
    $store.Close()
  }
}

function Open-X509Store() {
  [OutputType([X509Store])]
  param(
    [Parameter(Mandatory)]
    [string]$StoreName,
    [StoreLocation]$StoreLocation = [StoreLocation]::CurrentUser,
    [OpenFlags]$OpenFlags = [OpenFlags]::MaxAllowed
  )

  $store = [X509Store]::new($StoreName, $StoreLocation)
  if (-not $?) {
    throw "Failed to access the $StoreLocation\$StoreName certificate store!"
  }

  $store.open($OpenFlags)
  if (-not $?) {
    throw "Failed to open the $StoreLocation\$StoreName certificate store with $OpenFlags privileges!"
  }

  return $store;
}
