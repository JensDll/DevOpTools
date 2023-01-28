. $PSScriptRoot\WSL.ps1

$script:WSLScriptRoot = ConvertTo-WSLPath $MyInvocation.PSScriptRoot

$env:DEV_OP_TOOLS_HOME = Join-Path -Path (Resolve-Path '~') -ChildPath '.DevOpsTools'
