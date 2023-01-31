<#
.DESCRIPTION
Tests if the current user has admin privileges.
#>
function Test-Admin() {
  if ($IsWindows) {
    $principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  }

  return 0 -eq (id -u)
}

<#
.DESCRIPTION
Invokes the current script or specified function with elevated privileges.

.PARAMETER Function
The function name to invoke.

.PARAMETER NoExit
The new powershell window will not exit when the process completes.

.PARAMETER Arguments
Additional arguments passed to the script or function.
#>
function Invoke-Privileged() {
  [CmdletBinding()]
  param (
    [string]$Function,
    [switch]$NoExit,
    [Parameter(ValueFromRemainingArguments)]
    [string]$Arguments
  )

  if ((Test-Admin) -or -not $IsWindows) {
    return
  }

  $isVerbose = $PSBoundParameters['Verbose'] -eq $true
  $isDebug = $PSBoundParameters['Debug'] -eq $true

  $PSBoundParameters.Remove('Function') 1> $null
  $PSBoundParameters.Remove('NoExit') 1> $null
  $PSBoundParameters.Remove('Verbose') 1> $null
  $PSBoundParameters.Remove('Arguments') 1> $null
  $PSBoundParameters.Remove('Debug') 1> $null

  $boundArgs = ($PSBoundParameters.GetEnumerator() | ForEach-Object { "-$($_.Key) $($_.Value)" }),
  ($isVerbose ? '-Verbose' : ''), ($isDebug ? '-Debug' : '') -join ' '

  if ($Function) {
    Start-Process -FilePath 'pwsh' -Verb 'RunAs' -ArgumentList ($NoExit ? '-NoExit': ''),
    '-Command', ". $($MyInvocation.PSCommandPath); $Function $boundArgs $Arguments"
  } else {
    Start-Process -FilePath 'pwsh' -Verb 'RunAs' -ArgumentList ($NoExit ? '-NoExit': ''),
    $MyInvocation.PSCommandPath, $boundArgs, $Arguments
  }
}
