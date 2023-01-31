BeforeAll {
  . "$PSScriptRoot\import.ps1"
}

Describe 'New-RootCA' {
  BeforeAll {
    InModuleScope DevOpTools {
      $script:CaRootDir = $args[0]
    } -ArgumentList "$TestDrive\root"

    New-RootCA -Verbose
  }

  It 'Created the root CA certificate' {
    'TestDrive:\root\root_ca\ca.crt' | Should -Exist
    'TestDrive:\root\root_ca\ca.csr' | Should -Exist
    'TestDrive:\root\root_ca\ca.pfx' | Should -Exist
    'TestDrive:\root\root_ca\private\ca.key' | Should -Exist
  }
}

Describe 'PKI certificate lifecycle' {
  BeforeAll {
    InModuleScope DevOpTools {
      $script:CaRootDir = $args[0]
      $script:CaSubDir = $args[1]
    } -ArgumentList "$TestDrive\root", "$TestDrive\sub"

    New-RootCA
    New-SubordinateCA -Name sub_ca1
    New-SubordinateCA -Name sub_ca2 -PermittedDNS foo.com, bar.com, baz.com
    New-Certificate -Issuer sub_ca1 -Request $PSScriptRoot\__fixtures__\cert.conf `
      -Name sub_ca1 -Destination $TestDrive
    New-Certificate -Issuer sub_ca2 -Request $PSScriptRoot\__fixtures__\cert.conf `
      -Name sub_ca2 -Destination $TestDrive
  }

  It 'Created the certficates' {
    'TestDrive:\sub_ca1.crt' | Should -Exist
    'TestDrive:\sub_ca2.crt' | Should -Exist
  }

  It 'Created the keys' {
    'TestDrive:\sub_ca1.key' | Should -Exist
    'TestDrive:\sub_ca2.key' | Should -Exist
  }
}
