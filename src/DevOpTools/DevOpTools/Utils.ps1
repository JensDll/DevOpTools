<#
.DESCRIPTION
Convert a Windows path to an equivalent WSL mount path.

.PARAMETER Path
The Windows path to convert.
#>
function ConvertTo-WSLPath {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [string]$Path
  )

  $wslPath = $Path -replace '\\', '/'
  $wslPath = [regex]::Replace($wslPath, '^(\w):/', {
      param(
        [System.Text.RegularExpressions.Match]$match
      )
    
      return "/mnt/$($match.Groups[1].Value.ToLower())/"
    }
  )

  return $wslPath
}

$WSLScriptRoot = ConvertTo-WSLPath $MyInvocation.PSScriptRoot
$ConfigPath = Join-Path -Path (Resolve-Path '~') -ChildPath '.devoptools'
