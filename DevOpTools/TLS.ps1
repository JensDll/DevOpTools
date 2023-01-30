. $PSScriptRoot\WSL.ps1

$IncludeDir = Join-Path $PSScriptRoot CA include

$CaRootDir = Join-Path $DevOpToolsHome ca root
$CaSubDir = Join-Path $DevOpToolsHome ca sub

function New-RootCA() {
  [CmdletBinding()]
  param()

  if (Test-CA -Root root_ca) {
    Write-Warning 'Root CA already exists (skipping)'
    return
  }

  $ca = Initialize-CA -Root root_ca

  wsl --exec "$WSLScriptRoot/CA/create_root.sh" --home $ca.Home
}

function New-SubordinateCA() {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string] $Name,
    [string[]] $PermittedDNS = @()
  )

  if (Test-CA $Name) {
    Write-Warning "Subordinate CA with name '$Name' already exists (skipping)"
    return
  }

  $ca = Initialize-CA $Name

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

  Out-File -FilePath $IncludeDir\sub_ca_ext.conf -InputObject $subCaExt

  wsl --exec "$WSLScriptRoot/CA/create_sub.sh" `
    --home $ca.Home `
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

  if (-not (Test-CA $Issuer)) {
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

  wsl --exec "$WSLScriptRoot/CA/new_cert.sh" `
    --home (Join-Path $CaSubDir $Issuer | ConvertTo-WSLPath) `
    --home-root (Join-Path $CaRootDir root_ca | ConvertTo-WSLPath) `
    --request (ConvertTo-WSLPath -Path $Request) `
    --destination (ConvertTo-WSLPath -Path $Destination) `
    --name $Name `
    --type $Type

  Remove-Item $Destination\$Name.csr -ErrorAction Ignore
}

function Install-RootCA() {
  $certPath = Join-Path $CaHome root_ca.crt
  $result = Import-Certificate -FilePath $certPath -CertStoreLocation Cert:\CurrentUser\Root
  $result[0].FriendlyName = 'DevOpTools Development Root CA'
}

function Remove-DevOpToolsCertificates() {
  [CmdletBinding()]
  param()

  if (-not (Test-Path $DbIndex)) {
    return
  }

  $lookup = [System.Collections.Generic.HashSet[string]]::new()

  foreach ($line in Get-Content $DbIndex) {
    $parts = $line -split '\t'
    $serialNumber = [string]$parts[3]
    $lookup.Add($serialNumber) | Out-Null
  }

  foreach ($storeName in 'My', 'Root') {
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

    $store.Certificates | ForEach-Object {
      if ($lookup.Contains($_.SerialNumber)) {
        $store.Remove($_)
        if ($?) {
          Write-Verbose "Removed certificate with serial number '$($_.SerialNumber)' from the $storeLocation\$storeName certificate store."
        } else {
          Write-Error "Failed to remove certificate with serial number '$($_.SerialNumber)' from the $storeLocation\$storeName certificate store!"
        }
      }
    }

    $store.close()
  }

  Remove-Item -Recurse -Force $CaHome
}

function Test-CA() {
  param(
    [Parameter(Mandatory)]
    [string]$Name,
    [switch]$Root
  )

  return [bool](Test-Path (Join-Path ($Root ? $CaRootDir : $CaSubDir) $Name ca.pfx))
}

function Initialize-CA() {
  param(
    [Parameter(Mandatory)]
    [string]$Name,
    [switch]$Root
  )

  $caHome = Join-Path ($Root ? $CaRootDir : $CaSubDir) $Name
  $caHomeWsl = ConvertTo-WSLPath $caHome

  Write-Verbose "Initializing CA '$Name' at '$caHome'"

  Remove-Item -Recurse -Force $caHome -ErrorAction Ignore

  $certs = Join-Path $caHome certs
  $db = Join-Path $caHome db
  $private = Join-Path $caHome private
  New-Item $certs, $db, $private -ItemType Directory 1> $null

  $dbIndex = Join-Path $db index
  New-Item $dbIndex -ItemType File 1> $null

  return [PSCustomObject]@{
    Home = $caHomeWsl
  }
}
