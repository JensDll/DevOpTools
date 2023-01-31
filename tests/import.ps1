if ($global:DEVOPTOOLS_TEST_INSTALLED) {
  Import-Module DevOpTools -Force
} else {
  Import-Module $PSScriptRoot\..\DevOpTools -Force
}
