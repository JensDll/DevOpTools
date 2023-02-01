class ValidIssuer : System.Management.Automation.IValidateSetValuesGenerator {
  [string[]] GetValidValues() {
    return Get-SuboridinateCAName
  }
}
