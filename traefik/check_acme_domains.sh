#!/bin/sh
#
# Script: check_acme_domains.sh
# Descrição: Lê o arquivo acme.json do Traefik v2, detecta a chave raiz customizada e testa os domínios em Certificates[].domain.main com o comando host.
# Dependências: jq, host (bind-tools)
#
# Uso: ./check_acme_domains.sh [--fail-only]
#
# Este script pode ser baixado e usado diretamente do repositório oficial:
# https://github.com/marcelofmatos/scripts
#
# Para baixar e executar diretamente:
# curl -sSL https://raw.githubusercontent.com/marcelofmatos/scripts/main/check_acme_domains.sh | sh
#
# Ou clone o repositório para usar localmente:
# git clone https://github.com/marcelofmatos/scripts.git
# cd scripts
# chmod +x check_acme_domains.sh
# ./check_acme_domains.sh --fail-only

# Função para checar se um comando existe, e instalar se não existir
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

# Instalar dependências necessárias
apk update
check_install jq jq
check_install host bind-tools

# Arquivo acme.json do Traefik
ACME_FILE="acme.json"

# Verifica se arquivo existe
if [ ! -f "$ACME_FILE" ]; then
  echo "Erro: arquivo $ACME_FILE não encontrado."
  exit 1
fi

# Parâmetro --fail-only
FAIL_ONLY=0
if [ "$1" = "--fail-only" ]; then
  FAIL_ONLY=1
fi

# Detecta a primeira chave de nível superior (ex: myresolver, default, etc)
ROOT_KEY=$(jq -r 'keys_unsorted[0]' "$ACME_FILE")
echo "Chave raiz detectada: $ROOT_KEY"

# Ler os domínios em Certificates dentro da chave raiz e testar com host
jq -r --arg key "$ROOT_KEY" '
  .[$key].Certificates // [] | .[] | select(.domain.main != null) | .domain.main
' "$ACME_FILE" | while read -r domain; do
  if host "$domain" >/dev/null 2>&1; then
    if [ $FAIL_ONLY -eq 0 ]; then
      echo "Domínio $domain resolvido com sucesso."
      echo "------------------------------"
    fi
  else
    echo "Falha ao resolver $domain"
    echo "------------------------------"
  fi
done
