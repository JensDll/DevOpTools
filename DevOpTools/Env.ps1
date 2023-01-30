. $PSScriptRoot\WSL.ps1

$script:WSLScriptRoot = ConvertTo-WSLPath $MyInvocation.PSScriptRoot
$script:DevOpToolsHome = Join-Path -Path $PSScriptRoot .data
