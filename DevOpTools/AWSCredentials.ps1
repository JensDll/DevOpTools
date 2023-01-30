. $PSScriptRoot\Env.ps1

$CredentialsFilePath = Join-Path $DevOpToolsHome aws-credentials

<#
.DESCRIPTION
Create new AWS credentials for the specified user and store them to the file system.

.PARAMETER UserName
The user name to create the credentials for.

.PARAMETER Recreate
Delete the existing credentials if they exist and recreate them.
#>
function New-AWSCredentials {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [string]$UserName,
    [switch]$Recreate
  )

  if (-not (Test-Path $CredentialsFilePath)) {
    Write-Verbose "Creating new AWS credentials file at '$CredentialsFilePath'"
    New-Item $CredentialsFilePath -Force -ItemType File 1> $null
  }

  if ($Recreate) {
    Write-Verbose "Recreating AWS credentials for user '$UserName'"
    Remove-IAMCredentials $UserName
  } else {
    if (Test-AwsCredentials $UserName) {
      Write-Error "User '$UserName' already has cached credentials. Pass -Recreate to recreate them"
      Get-Help New-AWSCredentials -Parameter Recreate
      throw
    }

    Write-Verbose "Creating new AWS credentials for user '$UserName'"
  }

  Write-AWSCredentials $UserName
}

<#
.DESCRIPTION
Read AWS credentials for the specified user.

.PARAMETER UserName
The user name to read the credentials for.
#>
function Read-AWSCredentials {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [string]$UserName
  )

  if (-not (Test-AWSCredentials $UserName)) {
    Write-Error "Crendentials not found for user '$UserName'"
    throw
  }

  $accessKey = git config --file $CredentialsFilePath --get "$UserName.accessKey"
  $secretKey = git config --file $CredentialsFilePath --get "$UserName.secretKey"

  return @{
    AccessKey = $accessKey
    SecretKey = $secretKey
  }
}

<#
.DESCRIPTION
Remove AWS credentials for the specified user. It will remove them both
locally and from the IAM user.

.PARAMETER UserName
The user name to remove the credentials for.
#>
function Remove-AWSCredentials {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [string]$UserName
  )

  Write-Verbose "Removing AWS credentials for user '$UserName'"

  Remove-IAMCredentials $UserName

  git config --file $CredentialsFilePath --remove-section $UserName
}

function Write-AWSCredentials {
  param(
    [Parameter(Mandatory, Position = 0)]
    [string]$UserName
  )

  $credentials = (aws iam create-access-key --user-name $UserName --query 'AccessKey.[AccessKeyId, SecretAccessKey]' --output text) -split '\s+'

  git config --file $CredentialsFilePath "$UserName.accessKey" $credentials[0]
  git config --file $CredentialsFilePath "$UserName.secretKey" $credentials[1]
}

function Test-AWSCredentials {
  param(
    [Parameter(Mandatory, Position = 0)]
    [string]$UserName
  )

  return [bool] (git config --get --file $CredentialsFilePath "$UserName.accessKey")
}

function Remove-IAMCredentials {
  param(
    [Parameter(Mandatory, Position = 0)]
    [string]$UserName
  )

  $accessKeys = (aws iam list-access-keys --user-name $UserName --query 'AccessKeyMetadata[].AccessKeyId' --output text) -split '\s+'

  foreach ($accesKey in $accessKeys) {
    aws iam delete-access-key --access-key-id $accesKey --user-name $UserName
  }
}
