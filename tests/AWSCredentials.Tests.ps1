BeforeAll {
  Import-Module $PSScriptRoot\..\DevOpTools -Force
}

Describe 'AWSCredentials' {
  BeforeEach {
    $credentialsFile = "$TestDrive\credentials"

    InModuleScope DevopTools {
      $script:CredentialsFilePath = $args[0]
    } -ArgumentList $credentialsFile

    New-Item $credentialsFile -Force -ItemType File

    Mock aws {
      switch ($args[0] + " " + $args[1]) {
        'iam list-access-keys' {
          return 'access-key-1 access-key-2'
        }
        'iam create-access-key' {
          return 'access-key secret-key'
        }
      }
    } -ModuleName DevopTools

    Mock Write-Error {} -ModuleName DevopTools
  }

  Describe 'Read-AWSCredentials' {
    BeforeEach {
      # Arrange
      @'
[TestUser]
  accessKey = access-key
  secretKey = secret-key
'@ | Out-File $credentialsFile
    }

    It 'should read the credentials' {
      # Act
      $credentials = Read-AWSCredentials -UserName 'TestUser'

      # Assert
      $credentials.AccessKey | Should -Be 'access-key'
      $credentials.SecretKey | Should -Be 'secret-key'
    }

    It 'fail if user does not exist' {
      # Act + Assert
      { Read-AWSCredentials -UserName 'Invalid' } | Should -Throw
      Should -Invoke -CommandName Write-Error -ModuleName DevopTools -Exactly -Times 1
    }
  }

  Describe 'New-AWSCredentials' {
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
            Remove-Item $credentialsFile
          }

          # Act
          New-AWSCredentials -UserName 'TestUser' -Recreate:$withRecreate
          $credentials = Read-AWSCredentials -UserName 'TestUser'
        }

        # Assert
        it -Skip:(-not $withRecreate) 'call iam delete-access-key' {
          Should -Invoke -CommandName 'aws' -ModuleName DevopTools -Exactly -Times 1 `
            -ParameterFilter { "$args" -match 'iam delete-access-key.+--access-key-id access-key-1' }
          Should -Invoke -CommandName 'aws' -ModuleName DevopTools -Exactly -Times 1 `
            -ParameterFilter { "$args" -match 'iam delete-access-key.+--access-key-id access-key-2' }
        }

        It 'credentials file exists' {
          $credentialsFile | Should -Exist
        }

        it 'call aws iam create-access-key' {
          Should -Invoke -CommandName 'aws' -ModuleName DevopTools -Exactly -Times 1 `
            -ParameterFilter { "$args" -match 'iam create-access-key.+--user-name TestUser' }
        }

        it 'create new credentials' {
          $credentials.AccessKey | Should -Be 'access-key'
          $credentials.SecretKey | Should -Be 'secret-key'
        }

        it -Skip:$withRecreate 'fail if credentials already exist' {
          { New-AWSCredentials -UserName 'TestUser' } | Should -Throw
          Should -Invoke -CommandName Write-Error -ModuleName DevopTools -Exactly -Times 1
        }
      }
    }
  }
}
