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
    export DEVOPTOOLS_CA_HOME="$1"
    ;;
  -request-config)
    shift
    declare -r request_config="$1"
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

[[ -z $DEVOPTOOLS_CA_HOME ]] && __error "Missing value for parameter --home" && __usage
[[ -z $request_config ]] && __error "Missing value for parameter --request-config" && __usage
[[ -z $destination ]] && __error "Missing value for parameter --destination" && __usage
[[ -z $name ]] && __error "Missing value for parameter --name" && __usage
[[ $type != "server" && $type != "client" ]] && \
  __error "Invalid value for parameter --type; must be one of: server, client" && \
  __usage

declare -r sub_config="$script_dir/sub.conf"

declare -r key="$destination/$name.key"
declare -r csr="$destination/$name.csr"
declare -r crt="$destination/$name.crt"

openssl genpkey -out "$key" -algorithm RSA -pkeyopt rsa_keygen_bits:4096 -quiet
openssl req -new -config "$request_config" -key "$key" -out "$csr"
openssl ca -config "$sub_config" -in "$csr" -out "$crt" -extensions "${type}_ext" -notext -batch

cat "$DEVOPTOOLS_CA_HOME/sub_ca.crt" "$DEVOPTOOLS_CA_HOME/root_ca.crt" >> "$crt"
