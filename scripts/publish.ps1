[CmdletBinding(SupportsShouldProcess)]
param(
  [Parameter(ParameterSetName = 'Production')]
  [string]$NuGetApiKey,
  [Parameter(ParameterSetName = 'Local')]
  [switch]$Local
)

$rootDir = Join-Path -Path $PSScriptRoot ..

$srcDir = Join-Path -Path $rootDir DevOpTools
$publishDir = Join-Path -Path $rootDir publish DevOpTools

$whatIf = $WhatIfPreference
$confirm = $ConfirmPreference

$WhatIfPreference = $ConfirmPreference = $false

Remove-Item -Path $publishDir -Recurse -ErrorAction SilentlyContinue
Copy-Item -Path $srcDir -Destination $publishDir -Recurse
Copy-Item -Path "$rootDir\LICENSE.txt", "$rootDir\README.md" -Destination $publishDir
Get-ChildItem $publishDir -Directory | Where-Object { $_.Name -like '.*' } | Remove-Item -Recurse

$WhatIfPreference = $whatIf
$ConfirmPreference = $confirm

Test-ModuleManifest -Path (Join-Path -Path $publishDir DevOpTools.psd1)

if ($Local) {
  $PSBoundParameters.Remove('Local') 1> $null
  Publish-Module -Path $publishDir -Repository local @PSBoundParameters
} else {
  Publish-Module -Path $publishDir @PSBoundParameters
}
