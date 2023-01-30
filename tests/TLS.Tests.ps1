BeforeAll {
  Import-Module $PSScriptRoot\..\DevOpTools -Force
}

Describe 'Integration' {
  It 'Should not error' {
    New-RootCA
    New-SubordinateCA -Name sub_ca1
    New-SubordinateCA -Name sub_ca2 -PermittedDNS foo.com, bar.com, baz.com
    New-Certificate -Issuer sub_ca1 -Request $PSScriptRoot\__fixtures__\cert.conf `
      -Name sub_ca1 -Destination $PSScriptRoot\TLS
    New-Certificate -Issuer sub_ca2 -Request $PSScriptRoot\__fixtures__\cert.conf `
      -Name sub_ca2 -Destination $PSScriptRoot\TLS
  }
}
