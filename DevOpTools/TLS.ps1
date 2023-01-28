. $PSScriptRoot\WSL.ps1

$CaHome = Join-Path $env:DEV_OP_TOOLS_HOME root_ca
$CaHomeWsl = ConvertTo-WSLPath -Path $caHome

$Certs = Join-Path $CaHome certs
$Db = Join-Path $CaHome db
$DbIndex = Join-Path $Db index
$Private = Join-Path $CaHome private

function New-DevOpToolsRootCA() {
  [CmdletBinding()]
  param()

  if (Test-Path "$CaHome/root_ca.pfx") {
    return
  }

  if (-not (Test-Path $Private)) {
    New-Item $Certs, $Db, $Private -ItemType Directory 1> $null
    New-Item $DbIndex -ItemType File 1> $null
  }

  wsl --exec "$WSLScriptRoot/CA/create_root.sh" --home $CaHomeWsl

  $certPath = Join-Path $CaHome root_ca.pfx
  Import-PfxCertificate -FilePath $certPath -CertStoreLocation Cert:\CurrentUser\My -Exportable 1> $null
}

function New-DevOpToolsSubordinateCA() {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string] $PermittedDNS
  )

  wsl --exec "$WSLScriptRoot/CA/create_sub.sh" --home $CaHomeWsl --permitted-dns $PermittedDNS

  $certPath = Join-Path $CaHome sub_ca.pfx
  Import-PfxCertificate -FilePath $certPath -CertStoreLocation Cert:\CurrentUser\My -Exportable 1> $null
}

function New-DevOpToolsCertificate() {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string] $RequestConfig,
    [Parameter(Mandatory)]
    [string] $Name,
    [string] $Destination = $(Resolve-Path -Path .)
  )

  if (-not (Test-Path $Destination)) {
    New-Item $Destination -ItemType Directory 1> $null
  }

  wsl --exec "$WSLScriptRoot/CA/new_cert.sh" `
    --home $CaHomeWsl `
    --destination (ConvertTo-WSLPath -Path $Destination) `
    --name $Name `
    --type server `
    --request-config (ConvertTo-WSLPath -Path $RequestConfig)
}

function Import-DevOpToolsRootCA() {
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
