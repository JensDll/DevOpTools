﻿@{
  RootModule        = 'DevOpTools.psm1'
  ModuleVersion     = '2.0.2'
  GUID              = '0d0e7a69-7247-4979-a599-73850459367e'
  Author            = 'Jens Döllmann'
  Copyright         = 'Copyright (c) 2022 Jens Döllmann'
  Description       = 'A collection of DevOps related cmdlets.'
  PowerShellVersion = '6.0'
  ScriptsToProcess  = @()
  FunctionsToExport = @(
    # AWS
    'New-AWSCredential',
    'Read-AWSCredential',
    'Remove-AWSCredential',
    # Admin
    'Test-Admin',
    'Invoke-Privileged',
    # TLS
    'New-RootCA',
    'New-SubordinateCA',
    'Get-SubordinateCAName',
    'New-Certificate',
    'Install-RootCA',
    'Uninstall-RootCA',
    'Remove-RootCa',
    'Remove-SubordinateCA'
    # DNS
    'Add-DNSEntry',
    'Remove-DNSEntry',
    # WSL
    'ConvertTo-WSLPath'
  )
  CmdletsToExport   = @()
  AliasesToExport   = @()
  VariablesToExport = @()
  FileList          = @()
  PrivateData       = @{
    PSData = @{
      Tags       = @('DevOps', 'AWS', 'Windows', 'Linux')
      ProjectUri = 'https://github.com/JensDll/DevOpTools'
      LicenseUri = 'https://github.com/JensDll/DevOpTools/blob/main/LICENSE.txt'
    }
  }
}
