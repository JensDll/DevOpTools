#!/bin/bash

DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
RESET="\033[0m"
RED="\033[0;31m"
YELLOW="\033[0;33m"

__usage()
{
  echo "Usage: $(basename "${BASH_SOURCE[0]}") [options]
Options:
    --domain        The domain name to use for the certificate.
    --home          The path where the CA related resources are stored.
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
  -domain)
    shift
    export CA_DOMAIN="$1"
    [[ -z $CA_DOMAIN ]] && __error "Missing value for parameter --domain" && __usage
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

openssl rand -hex 16 > "$CA_HOME/db/serial"

root_ca_config="$DIR/root_ca.conf"
sub_ca_config="$DIR/sub_ca.conf"

root_name='root_ca'
sub_name='sub_ca'

openssl req -new -config "$root_ca_config" \
  -out "$CA_HOME/$root_name.csr" \
  -keyout "$CA_HOME/private/$root_name.key" -noenc

openssl ca -selfsign -config "$root_ca_config" \
  -in "$CA_HOME/$root_name.csr"  \
  -out "$CA_HOME/$root_name.crt" \
  -extensions ca_ext -batch

openssl req -new -config "$sub_ca_config" \
  -out "$CA_HOME/$sub_name.csr" \
  -keyout "$CA_HOME/private/$sub_name.key" -noenc

openssl ca -config "$root_ca_config" \
  -in "$CA_HOME/$sub_name.csr" \
  -out "$CA_HOME/$sub_name.crt" \
  -extensions sub_ca_ext -batch

# openssl pkcs12 -export \
#   -in "$CA_HOME/$CA_NAME.crt" \
#   -inkey "$CA_HOME/private/$CA_NAME.key" \
#   -name 'DevOpTools development root CA' \
#   -out "$CA_HOME/$CA_NAME.pfx" \
#   -password 'pass:'
