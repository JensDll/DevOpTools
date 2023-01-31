param(
  [switch]$Installed
)

Remove-Module -Name DevOpTools -ErrorAction SilentlyContinue

if ($Installed) {
  $global:DEVOPTOOLS_TEST_INSTALLED = $true
} else {
  $global:DEVOPTOOLS_TEST_INSTALLED = $false
}

$config = New-PesterConfiguration

$testDir = Join-Path $PSScriptRoot .. tests

$config.Run.Container = $(
  (New-PesterContainer -Path $testDir\AWSCredentials.Tests.ps1),
  (New-PesterContainer -Path $testDir\DNS.Tests.ps1),
  (New-PesterContainer -Path $testDir\TLS.Tests.ps1),
  (New-PesterContainer -Path $testDir\WSL.Tests.ps1),
  (New-PesterContainer -Path $testDir\Admin.Tests.ps1 -Data @{ IsAdmin = $false })
)

if ($Env:CI -eq 'true') {
  $config.Run.Throw = $true
}

$config.Output.Verbosity = 'Detailed'

Invoke-Pester -Configuration $config
