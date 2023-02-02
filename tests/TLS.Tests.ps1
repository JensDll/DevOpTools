using namespace System.Security.Cryptography
using namespace System.Security.Cryptography.X509Certificates

BeforeAll {
  . "$PSScriptRoot\__fixtures__\import.ps1"
}

Describe 'New-RootCA' {
  BeforeAll {
    InModuleScope CertificateAuthority {
      [CertificateAuthority]::BaseDir = $args[0]
      [CertificateAuthority]::BaseDirWsl = $args[0] | ConvertTo-WSLPath
      [RootCertificateAuthority]::BaseDir = Join-Path $args[0] root
    } -ArgumentList "$TestDrive"

    New-RootCA
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
    InModuleScope CertificateAuthority {
      [CertificateAuthority]::BaseDir = $args[0]
      [CertificateAuthority]::BaseDirWsl = $args[0] | ConvertTo-WSLPath
      [RootCertificateAuthority]::BaseDir = Join-Path $args[0] root
      [SubordinateCertificateAuthority]::BaseDir = Join-Path $args[0] sub
    } -ArgumentList "$TestDrive"

    New-RootCA
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
      New-SubordinateCA -Name ca_name_constraints -PermittedDNS foo.com, bar.com
      $script:subCa = [X509Certificate2]::new((Join-Path $TestDrive sub ca_name_constraints ca.crt))
    }

    It 'Has correct name constraints' {
      $extensions = $subCa.Extensions | Where-Object { $_.Oid.Value -eq '2.5.29.30' }
      $extensions | Should -HaveCount 1
      $nameConstraints = [X509Extension]$extensions[0]
      $result = [System.Text.Encoding]::Latin1.GetString($nameConstraints.RawData)
      $result | Should -BeLike '*foo.com*'
      $result | Should -BeLike '*bar.com*'
    }
  }
}

Describe 'PKI certificate lifecycle' {
  BeforeAll {
    InModuleScope CertificateAuthority {
      [CertificateAuthority]::BaseDir = $args[0]
      [CertificateAuthority]::BaseDirWsl = $args[0] | ConvertTo-WSLPath
      [RootCertificateAuthority]::BaseDir = Join-Path $args[0] root
      [SubordinateCertificateAuthority]::BaseDir = Join-Path $args[0] sub
    } -ArgumentList "$TestDrive"

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
      It 'Returns the names of registered subordinate CAs' {
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

Describe 'Cleanup' {
  BeforeAll {
    InModuleScope CertificateAuthority {
      [CertificateAuthority]::BaseDir = $args[0]
      [CertificateAuthority]::BaseDirWsl = $args[0] | ConvertTo-WSLPath
      [RootCertificateAuthority]::BaseDir = Join-Path $args[0] root
      [SubordinateCertificateAuthority]::BaseDir = Join-Path $args[0] sub
    } -ArgumentList "$TestDrive"

    New-RootCA
    New-SubordinateCA -Name sub_ca1
    New-SubordinateCA -Name sub_ca2
  }

  It 'Created the certificates' {
    'TestDrive:\root\root_ca\ca.crt' | Should -Exist
    'TestDrive:\sub\sub_ca1\ca.crt' | Should -Exist
    'TestDrive:\sub\sub_ca2\ca.crt' | Should -Exist
  }

  Describe 'Remove-RootCA' {
    BeforeAll {
      Mock -ModuleName DevOpTools Uninstall-RootCA {}
      Remove-RootCA
    }

    It 'Removes the root CA' {
      'TestDrive:\root\root_ca' | Should -Not -Exist
    }

    It 'Calls Uninstall-RootCA' {
      Should -Invoke -CommandName Uninstall-RootCA -ModuleName DevOpTools -Scope Describe -Times 1
    }
  }

  Describe 'Remove-SubordinateCA' {
    It 'Failes if the subordinate CA does not exist' {
      { Remove-SubordinateCA -Name 'does_not_exist' } | Should -Throw
    }

    Context 'Remove <_>' -ForEach @('sub_ca1', 'sub_ca2') {
      BeforeAll {
        Remove-SubordinateCA -Name $_
      }

      It 'Removes the subordinate CA' {
        "TestDrive:\sub\$_" | Should -Not -Exist
      }
    }
  }
}
