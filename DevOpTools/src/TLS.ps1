﻿using namespace System.Security.Cryptography.X509Certificates

using module .\ValidateSet

$CaRootDir = Join-Path $env:DEVOPTOOLS_HOME ca root
$CaSubDir = Join-Path $env:DEVOPTOOLS_HOME ca sub

<#
.DESCRIPTION
Creates a new root certificate authority (CA) if it doesn't exist.
#>
function New-RootCA() {
  [CmdletBinding()]
  param()

  if (Test-CA -Root $CaRootDir -Name root_ca) {
    Write-Warning 'Root CA already exists (skipping)'
    return
  }

  $rootCa = Initialize-CA -Root $CaRootDir -Name root_ca

  $script = "$PSScriptRoot\CertificateAuthority\create_root.sh" | ConvertTo-WSLPath
  bash $script --home $rootCa.Home
}

<#
.DESCRIPTION
Creates a new subordinate certificate authority (CA) from the root CA
if one with the given name doesn't exist. If the root CA doesn't exist,
New-SubordinateCA will create it with a warning.

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
    [string] $Name,
    [string[]] $PermittedDNS
  )

  if (-not (Test-CA -Root $CaRootDir -Name root_ca)) {
    Write-Warning 'Subordinate CA cannot be created without a root CA (creating)'
    New-RootCA
  }

  if (Test-CA -Root $CaSubDir -Name $Name) {
    Write-Warning "Subordinate CA with name '$Name' already exists (skipping)"
    return
  }

  $subCa = Initialize-CA -Root $CaSubDir -Name $Name

  $subCaExt = @"
[sub_ca_ext]
authorityKeyIdentifier  = keyid:always
basicConstraints = critical,CA:true,pathlen:0
extendedKeyUsage = serverAuth,clientAuth
keyUsage = critical,keyCertSign,cRLSign
subjectKeyIdentifier = hash
"@

  if ($PermittedDNS) {
    $subCaExt += @"

nameConstraints = @name_constraints
[name_constraints]
excluded;IP.0 = 0.0.0.0/0.0.0.0
excluded;IP.1 = 0:0:0:0:0:0:0:0/0:0:0:0:0:0:0:0
$(($PermittedDNS | ForEach-Object { 'permitted;DNS.' + $i++ +  " = $_" }) -join [System.Environment]::NewLine)
"@
  }

  Out-File -FilePath "$CaRootDir\root_ca\include\sub_ca_ext.conf" -InputObject $subCaExt

  $script = "$PSScriptRoot\CertificateAuthority\create_sub.sh" | ConvertTo-WSLPath
  bash $script `
    --home $subCa.Home `
    --home-root (Join-Path $CaRootDir root_ca | ConvertTo-WSLPath) `
    --name $Name
}

<#
.DESCRIPTION
Returns the names of available subordinate certificate authorities (CAs).
#>
function Get-SuboridinateCAName() {
  Get-ChildItem $CaSubDir -Name
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
    [ValidateSet([ValidIssuer])]
    [string] $Issuer,
    [Parameter(Mandatory)]
    [string] $Request,
    [ValidateSet('server', 'client')]
    [string] $Type = 'server',
    [string] $Name = 'tls',
    [string] $Destination = (Resolve-Path .)
  )

  if (-not (Test-CA -Root $CaSubDir -Name $Issuer)) {
    Write-Error "Subordinate CA '$Issuer' does not exist!"
    return
  }

  if (-not (Test-Path $Request)) {
    Write-Error "Request file '$Request' does not exist!"
    return
  }

  if (-not (Test-Path $Destination)) {
    New-Item $Destination -ItemType Directory 1> $null
  }

  $script = "$PSScriptRoot\CertificateAuthority\new_cert.sh" | ConvertTo-WSLPath
  bash $script `
    --home (Join-Path $CaSubDir $Issuer | ConvertTo-WSLPath) `
    --home-root (Join-Path $CaRootDir root_ca | ConvertTo-WSLPath) `
    --request (ConvertTo-WSLPath -Path $Request) `
    --destination (ConvertTo-WSLPath -Path $Destination) `
    --name $Name `
    --type $Type

  Remove-Item $Destination\$Name.csr -ErrorAction Ignore
}

<#
.DESCRIPTION
Installs the root certificate authority (CA) into the current user's trusted root store.
#>
function Install-RootCA() {
  $certPath = Join-Path $CaRootDir root_ca ca.crt
  Install-Certificate -Path $certPath -StoreName Root -FriendlyName 'DevOpTools Development Root CA'
}

<#
.DESCRIPTION
Uninstalls the root certificate authority (CA) from the current user's trusted root store.
#>
function Uninstall-RootCA() {
  $certPath = Join-Path $CaRootDir root_ca ca.crt
  Uninstall-Certificate -Path $certPath -StoreName Root
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
    if ($FriendlyName) { $cert.FriendlyName = $FriendlyName }
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

function Test-CA() {
  [OutputType([bool])]
  param(
    [Parameter(Mandatory)]
    [string]$Root,
    [Parameter(Mandatory)]
    [string]$Name
  )

  return Test-Path "$Root\$Name\ca.pfx" -PathType Leaf
}

function Initialize-CA() {
  param(
    [Parameter(Mandatory)]
    [string]$Root,
    [Parameter(Mandatory)]
    [string]$Name
  )

  $caHome = Join-Path $Root $Name

  Write-Verbose "Initializing CA '$Name' at '$caHome'"

  Remove-Item -Recurse -Force $caHome -ErrorAction Ignore

  $certs = Join-Path $caHome certs
  $db = Join-Path $caHome db
  $private = Join-Path $caHome private
  $include = Join-Path $caHome include
  New-Item $certs, $db, $private, $include -ItemType Directory 1> $null

  $dbIndex = Join-Path $db index
  New-Item $dbIndex -ItemType File 1> $null

  return [PSCustomObject]@{
    Home = ConvertTo-WSLPath $caHome
  }
}
