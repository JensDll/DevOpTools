using namespace System.Security.Cryptography.X509Certificates

BeforeAll {
  . "$PSScriptRoot\__fixtures__\import.ps1"
}

Describe 'New-RootCA' {
  BeforeAll {
    InModuleScope DevOpTools {
      $script:CaRootDir = $args[0]
    } -ArgumentList "$TestDrive\root"

    New-RootCA -Verbose

    $script:rootCa = [X509Certificate2]::new((Join-Path $TestDrive root root_ca ca.crt))
  }

  It 'Creates the right number of files' {
    Get-ChildItem 'TestDrive:\root\root_ca' -File | Should -HaveCount 3
    Get-ChildItem 'TestDrive:\root\root_ca\private' | Should -HaveCount 1
  }

  It 'Creates the root CA' {
    'TestDrive:\root\root_ca\ca.crt' | Should -Exist
    'TestDrive:\root\root_ca\ca.csr' | Should -Exist
    'TestDrive:\root\root_ca\ca.pfx' | Should -Exist
    'TestDrive:\root\root_ca\private\ca.key' | Should -Exist
  }

  It 'Is signed by itself' {
    $rootCa.Issuer | Should -Be $rootCa.Subject
  }
}

Describe 'New-SubordinateCA' {
  BeforeAll {
    InModuleScope DevOpTools {
      $script:CaRootDir = $args[0]
      $script:CaSubDir = $args[1]
    } -ArgumentList "$TestDrive\root", "$TestDrive\sub"

    New-SubordinateCA -Name ca

    $script:rootCa = [X509Certificate2]::new((Join-Path $TestDrive root root_ca ca.crt))
    $script:subCa = [X509Certificate2]::new((Join-Path $TestDrive sub ca ca.crt))
  }

  It 'Creates the right number of files' {
    Get-ChildItem 'TestDrive:\sub\ca' -File | Should -HaveCount 3
    Get-ChildItem 'TestDrive:\sub\ca\private' | Should -HaveCount 1
  }

  It 'Creates the subordinate CA' {
    'TestDrive:\sub\ca\ca.crt' | Should -Exist
    'TestDrive:\sub\ca\ca.csr' | Should -Exist
    'TestDrive:\sub\ca\ca.pfx' | Should -Exist
    'TestDrive:\sub\ca\private\ca.key' | Should -Exist
  }

  It 'Is issued by the root CA' {
    $subCa.Issuer | Should -Be $rootCa.Subject
  }

  Describe 'With name constraints' {
    BeforeAll {
      New-SubordinateCA -Name ca_name_constraints -PermittedDNS foo.com, bar.com, baz.com

      $script:subCa = [X509Certificate2]::new((Join-Path $TestDrive sub ca_name_constraints ca.crt))
    }

    It 'Has name constraints' {
      $extensions = $subCa.Extensions | Where-Object { $_.Oid.Value -eq '2.5.29.30' }
      $extensions | Should -HaveCount 1
    }
  }
}

Describe 'PKI certificate lifecycle' {
  BeforeAll {
    InModuleScope DevOpTools {
      $script:CaRootDir = $args[0]
      $script:CaSubDir = $args[1]
    } -ArgumentList "$TestDrive\root", "$TestDrive\sub"

    New-RootCA
  }

  Describe 'New-SubordinateCA' {
    BeforeAll {
      New-SubordinateCA -Name sub_ca1
      New-SubordinateCA -Name sub_ca2 -PermittedDNS foo.com, bar.com, baz.com

      $script:subCa1 = [X509Certificate2]::new((Join-Path $TestDrive sub sub_ca1 ca.crt))
      $script:subCa2 = [X509Certificate2]::new((Join-Path $TestDrive sub sub_ca2 ca.crt))
    }

    Describe 'Get-SuboridinateCAName' {
      It 'Returns the names of registered subordinate certificate authorities' {
        Get-SuboridinateCAName | Should -BeExactly 'sub_ca1', 'sub_ca2'
      }
    }

    Describe 'New-Certificate' {
      BeforeAll {
        New-Certificate -Issuer sub_ca1 -Request $PSScriptRoot\__fixtures__\cert.conf `
          -Name sub_ca1 -Destination $TestDrive
        New-Certificate -Issuer sub_ca2 -Request $PSScriptRoot\__fixtures__\cert.conf `
          -Name sub_ca2 -Destination $TestDrive
      }

      It 'Creates the right number of files' {
        Get-ChildItem 'TestDrive:\' -File | Should -HaveCount 4
      }

      It 'Creates the certficates' {
        'TestDrive:\sub_ca1.crt' | Should -Exist
        'TestDrive:\sub_ca2.crt' | Should -Exist
      }

      It 'Creates the keys' {
        'TestDrive:\sub_ca1.key' | Should -Exist
        'TestDrive:\sub_ca2.key' | Should -Exist
      }
    }
  }
}
