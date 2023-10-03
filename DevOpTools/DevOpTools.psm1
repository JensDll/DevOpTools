if ($env:DEVOPTOOLS_HOME) {
  $global:DevOpToolsHome = $env:DEVOPTOOLS_HOME
} else {
  if ($env:XDG_CONFIG_HOME) {
    $global:DevOpToolsHome = Join-Path $env:XDG_CONFIG_HOME DevOpTools
  } else {
    $global:DevOpToolsHome = Join-Path $HOME .config DevOpTools
  }
}

. $PSScriptRoot\src\AWSCredentials.ps1
. $PSScriptRoot\src\Admin.ps1
. $PSScriptRoot\src\TLS.ps1
. $PSScriptRoot\src\DNS.ps1
. $PSScriptRoot\src\WSL.ps1
