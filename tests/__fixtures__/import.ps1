Remove-Module DevOpTools -Force -ErrorAction Ignore

if ($DEVOPTOOLS_TEST_INSTALLED) {
  Import-Module DevOpTools
} else {
  Import-Module $PSScriptRoot\..\..\DevOpTools
}
