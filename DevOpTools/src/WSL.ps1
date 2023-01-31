<#
.DESCRIPTION
Converts a Windows path to the equivalent WSL path.

.PARAMETER Path
The Windows path to convert.
#>
function ConvertTo-WSLPath {
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [string]$Path
  )

  process {
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
}
