#!/bin/bash

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
declare -r script_dir
declare -r reset="\033[0m"
declare -r red="\033[0;31m"
declare -r yellow="\033[0;33m"

__usage()
{
  echo "Usage: $(basename "${BASH_SOURCE[0]}")"
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
  -request)
    shift
    declare -r request="$1"
    ;;
  -destination)
    shift
    declare -r destination="$1"
    ;;
  -name)
    shift
    declare -r name="$1"
    ;;
  -type)
    shift
    declare -rl type="$1"
    ;;
  *)
    __error "Unknown option: $1" && __usage
    ;;
  esac

  shift
done

[[ -z $CA_SUB_HOME ]] && __error "Missing value for parameter --home" && __usage
[[ -z $CA_ROOT_HOME ]] && __error "Missing value for parameter --home-root" && __usage
[[ -z $request ]] && __error "Missing value for parameter --request" && __usage
[[ -z $destination ]] && __error "Missing value for parameter --destination" && __usage
[[ -z $name ]] && __error "Missing value for parameter --name" && __usage
[[ $type != "server" && $type != "client" ]] && \
  __error "Invalid value for parameter --type; must be one of: server, client" && \
  __usage

declare -r config="$script_dir/sub.conf"

declare -r key="$destination/$name.key"
declare -r csr="$destination/$name.csr"
declare -r crt="$destination/$name.crt"

openssl genpkey -out "$key" -algorithm EC \
  -pkeyopt ec_paramgen_curve:P-256 -quiet

openssl req -new -config "$request" -key "$key" -out "$csr"

openssl ca -config "$config" -in "$csr" -out "$crt" -extensions "${type}_ext" -notext -batch

cat "$CA_SUB_HOME/ca.crt" "$CA_ROOT_HOME/ca.crt" >> "$crt"
