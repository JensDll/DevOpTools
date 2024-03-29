﻿using namespace System.Diagnostics.CodeAnalysis

BeforeAll {
  . "$PSScriptRoot\__fixtures__\import.ps1"
}

Describe 'AWSCredentials' {
  BeforeEach {
    $credentialsFilePath = "$([IO.Path]::GetTempPath())$([Guid]::NewGuid())_aws_credentials"

    InModuleScope DevOpTools {
      $script:CredentialsFilePath = $args[0]
      function script:aws { throw 'aws not mocked' }
    } -ArgumentList $credentialsFilePath

    New-Item $credentialsFilePath -Force -ItemType File

    Mock aws {
      switch ($args[0] + " " + $args[1]) {
        'iam list-access-keys' {
          return 'access-key-1 access-key-2'
        }
        'iam create-access-key' {
          return 'access-key secret-key'
        }
      }
    } -ModuleName DevOpTools

    Mock Write-Error {} -ModuleName DevOpTools
  }

  Describe 'Read-AWSCredential' {
    BeforeEach {
      # Arrange
      @'
[TestUser]
  accessKey = access-key
  secretKey = secret-key
'@ | Out-File $credentialsFilePath
    }

    It 'Reads the credentials' {
      # Act
      $credentials = Read-AWSCredential -Username 'TestUser'

      # Assert
      $credentials.AccessKey | Should -Be 'access-key'
      $credentials.SecretKey | Should -Be 'secret-key'
    }

    It "Fails if the user doesn't exist" {
      # Act + Assert
      { Read-AWSCredential -Username 'Invalid' } | Should -Throw
      Should -Invoke -CommandName Write-Error -ModuleName DevOpTools -Exactly -Times 1
    }
  }

  Describe 'New-AWSCredential' {
    Describe 'With existing credentials file (<exists>)' -ForEach @(
      @{ exists = $true }
      @{ exists = $false }
    ) {
      Describe 'With -Recreate (<withRecreate>)' -ForEach @(
        @{ withRecreate = $true }
        @{ withRecreate = $false }
      ) {
        BeforeEach {
          # Arrange
          if (-not $exists) {
            Remove-Item $credentialsFilePath
          }

          # Act
          New-AWSCredential -Username 'TestUser' -Recreate:$withRecreate
          [SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
          $credentials = Read-AWSCredential -Username 'TestUser'
        }

        # Assert
        It -Skip:(-not $withRecreate) 'call iam delete-access-key' {
          Should -Invoke -CommandName 'aws' -ModuleName DevOpTools -Exactly -Times 1 `
            -ParameterFilter { "$args" -match 'iam delete-access-key.+--access-key-id access-key-1' }
          Should -Invoke -CommandName 'aws' -ModuleName DevOpTools -Exactly -Times 1 `
            -ParameterFilter { "$args" -match 'iam delete-access-key.+--access-key-id access-key-2' }
        }

        It 'The credentials file exists' {
          $credentialsFilePath | Should -Exist
        }

        It 'Calls aws iam create-access-key' {
          Should -Invoke -CommandName 'aws' -ModuleName DevOpTools -Exactly -Times 1 `
            -ParameterFilter { "$args" -match 'iam create-access-key.+--user-name TestUser' }
        }

        It 'Created new credentials' {
          $credentials.AccessKey | Should -Be 'access-key'
          $credentials.SecretKey | Should -Be 'secret-key'
        }

        It -Skip:$withRecreate 'Fails if credentials already exist' {
          { New-AWSCredential -Username 'TestUser' } | Should -Throw
          Should -Invoke -CommandName Write-Error -ModuleName DevOpTools -Exactly -Times 1
        }
      }
    }

    AfterEach {
      Remove-Item $credentialsFilePath
    }
  }
}
