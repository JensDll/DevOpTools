BeforeAll {
  . "$PSScriptRoot\__fixtures__\import.ps1"
}

Describe 'ConvertTo-WSLPath' {
  Describe "<path> -> <expected>" -ForEach @(
    @{ Path = 'A:\Windows\System32'; Expected = '/mnt/a/Windows/System32' }
    @{ Path = 'B:\Users\Alice\src\DevOpTools\'; Expected = '/mnt/b/Users/Alice/src/DevOpTools/' }
    @{ Path = 'C:\Program Files (x86)\dotnet\'; Expected = '/mnt/c/Program Files (x86)/dotnet/' }
  ) {
    It 'Passing as named paramter' {
      ConvertTo-WSLPath -Path $Path | Should -Be $Expected
    }

    It 'Passing as positional paramter' {
      ConvertTo-WSLPath $Path | Should -Be $Expected
    }

    It 'Passing as pipeline input (by type)' {
      $Path | ConvertTo-WSLPath | Should -Be $Expected
    }

    It 'Passing as pipeline input (by property name)' {
      [pscustomobject]$_ | ConvertTo-WSLPath | Should -Be $Expected
    }
  }
}
