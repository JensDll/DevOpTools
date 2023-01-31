$HostFilePath = 'C:\Windows\System32\drivers\etc\hosts'

<#
.DESCRIPTION
Adds new domain entries to the system's hosts-file.

.PARAMETER IPAddress
The IP address for the domain.

.PARAMETER Domain
The domain for the IP address.

.PARAMETER Subdomains
A list of subdomains.
#>
function Add-DNSEntry() {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$IPAddress,
    [Parameter(Mandatory)]
    [string]$Domain,
    [string[]]$Subdomain
  )

  $PSBoundParameters.Remove('SubDomains') > $null

  Invoke-Privileged -Function 'Add-DNSEntry' @PSBoundParameters `
  ( $Subdomain ? "-SubDomains $($Subdomain -join ',')" : '')

  if (-not (Test-Admin)) {
    return
  }

  Remove-DNSEntry -Domain $Domain

  Write-Verbose "Writing DNS entries to '$HostFilePath'"

  $hasNewlime = (Get-Content $HostFilePath -Raw) -Match [System.Environment]::NewLine + '$'
  $entries = ($hasNewlime ? '' : [System.Environment]::NewLine) + "$IPAddress $Domain # Added by PowerShell DevOpTools"

  foreach ($subdomain in $Subdomain) {
    $entries += [System.Environment]::NewLine + "$IPAddress $subdomain.$Domain # Added by PowerShell DevOpTools"
  }

  Add-Content -Path $HostFilePath -Value $entries -NoNewline

  if (-not $VerbosePreference -eq [System.Management.Automation.ActionPreference]::SilentlyContinue) {
    Write-Verbose "The file's content is now the following:"
    Get-Content $HostFilePath -Raw
    Write-Verbose 'Done! Press Enter to exit'
    Read-Host 1> $null
  }
}

<#
.DESCRIPTION
Remove previously added domain entries from the system's hosts-file.

.PARAMETER Domain
The domain entries to remove. But only if Add-DNSEntry has added them previously.
#>
function Remove-DNSEntry() {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$Domain
  )

  Invoke-Privileged -Function 'Remove-DNSEntry' @PSBoundParameters

  if (-not (Test-Admin)) {
    return
  }

  $lines = @()

  foreach ($line in Get-Content $HostFilePath) {
    if ($line -NotMatch "$Domain # Added by PowerShell DevOpTools") {
      $lines += $line
    }
  }

  Write-Verbose "Removing DNS entries from '$HostFilePath'"

  Set-Content -Path $HostFilePath -Value ($lines -join [System.Environment]::NewLine) -NoNewline

  if (-not $VerbosePreference -eq [System.Management.Automation.ActionPreference]::SilentlyContinue) {
    Write-Verbose "The file's content is now the following:"
    Get-Content $HostFilePath -Raw
    Write-Verbose 'Done! Press Enter to exit'
    Read-Host 1> $null
  }
}
