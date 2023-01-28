#!/bin/bash

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
declare -r script_dir
declare -r reset="\033[0m"
declare -r red="\033[0;31m"
declare -r yellow="\033[0;33m"

__usage()
{
  echo "Usage: $(basename "${BASH_SOURCE[0]}") --home <path> --permitted-dns <domain>"
  exit 2
}

__error() {
  echo -e "${red}error: $*${reset}" 1>&2
}

__warn() {
  echo -e "${yellow}warning: $*${reset}"
}

while [[ $# -gt 0 ]]
do
  # Replace leading "--" with "-" and convert to lowercase
  declare -l opt="${1/#--/-}"

  case "$opt" in
  -\?|-help|-h)
    __usage
    ;;
  -home)
    shift
    export DEVOPTOOLS_CA_HOME="$1"
    ;;
  -permitted-dns)
    shift
    export DEVOPTOOLS_CA_PERMITTED_DNS="$1"
    ;;
  *)
    __error "Unknown option: $1" && __usage
    ;;
  esac

  shift
done

[[ -z $DEVOPTOOLS_CA_HOME ]] && __error "Missing value for parameter --home" && __usage
[[ -z $DEVOPTOOLS_CA_PERMITTED_DNS ]] && __error "Missing value for parameter --permitted-dns" && __usage

declare -r root_config="$script_dir/root.conf"
declare -r sub_config="$script_dir/sub.conf"

declare -r name=sub_ca

declare -r csr="$DEVOPTOOLS_CA_HOME/$name.csr"
declare -r key="$DEVOPTOOLS_CA_HOME/private/$name.key"
declare -r crt="$DEVOPTOOLS_CA_HOME/$name.crt"
declare -r pfx="$DEVOPTOOLS_CA_HOME/$name.pfx"

openssl req -new -config "$sub_config" -out "$csr" -keyout "$key" \
  -noenc 2> /dev/null

openssl ca -config "$root_config" -in "$csr" -out "$crt" \
  -extensions sub_ca_ext -notext -batch

openssl pkcs12 -export -in "$crt" -inkey "$key" \
  -name 'DevOpTools Development Subordinate CA' \
  -out "$pfx" -password 'pass:'
