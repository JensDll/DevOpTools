$rootDir = Join-Path $PSScriptRoot ..
$srcDir = Join-Path $rootDir DevOpTools
$publishDir = Join-Path $rootDir publish DevOpTools

Remove-Item -Path $publishDir -Recurse -ErrorAction SilentlyContinue
Copy-Item -Path $srcDir -Destination $publishDir -Recurse
Get-ChildItem $publishDir -Directory | Where-Object { $_.Name -like '.*' } | Remove-Item -Recurse
