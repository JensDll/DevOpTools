@{
  Severity            = @('Error', 'Warning', 'Information')
  IncludeDefaultRules = $true
  ExcludeRules        = @(
    'PSUseShouldProcessForStateChangingFunctions',
    'PSAvoidUsingPositionalParameters',
    'PSAvoidGlobalVars'
  )
}
