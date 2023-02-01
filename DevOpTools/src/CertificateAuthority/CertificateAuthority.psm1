class CertificateAuthority {
  static [string]$BaseDir = (Join-Path $env:DEVOPTOOLS_HOME ca)
  static [string]$BaseDirWsl = (ConvertTo-WSLPath -Path ([CertificateAuthority]::BaseDir))

  [string]$Name

  CertificateAuthority($BaseDir, $Name) {
    $caBaseDir = Join-Path $BaseDir $Name

    Remove-Item -Recurse -Force $caBaseDir -ErrorAction Ignore

    $certs = Join-Path $caBaseDir certs
    $db = Join-Path $caBaseDir db
    $private = Join-Path $caBaseDir private
    $include = Join-Path $caBaseDir include
    New-Item $certs, $db, $private, $include -ItemType Directory 1> $null

    $dbIndex = Join-Path $db index
    New-Item $dbIndex -ItemType File 1> $null

    $this.Name = $Name
  }
}

class RootCertificateAuthority : CertificateAuthority {
  static [string]$BaseDir = (Join-Path ([CertificateAuthority]::BaseDir) root)

  RootCertificateAuthority() : base([RootCertificateAuthority]::BaseDir, 'root_ca') {}

  static [bool]Exists() {
    return Test-Path "$([RootCertificateAuthority]::BaseDir)\root_ca\ca.pfx"
  }

  [void]Create() {
    $script = "$PSScriptRoot\create_root.sh" | ConvertTo-WSLPath
    bash "$script" --root "$([CertificateAuthority]::BaseDirWsl)"
  }
}

class SubordinateCertificateAuthority : CertificateAuthority {
  static [string]$BaseDir = (Join-Path ([CertificateAuthority]::BaseDir) sub)

  SubordinateCertificateAuthority([string]$Name, [string[]]$PermittedDns)
  : base([SubordinateCertificateAuthority]::BaseDir, $Name) {
    $subCaExt = @"
[sub_ca_ext]
authorityKeyIdentifier  = keyid:always
basicConstraints = critical,CA:true,pathlen:0
extendedKeyUsage = serverAuth,clientAuth
keyUsage = critical,keyCertSign,cRLSign
subjectKeyIdentifier = hash
"@

    if ($PermittedDns) {
      $subCaExt += @"

nameConstraints = @name_constraints
[name_constraints]
excluded;IP.0 = 0.0.0.0/0.0.0.0
excluded;IP.1 = 0:0:0:0:0:0:0:0/0:0:0:0:0:0:0:0
$(($PermittedDNS | ForEach-Object { 'permitted;DNS.' + [int]$i++ +  " = $_" }) -join [Environment]::NewLine)
"@
    }

    Out-File -FilePath "$([RootCertificateAuthority]::BaseDir)\root_ca\include\sub_ca_ext.conf" `
      -InputObject $subCaExt
  }

  static [bool]Exists([string]$Name) {
    return Test-Path "$([SubordinateCertificateAuthority]::BaseDir)\$Name\ca.pfx"
  }

  [void]Create() {
    $script = "$PSScriptRoot\create_sub.sh" | ConvertTo-WSLPath
    bash "$script" $this.Name --root "$([CertificateAuthority]::BaseDirWsl)"
  }
}

class SubordinateCertificateAuthorities : System.Management.Automation.IValidateSetValuesGenerator {
  [string[]] GetValidValues() {
    return Get-SuboridinateCAName
  }
}
