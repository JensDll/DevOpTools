﻿using namespace System.Diagnostics.CodeAnalysis

[SuppressMessageAttribute('PSReviewUnusedParameter', 'IsAdmin')]
param (
  [Parameter(Mandatory)]
  [bool]$IsAdmin
)

BeforeAll {
  . "$PSScriptRoot\__fixtures__\import.ps1"
}

Describe 'Test-Admin' {
  It 'return <IsAdmin>' {
    Test-Admin | Should -Be $IsAdmin
  }
}
