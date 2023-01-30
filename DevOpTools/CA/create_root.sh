#!/bin/bash

CA_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export CA_ROOT

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
  # Replace leading "--" with "-" and convert to lowercase
  declare -l opt="${1/#--/-}"

  case "$opt" in
  -\?|-help|-h)
    __usage
    ;;
  -home)
    shift
    export CA_ROOT_HOME="$1"
    ;;
  *)
    __error "Unknown option: $1" && __usage
    ;;
  esac

  shift
done

[[ -z $CA_ROOT_HOME ]] && __error "Missing value for parameter --home" && __usage

declare -r config="$CA_ROOT/root.conf"

declare -r csr="$CA_ROOT_HOME/ca.csr"
declare -r key="$CA_ROOT_HOME/private/ca.key"
declare -r crt="$CA_ROOT_HOME/ca.crt"
declare -r pfx="$CA_ROOT_HOME/ca.pfx"

openssl req -new -config "$config" -out "$csr" -keyout "$key" \
  -noenc 2> /dev/null

openssl ca -selfsign -config "$config" -in "$csr" -out "$crt" \
  -extensions ca_ext -notext -batch

openssl pkcs12 -export -in "$crt" -inkey "$key" \
  -name 'DevOpTools Development Root CA' \
  -out "$pfx" -passout 'pass:'
