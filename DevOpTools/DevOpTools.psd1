@{
  RootModule        = 'DevOpTools.psm1'
  ModuleVersion     = '0.0.9'
  GUID              = '0d0e7a69-7247-4979-a599-73850459367e'
  Author            = 'Jens Döllmann'
  Copyright         = 'Copyright (c) 2022 Jens Döllmann'
  Description       = 'A collection of DevOps related cmdlets.'
  PowerShellVersion = '5.0'
  ScriptsToProcess  = @('scripts\init.ps1')
  FunctionsToExport = @(
    # AWS
    'New-AWSCredentials',
    'Read-AWSCredentials',
    'Remove-AWSCredentials',

    # Admin
    'Test-Admin',
    'Invoke-Privileged',

    # TLS
    'New-RootCA',
    'New-SubordinateCA',
    'Get-SuboridinateCAName',
    'New-Certificate',
    'Install-RootCA',
    'Uninstall-RootCA',

    # DNS
    'Add-DNSEntries',
    'Remove-DNSEntries',

    # WSL
    'ConvertTo-WSLPath'
  )
  CmdletsToExport   = @()
  AliasesToExport   = @()
  VariablesToExport = $()
  FileList          = @()
  PrivateData       = @{
    PSData = @{
      Tags       = @('powershell', 'devops', 'Windows')
      LicenseUri = 'https://github.com/JensDll/DevOpTools/blob/main/LICENSE'
      ProjectUri = 'https://github.com/JensDll/DevOpTools'
    }
  }
}
