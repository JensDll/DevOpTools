BeforeAll {
  . "$PSScriptRoot\__fixtures__\import.ps1"
}

Describe 'DNS' {
  BeforeEach {
    $hostFilePath = "$TestDrive\hosts"

    InModuleScope DevopTools {
      $script:hostFilePath = $args[0]
    } -ArgumentList $hostFilePath

    New-Item $hostFilePath -Force -ItemType File

    @"
# Some comment
192.168.3.4 foo.com
"@ | Out-File $hostFilePath

    Mock Test-Admin {
      return $true
    } -ModuleName DevopTools
  }

  Describe 'Add-DNSEntry' {
    It 'Adds entries to the hosts-file' {
      # Act
      Add-DNSEntry -IPAddress 127.0.0.1 -Domain 'example.com' -Subdomain www, api

      # Assert
      $hostFilePath | Should -FileContentMatchExactly '^# Some comment'
      $hostFilePath | Should -FileContentMatchExactly '^192.168.3.4 foo.com'
      $hostFilePath | Should -FileContentMatchExactly '^127.0.0.1 example.com'
      $hostFilePath | Should -FileContentMatchExactly '^127.0.0.1 www.example.com'
      $hostFilePath | Should -FileContentMatchExactly '^127.0.0.1 api.example.com'
      Get-Content $hostFilePath | Should -HaveCount 5
    }

    It 'Does not break when called multiple times' {
      # Act
      Add-DNSEntry -IPAddress 127.0.0.2 -Domain 'example.com' -Subdomain www, api
      Add-DNSEntry -IPAddress 127.0.0.2 -Domain 'example.com' -Subdomain www, api
      Add-DNSEntry -IPAddress 127.0.0.2 -Domain 'example.com' -Subdomain www, api

      # Assert
      $hostFilePath | Should -FileContentMatchExactly '^# Some comment'
      $hostFilePath | Should -FileContentMatchExactly '^192.168.3.4 foo.com'
      $hostFilePath | Should -FileContentMatchExactly '^127.0.0.2 example.com'
      $hostFilePath | Should -FileContentMatchExactly '^127.0.0.2 www.example.com'
      $hostFilePath | Should -FileContentMatchExactly '^127.0.0.2 api.example.com'
      Get-Content $hostFilePath | Should -HaveCount 5
    }
  }

  Describe 'Remove-DNSEntry' {
    It 'Removes entries from the hosts-file' {
      # Arrange
      Add-DNSEntry -IPAddress 127.0.0.1 -Domain 'example.com' -Subdomain www, api

      # Act
      Remove-DNSEntry -Domain 'example.com'

      # Assert
      $hostFilePath | Should -FileContentMatchExactly '^# Some comment'
      $hostFilePath | Should -FileContentMatchExactly '^192.168.3.4 foo.com'
      $hostFilePath | Should -Not -FileContentMatchExactly '^127.0.0.1 example.com'
      $hostFilePath | Should -Not -FileContentMatchExactly '^127.0.0.1 www.example.com'
      $hostFilePath | Should -Not -FileContentMatchExactly '^127.0.0.1 api.example.com'
      Get-Content $hostFilePath | Should -HaveCount 2
    }

    It 'Does not break when called multiple times' {
      # Arrange
      Add-DNSEntry -IPAddress 127.0.0.1 -Domain 'example.com' -Subdomain www, api

      # Act
      Remove-DNSEntry -Domain 'example.com'
      Remove-DNSEntry -Domain 'example.com'
      Remove-DNSEntry -Domain 'example.com'

      # Assert
      $hostFilePath | Should -FileContentMatchExactly '^# Some comment'
      $hostFilePath | Should -FileContentMatchExactly '^192.168.3.4 foo.com'
      $hostFilePath | Should -Not -FileContentMatchExactly '^127.0.0.1 example.com'
      $hostFilePath | Should -Not -FileContentMatchExactly '^127.0.0.1 www.example.com'
      $hostFilePath | Should -Not -FileContentMatchExactly '^127.0.0.1 api.example.com'
      Get-Content $hostFilePath | Should -HaveCount 2
    }
  }
}
