#!/bin/sh
#
# Script: check_acme_domains_compat.sh
# Descrição: Detecta se acme.json é do Traefik v1 ou v2 e testa domínios em Certificates com rispettivo case dos campos.
# Dependências: jq, host (bind-tools)
#
# Uso: ./check_acme_domains_compat.sh [--fail-only] [--verbose]
#
# Para baixar e executar diretamente:
# curl -sSL https://raw.githubusercontent.com/marcelofmatos/scripts/main/check_acme_domains_compat.sh | sh
#

check_install() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Comando $1 não encontrado. Instalando..."
    apk add --no-cache "$2"
    if ! command -v "$1" >/dev/null 2>&1; then
      echo "Erro: falha ao instalar $1"
      exit 1
    fi
  fi
}

apk update
check_install jq jq
check_install host bind-tools

ACME_FILE="acme.json"
if [ ! -f "$ACME_FILE" ]; then
  echo "Erro: arquivo $ACME_FILE não encontrado."
  exit 1
fi

FAIL_ONLY=0
VERBOSE=0
for arg in "$@"
do
  case $arg in
    --fail-only) FAIL_ONLY=1 ;;
    --verbose) VERBOSE=1 ;;
    *) ;;
  esac
done

# Detecta formato Traefik v2: chave customizada com .Certificates
ROOT_KEY=$(jq -r 'keys_unsorted | map(select(. != "Certificates")) | .[0]' "$ACME_FILE" 2>/dev/null)
HAS_CERTS_V2=$(jq -e --arg key "$ROOT_KEY" '.[$key].Certificates? // empty' "$ACME_FILE" >/dev/null 2>&1 && echo yes || echo no)

if [ "$HAS_CERTS_V2" = "yes" ]; then
  echo "Formato Traefik v2 detectado. Chave raiz: $ROOT_KEY"
  DOMAINS=$(jq -r --arg key "$ROOT_KEY" '
    .[$key].Certificates // [] | .[] | select(.domain.main != null) | .domain.main
  ' "$ACME_FILE")
elif jq -e '.Certificates?' "$ACME_FILE" >/dev/null 2>&1; then
  echo "Formato Traefik v1 detectado."
  DOMAINS=$(jq -r '
    .Certificates // [] | .[] | select(.Domain.Main != null) | .Domain.Main
  ' "$ACME_FILE")
else
  echo "Formato de arquivo acme.json não reconhecido."
  exit 1
fi

echo "$DOMAINS" | while read -r domain; do
  if output=$(host "$domain" 2>&1); then
    if [ $FAIL_ONLY -eq 0 ]; then
      if [ $VERBOSE -eq 1 ]; then
        echo "Host para $domain:"
        echo "$output"
      else
        echo "Domínio $domain resolvido com sucesso."
      fi
      echo "------------------------------"
    fi
  else
    if [ $VERBOSE -eq 1 ]; then
      echo "Host falhou para $domain:"
      echo "$output"
    else
      echo "Falha ao resolver $domain"
    fi
    echo "------------------------------"
  fi
done
