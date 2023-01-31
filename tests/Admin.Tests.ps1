param (
  [Parameter(Mandatory)]
  [bool] $IsAdmin
)

BeforeAll {
  . "$PSScriptRoot\import.ps1"
}

Describe 'Test-Admin' {
  It 'return <IsAdmin>' {
    Test-Admin | Should -Be $IsAdmin
  }
}
