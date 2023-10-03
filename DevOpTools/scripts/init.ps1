if ($null -ne $env:DEVOPTOOLS_HOME) {
  if ($null -ne $env:XDG_CONFIG_HOME) {
    $env:DEVOPTOOLS_HOME = Join-Path $env:XDG_CONFIG_HOME DevOpTools
  } else {
    $env:DEVOPTOOLS_HOME = Join-Path $HOME .config DevOpTools
  }
}
