$env:DEVOPTOOLS_HOME = Join-Path $HOME ($null -ne $env:XDG_CONFIG_HOME ? $env:XDG_CONFIG_HOME : '.config') devoptools
