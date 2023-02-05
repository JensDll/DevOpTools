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
  declare -l opt="${1/#--/-}"

  case "$opt" in
  -\?|-help|-h)
    __usage
    ;;
  -sub-ca-home)
    shift
    export SUB_CA_HOME="$1"
    ;;
  -request)
    shift
    declare -r request="$1"
    ;;
  -name)
    shift
    declare -r name="$1"
    ;;
  -type)
    shift
    declare -rl type="$1"
    ;;
  -destination)
    shift
    declare -r destination="$1"
    ;;
  *)
    __error "Unknown option: $1" && __usage
    ;;
  esac

  shift
done

declare -r config="$script_dir/sub.conf"
declare -r new_key="$script_dir/p256"

declare -r key="$destination/$name.key"
declare -r csr="$destination/$name.csr"
declare -r crt="$destination/$name.crt"

openssl req -config "$request" -newkey param:"$new_key" -noenc -out "$csr" -keyout "$key"

openssl ca -config "$config" -in "$csr" -out "$crt" -extensions "${type}_ext" -notext -batch
