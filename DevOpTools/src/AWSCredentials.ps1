$CredentialsFilePath = Join-Path $DevOpToolsHome aws_credentials

<#
.DESCRIPTION
Create new AWS credentials for the given username and stores them to the file system.

.PARAMETER Username
The username to create the credentials for.

.PARAMETER Recreate
Deletes any existing credentials and recreates them.
#>
function New-AWSCredential {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [string]$Username,
    [switch]$Recreate
  )

  begin {
    if (-not (Test-Path $CredentialsFilePath)) {
      Write-Verbose "Creating new AWS credentials file at '$CredentialsFilePath'"
      New-Item $CredentialsFilePath -Force -ItemType File 1> $null
    }
  }

  process {
    if ($Recreate) {
      Write-Verbose "Recreating AWS credentials for user '$Username'"
      Remove-IAMCredential $Username
    } else {
      if (Test-AwsCredential $Username) {
        Write-Error "User '$Username' already has cached credentials. Pass -Recreate to recreate them"
        Get-Help New-AWSCredential -Parameter Recreate
        throw
      }

      Write-Verbose "Creating new AWS credentials for user '$Username'"
    }

    Write-AWSCredential $Username
  }
}

<#
.DESCRIPTION
Reads AWS credentials for the given username.

.PARAMETER Username
The username to read the credentials.
#>
function Read-AWSCredential {
  [CmdletBinding()]
  [OutputType([hashtable])]
  param(
    [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [string]$Username
  )

  process {
    if (-not (Test-AWSCredential $Username)) {
      Write-Error "Crendentials not found for user '$Username'"
      throw
    }

    $accessKey = git config --file $CredentialsFilePath --get "$Username.accessKey"
    $secretKey = git config --file $CredentialsFilePath --get "$Username.secretKey"

    return @{
      AccessKey = $accessKey
      SecretKey = $secretKey
    }
  }
}

<#
.DESCRIPTION
Removes AWS credentials for the given username locally and remotely.

.PARAMETER Username
The username to remove the credentials.
#>
function Remove-AWSCredential {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [string]$Username
  )

  process {
    Write-Verbose "Removing AWS credentials for user '$Username'"

    Remove-IAMCredential $Username

    git config --file $CredentialsFilePath --remove-section $Username
  }
}

function Write-AWSCredential {
  param(
    [Parameter(Mandatory)]
    [string]$Username
  )

  $credentials = (aws iam create-access-key --user-name $Username --query 'AccessKey.[AccessKeyId, SecretAccessKey]' --output text) -split '\s+'

  git config --file $CredentialsFilePath "$Username.accessKey" $credentials[0]
  git config --file $CredentialsFilePath "$Username.secretKey" $credentials[1]
}

function Test-AWSCredential {
  [OutputType([bool])]
  param(
    [Parameter(Mandatory)]
    [string]$Username
  )

  return [bool] (git config --get --file $CredentialsFilePath "$Username.accessKey")
}

function Remove-IAMCredential {
  param(
    [Parameter(Mandatory)]
    [string]$Username
  )

  $accessKeys = (aws iam list-access-keys --user-name $Username --query 'AccessKeyMetadata[].AccessKeyId' --output text) -split '\s+'

  foreach ($accesKey in $accessKeys) {
    aws iam delete-access-key --access-key-id $accesKey --user-name $Username
  }
}
