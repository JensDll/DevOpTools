. $PSScriptRoot\WSL.ps1

$CaRootDir = Join-Path $env:DEVOPTOOLS_HOME ca root
$CaSubDir = Join-Path $env:DEVOPTOOLS_HOME ca sub

function New-RootCA() {
  [CmdletBinding()]
  param()

  if (Test-CA -Root $CaRootDir -Name root_ca) {
    Write-Warning 'Root CA already exists (skipping)'
    return
  }

  $rootCa = Initialize-CA -Root $CaRootDir -Name root_ca

  $script = "$PSScriptRoot\CA\create_root.sh" | ConvertTo-WSLPath
  bash $script --home $rootCa.Home
}

function New-SubordinateCA() {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string] $Name,
    [string[]] $PermittedDNS = @()
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

  Out-File -FilePath "$CaRootDir/root_ca/include/sub_ca_ext.conf" -InputObject $subCaExt

  $script = "$PSScriptRoot\CA\create_sub.sh" | ConvertTo-WSLPath
  bash $script `
    --home $subCa.Home `
    --home-root (Join-Path $CaRootDir root_ca | ConvertTo-WSLPath) `
    --name $Name
}

function Get-SuboridinateCAName() {
  Get-ChildItem $CaSubDir -Name
}

function New-Certificate() {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string] $Issuer,
    [Parameter(Mandatory)]
    [string] $Request,
    [ValidateSet('server', 'client')]
    [string] $Type = 'server',
    [string] $Name = 'tls',
    [string] $Destination = $(Resolve-Path .)
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

  $script = "$PSScriptRoot\CA\new_cert.sh" | ConvertTo-WSLPath
  bash $script `
    --home (Join-Path $CaSubDir $Issuer | ConvertTo-WSLPath) `
    --home-root (Join-Path $CaRootDir root_ca | ConvertTo-WSLPath) `
    --request (ConvertTo-WSLPath -Path $Request) `
    --destination (ConvertTo-WSLPath -Path $Destination) `
    --name $Name `
    --type $Type

  Remove-Item $Destination\$Name.csr -ErrorAction Ignore
}

function Install-RootCA() {
  $certPath = Join-Path $CaRootDir root_ca ca.crt
  Install-Certificate -Path $certPath -StoreName Root -FriendlyName 'DevOpTools Development Root CA'
}

function Uninstall-RootCA() {
  $certPath = Join-Path $CaRootDir root_ca ca.crt
  Uninstall-Certificate -Path $certPath -StoreName Root
}

function Install-Certificate() {
  [OutputType([System.Security.Cryptography.X509Certificates.X509Certificate2])]
  param(
    [Parameter(Mandatory)]
    [string]$Path,
    [Parameter(Mandatory)]
    [string]$StoreName,
    [string]$FriendlyName
  )

  $storeLocation = [System.Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser

  $store = [System.Security.Cryptography.X509Certificates.X509Store]::new($storeName, $storeLocation)
  if (-not $?) {
    Write-Error "Failed to access the $storeLocation\$storeName certificate store!"
    return
  }

  $openFlag = [System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite
  $store.open($openFlag)
  if (-not $?) {
    Write-Error "Failed to open the $storeLocation\$storeName certificate store with $openFlag privileges!"
    return
  }

  try {
    $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($Path)
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

  $storeLocation = [System.Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser

  $store = [System.Security.Cryptography.X509Certificates.X509Store]::new($storeName, $storeLocation)
  if (-not $?) {
    Write-Error "Failed to access the $storeLocation\$storeName certificate store!"
    return
  }

  $openFlag = [System.Security.Cryptography.X509Certificates.OpenFlags]::MaxAllowed
  $store.open($openFlag)
  if (-not $?) {
    Write-Error "Failed to open the $storeLocation\$storeName certificate store with $openFlag privileges!"
    return
  }

  try {
    $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($Path)
    $store.Remove($cert)
  } finally {
    $store.Close()
  }
}

function Test-CA() {
  [OutputType([bool])]
  param(
    [Parameter(Mandatory)]
    [string]$Root,
    [Parameter(Mandatory)]
    [string]$Name
  )

  return [bool](Test-Path (Join-Path $Root $Name ca.pfx))
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
