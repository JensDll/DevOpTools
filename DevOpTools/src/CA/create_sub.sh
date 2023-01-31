#!/bin/bash

CA_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export CA_ROOT

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
    export CA_SUB_HOME="$1"
    ;;
  -home-root)
    shift
    export CA_ROOT_HOME="$1"
    ;;
  -name)
    shift
    declare -r name="$1"
    ;;
  *)
    __error "Unknown option: $1" && __usage
    ;;
  esac

  shift
done

[[ -z $CA_SUB_HOME ]] && __error "Missing value for parameter --home" && __usage
[[ -z $CA_ROOT_HOME ]] && __error "Missing value for parameter --home-root" && __usage
[[ -z $name ]] && __error "Missing value for parameter --name" && __usage

declare -r root_config="$CA_ROOT/root.conf"
declare -r sub_config="$CA_ROOT/sub.conf"

declare -r csr="$CA_SUB_HOME/ca.csr"
declare -r key="$CA_SUB_HOME/private/ca.key"
declare -r crt="$CA_SUB_HOME/ca.crt"
declare -r pfx="$CA_SUB_HOME/ca.pfx"

openssl req -new -config "$sub_config" -out "$csr" -keyout "$key" \
  -noenc 2> /dev/null

openssl ca -config "$root_config" -in "$csr" -out "$crt" \
  -extensions sub_ca_ext -notext -batch

openssl pkcs12 -export -in "$crt" -inkey "$key" \
  -name "DevOpTools Development Subordinate CA ($name)" \
  -out "$pfx" -password 'pass:'
