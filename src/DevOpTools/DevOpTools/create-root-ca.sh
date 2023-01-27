#!/bin/bash

DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
RESET="\033[0m"
RED="\033[0;31m"
YELLOW="\033[0;33m"

__usage()
{
  echo "Usage: $(basename "${BASH_SOURCE[0]}") [options]
Options:
    --domain | -d       The domain name to use for the certificate.
    --home              The path where CA related resources are stored.
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
  -domain|-d)
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

openssl req -new \
  -config "$DIR/root-ca.conf" \
  -out "$CA_HOME/certs/root-ca.csr" \
  -keyout "$CA_HOME/private/tls.key" \
  -noenc

openssl ca -selfsign \
  -create_serial \
  -config "$DIR/root-ca.conf" \
  -in "$CA_HOME/certs/root-ca.csr" \
  -out "$CA_HOME/certs/tls.crt" \
  -extensions ca_ext \
  -batch

openssl pkcs12 -export \
  -in "$CA_HOME/certs/tls.crt" \
  -inkey "$CA_HOME/private/tls.key" \
  -name "PowerShell DevOpTools development certificate" \
  -out "$CA_HOME/certs/tls.p12" \
  -password "pass:"
