#!/bin/bash

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
declare -r script_dir
declare -r reset="\033[0m"
declare -r red="\033[0;31m"
declare -r yellow="\033[0;33m"

__usage()
{
  echo "Usage: $(basename "${BASH_SOURCE[0]}") --home <path>"
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
  declare -l opt="${1/#--/-}"

  case "$opt" in
  -\?|-help|-h)
    __usage
    ;;
  -root)
    shift
    export ROOT_CA_HOME="$1/root/root_ca"
    ;;
  *)
    __error "Unknown option: $1" && __usage
    ;;
  esac

  shift
done


declare -r config="$script_dir/root.conf"

declare -r csr="$ROOT_CA_HOME/ca.csr"
declare -r key="$ROOT_CA_HOME/private/ca.key"
declare -r crt="$ROOT_CA_HOME/ca.crt"
declare -r pfx="$ROOT_CA_HOME/ca.pfx"

openssl req -new -config "$config" -out "$csr" -keyout "$key" \
  -noenc 2> /dev/null

openssl ca -selfsign -config "$config" -in "$csr" -out "$crt" \
  -extensions ca_ext -notext -batch

openssl pkcs12 -export -in "$crt" -inkey "$key" \
  -name 'DevOpTools Development Root CA' \
  -out "$pfx" -passout 'pass:'
