param (
  [Parameter(Mandatory)]
  [bool] $IsAdmin
)

BeforeAll {
  Import-Module $PSScriptRoot\..\DevOpTools -Force
}

Describe 'Test-Admin' {
  It 'return <IsAdmin>' {
    Test-Admin | Should -Be $IsAdmin
  }
}
