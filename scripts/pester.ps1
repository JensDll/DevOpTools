param(
  [switch]$AsAdmin
)

Import-Module $PSScriptRoot\..\DevOpTools -Force -Function 'Invoke-Privileged', 'Test-Admin'

If ($AsAdmin -and $IsWindows) {
  Invoke-Privileged -NoExit -AsAdmin

  If (-not (Test-Admin)) {
    return
  }
}

$config = New-PesterConfiguration

$testDir = Join-Path $PSScriptRoot .. tests

$config.Run.Container = $(
  (New-PesterContainer -Path $testDir\AWSCredentials.Tests.ps1)
  (New-PesterContainer -Path $testDir\DNS.Tests.ps1),
  (New-PesterContainer -Path $testDir\TLS.Tests.ps1),
  (New-PesterContainer -Path $testDir\Admin.Tests.ps1 -Data @{ IsAdmin = $AsAdmin })
)

if ($Env:CI -eq 'true') {
  $config.Run.Throw = $true
}

$config.Output.Verbosity = 'Detailed'

Invoke-Pester -Configuration $config
