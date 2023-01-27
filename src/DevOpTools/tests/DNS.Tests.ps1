BeforeAll {
  Import-Module $PSScriptRoot\..\DevOpTools -Force
}

Describe 'DNS' {
  BeforeEach {
    $hostFilePath = "$([IO.Path]::GetTempPath())$([Guid]::NewGuid())-hosts"

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

  Describe 'Add-DNSEntries' {
    It 'should add entries to the hosts file' {
      # Act
      Add-DNSEntries -IPAddress 127.0.0.0 -Domain 'example.com' -SubDomains www, api

      # Assert
      $hostFilePath | Should -FileContentMatchExactly '^# Some comment'
      $hostFilePath | Should -FileContentMatchExactly '^192.168.3.4 foo.com'
      $hostFilePath | Should -FileContentMatchExactly '^127.0.0.0 example.com'
      $hostFilePath | Should -FileContentMatchExactly '^127.0.0.0 www.example.com'
      $hostFilePath | Should -FileContentMatchExactly '^127.0.0.0 api.example.com'
      Get-Content $hostFilePath | Should -HaveCount 5
    }

    It 'should not break when called multiple times' {
      # Act
      Add-DNSEntries -IPAddress 127.0.0.0 -Domain 'example.com' -SubDomains www, api
      Add-DNSEntries -IPAddress 127.0.0.0 -Domain 'example.com' -SubDomains www, api
      Add-DNSEntries -IPAddress 127.0.0.0 -Domain 'example.com' -SubDomains www, api

      # Assert
      $hostFilePath | Should -FileContentMatchExactly '^# Some comment'
      $hostFilePath | Should -FileContentMatchExactly '^192.168.3.4 foo.com'
      $hostFilePath | Should -FileContentMatchExactly '^127.0.0.0 example.com'
      $hostFilePath | Should -FileContentMatchExactly '^127.0.0.0 www.example.com'
      $hostFilePath | Should -FileContentMatchExactly '^127.0.0.0 api.example.com'
      Get-Content $hostFilePath | Should -HaveCount 5
    }
  }

  Describe 'Remove-DNSEntries' {
    It 'should remove entries to the hosts file' {
      # Arrange
      Add-DNSEntries -IPAddress 127.0.0.0 -Domain 'example.com' -SubDomains www, api

      # Act
      Remove-DNSEntries -Domain 'example.com'

      # Assert
      $hostFilePath | Should -FileContentMatchExactly '^# Some comment'
      $hostFilePath | Should -FileContentMatchExactly '^192.168.3.4 foo.com'
      $hostFilePath | Should -Not -FileContentMatchExactly '^127.0.0.0 example.com'
      $hostFilePath | Should -Not -FileContentMatchExactly '^127.0.0.0 www.example.com'
      $hostFilePath | Should -Not -FileContentMatchExactly '^127.0.0.0 api.example.com'
      Get-Content $hostFilePath | Should -HaveCount 2
    }

    It 'should not break when called multiple times' {
      # Arrange
      Add-DNSEntries -IPAddress 127.0.0.0 -Domain 'example.com' -SubDomains www, api

      # Act
      Remove-DNSEntries -Domain 'example.com'
      Remove-DNSEntries -Domain 'example.com'
      Remove-DNSEntries -Domain 'example.com'
      
      # Assert
      $hostFilePath | Should -FileContentMatchExactly '^# Some comment'
      $hostFilePath | Should -FileContentMatchExactly '^192.168.3.4 foo.com'
      $hostFilePath | Should -Not -FileContentMatchExactly '^127.0.0.0 example.com'
      $hostFilePath | Should -Not -FileContentMatchExactly '^127.0.0.0 www.example.com'
      $hostFilePath | Should -Not -FileContentMatchExactly '^127.0.0.0 api.example.com'
      Get-Content $hostFilePath | Should -HaveCount 2
    }
  }

  AfterEach {
    Remove-Item $hostFilePath
  }
}