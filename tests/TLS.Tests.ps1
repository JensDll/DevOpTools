BeforeAll {
  . "$PSScriptRoot\__fixtures__\import.ps1"
}

Describe 'New-RootCA' {
  BeforeAll {
    # Arrange
    InModuleScope DevOpTools {
      $script:CaRootDir = $args[0]
    } -ArgumentList "$TestDrive\root"

    $script:rootCa = 'TestDrive:\root\root_ca'

    # Act
    New-RootCA -Verbose
  }

  It 'Created the right amount files' {
    Get-ChildItem $rootCa -File | Should -HaveCount 3
    Get-ChildItem "$rootCa\private" | Should -HaveCount 1
  }

  # Assert
  It 'Created the root CA' {
    "$rootCa\ca.crt" | Should -Exist
    "$rootCa\ca.csr" | Should -Exist
    "$rootCa\ca.pfx" | Should -Exist
    "$rootCa\private\ca.key" | Should -Exist
  }
}

Describe 'PKI certificate lifecycle' {
  BeforeAll {
    # Arrange
    InModuleScope DevOpTools {
      $script:CaRootDir = $args[0]
      $script:CaSubDir = $args[1]
    } -ArgumentList "$TestDrive\root", "$TestDrive\sub"

    # Act
    New-RootCA
    New-SubordinateCA -Name sub_ca1
    New-SubordinateCA -Name sub_ca2 -PermittedDNS foo.com, bar.com, baz.com
    New-Certificate -Issuer sub_ca1 -Request $PSScriptRoot\__fixtures__\cert.conf `
      -Name sub_ca1 -Destination $TestDrive
    New-Certificate -Issuer sub_ca2 -Request $PSScriptRoot\__fixtures__\cert.conf `
      -Name sub_ca2 -Destination $TestDrive
  }

  # Assert
  It 'Created the right amount files' {
    Get-ChildItem 'TestDrive:\' -File | Should -HaveCount 4
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
