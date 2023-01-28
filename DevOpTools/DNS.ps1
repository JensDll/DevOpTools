$HostFilePath = 'C:\Windows\System32\drivers\etc\hosts'

<#
.DESCRIPTION
Add new host entries to the system's hosts file.

.PARAMETER IPAddress
The IP address to resolve.

.PARAMETER Domain
The domain for which to resolve the IP address.

.PARAMETER Subdomains
Any number of subdomains.
#>
function Add-DNSEntries() {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory, Position = 0)]
    [string]$IPAddress,
    [Parameter(Mandatory, Position = 1)]
    [string]$Domain,
    [Parameter(Position = 2)]
    [string[]]$Subdomains
  )

  $PSBoundParameters.Remove('SubDomains') > $null

  Invoke-Privileged -Function 'Add-DNSEntries' @PSBoundParameters `
  ( $Subdomains ? "-SubDomains $($Subdomains -join ',')" : '')

  if (-not (Test-Admin)) {
    return
  }

  $isVerbose = $PSBoundParameters['Verbose'] -eq $true

  Remove-DNSEntries -Domain $Domain

  Write-Verbose "Writing DNS entries to location: $HostFilePath"

  $hasNewlime = (Get-Content $HostFilePath -Raw) -Match [System.Environment]::NewLine + '$'

  $entries = ($hasNewlime ? '' : [System.Environment]::NewLine) + "$IPAddress $Domain # Added by PowerShell DevOp Tools"

  foreach ($subdomain in $Subdomains) {
    $entries += [System.Environment]::NewLine + "$IPAddress $subdomain.$Domain # Added by PowerShell DevOp Tools"
  }

  Add-Content -Path $HostFilePath -Value $entries -NoNewline

  if ($isVerbose) {
    Get-Content $HostFilePath -Raw
    Write-Verbose 'Done ... Press Enter to exit:'
    Read-Host 1> $null
  }
}

<#
.DESCRIPTION
Remove previously added host entries from the system's hosts file.

.PARAMETER Domain
Remove entries for this domain. But only if Add-DNSEntries previously added them.
#>
function Remove-DNSEntries() {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [string]$Domain
  )

  Invoke-Privileged -Function 'Remove-DNSEntries' @PSBoundParameters

  if (-not (Test-Admin)) {
    return
  }

  $isVerbose = $PSBoundParameters['Verbose'] -eq $true

  $lines = @()

  foreach ($line in Get-Content $HostFilePath) {
    if ($line -NotMatch "$Domain # Added by PowerShell DevOp Tools") {
      $lines += $line
    }
  }

  Set-Content -Path $HostFilePath -Value ($lines -join [System.Environment]::NewLine) -NoNewline

  if ($isVerbose) {
    Get-Content $HostFilePath -Raw
    Write-Verbose 'Done ... Press Enter to exit:'
    Read-Host 1> $null
  }
}
