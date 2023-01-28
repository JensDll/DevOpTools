#!/bin/bash

SCRIPT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
RESET="\033[0m"
RED="\033[0;31m"
YELLOW="\033[0;33m"

__usage()
{
  echo "Usage: $(basename "${BASH_SOURCE[0]}") [options]
Options:
    --home
"
  exit 2
}

__error() {
  echo -e "${RED}error: $*${RESET}" 1>&2
}

__warn() {
  echo -e "${YELLOW}warning: $*${RESET}"
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
    export CA_HOME="$1"
    [[ -z $CA_HOME ]] && __error "Missing value for parameter --home" && __usage
    ;;
  *)
    __error "Unknown option: $1" && __usage
    ;;
  esac

  shift
done

export CA_DOMAIN=''

config="$SCRIPT_ROOT/root.conf"
name='root_ca'

csr="$CA_HOME/$name.csr"
key="$CA_HOME/private/$name.key"
crt="$CA_HOME/$name.crt"
pfx="$CA_HOME/$name.pfx"

openssl req -new -config "$config" -out "$csr" -keyout "$key" -noenc

openssl ca -selfsign -config "$config" -in "$csr" -out "$crt" \
  -extensions ca_ext -batch

openssl pkcs12 -export -in "$crt" -inkey "$key" \
  -name 'DevOpTools development root CA' \
  -out "$pfx" -password 'pass:'
