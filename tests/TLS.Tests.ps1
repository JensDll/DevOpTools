using namespace System.Diagnostics.CodeAnalysis
using namespace System.Text.RegularExpressions
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
    [SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
    $rootCa = [X509Certificate2]::new((Join-Path $TestDrive root root_ca ca.crt))
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
  }

  Context 'Without a root CA' {
    It 'Subordinate CA creation fails' {
      { New-SubordinateCA -Name ca } | Should -Throw
    }
  }

  Context 'With a root CA' {
    BeforeAll {
      New-RootCA
      [SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
      $rootCa = [X509Certificate2]::new((Join-Path $TestDrive root root_ca ca.crt))
    }

    Context 'Without extensions' {
      BeforeAll {
        New-SubordinateCA -Name ca
        [SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
        $subCa = [X509Certificate2]::new((Join-Path $TestDrive sub ca ca.crt))
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
    }

    Context 'With name constraints' {
      BeforeAll {
        New-SubordinateCA -Name ca_name_constraints -PermittedDNS foo.com, bar.com 1> $null
        [SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
        $subCa = [X509Certificate2]::new((Join-Path $TestDrive sub ca_name_constraints ca.crt))
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
      [SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
      $subCa1 = [X509Certificate2]::new((Join-Path $TestDrive sub sub_ca1 ca.crt))
      [SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
      $subCa2 = [X509Certificate2]::new((Join-Path $TestDrive sub sub_ca2 ca.crt))
    }

    Describe 'Get-SubordinateCAName' {
      It 'Returns the names of registered subordinate CAs' {
        Get-SubordinateCAName | Should -BeExactly 'sub_ca1', 'sub_ca2'
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

      Context 'Creates the full certificate chain' {
        BeforeAll {
          [string]$rootCert = Get-Content 'TestDrive:\root\root_ca\ca.crt' -Raw
          $rootCert = $rootCert.Trim()
          [SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
          $regex = '-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----'
        }

        Context 'Matching <_>' -ForEach @('sub_ca1', 'sub_ca2') {
          BeforeAll {
            [string]$subCert = Get-Content "TestDrive:\sub\$_\ca.crt" -Raw
            $subCert = $subCert.Trim()
            [string]$cert = Get-Content "TestDrive:\$($_).crt" -Raw
            [MatchCollection]$matches = [regex]::Matches($cert, $regex, [RegexOptions]::Singleline)
          }

          It 'Contains 3 certificates' {
            $matches | Should -HaveCount 3
          }

          It 'Contains the subordinate certificate' {
            $match = [System.Text.RegularExpressions.Match]$matches[1]
            $actual = $match.Value -replace '\r', ''
            $actual | Should -BeExactly $subCert
          }

          It 'Contains the root certificate' {
            $match = [System.Text.RegularExpressions.Match]$matches[2]
            $actual = $match.Value -replace '\r', ''
            $actual | Should -BeExactly $rootCert
          }
        }
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
