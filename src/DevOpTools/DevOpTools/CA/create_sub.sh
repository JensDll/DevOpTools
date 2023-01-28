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
    --domain
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
  -domain)
    shift
    export CA_DOMAIN="$1"
    [[ -z $CA_DOMAIN ]] && __error "Missing value for parameter --domain" && __usage
    ;;
  *)
    __error "Unknown option: $1" && __usage
    ;;
  esac

  shift
done

root_config="$SCRIPT_ROOT/root.conf"
sub_config="$SCRIPT_ROOT/sub.conf"
name=sub_ca

csr="$CA_HOME/$name.csr"
key="$CA_HOME/private/$name.key"
crt="$CA_HOME/$name.crt"

# openssl req -new -config "$sub_config" -out "$csr" -keyout "$key" -noenc
# openssl ca -config "$root_config" -in "$csr" -out "$crt" -extensions sub_ca_ext -batch

# openssl genpkey -out "$SCRIPT_ROOT/web.key" -algorithm RSA -pkeyopt rsa_keygen_bits:2048
openssl req -new -config "$SCRIPT_ROOT/csr.conf" -key "$SCRIPT_ROOT/web.key" -out "$SCRIPT_ROOT/web.csr"
openssl ca -config "$sub_config" -in "$SCRIPT_ROOT/web.csr" -out "$SCRIPT_ROOT/web.crt" -extensions server_ext -batch
