$rootDir = Join-Path -Path $PSScriptRoot ..

"$rootDir\DevOpTools", "$rootDir\scripts", "$rootDir\tests" `
| Invoke-ScriptAnalyzer -Recurse -Settings "$rootDir\PSScriptAnalyzerSettings.psd1"
