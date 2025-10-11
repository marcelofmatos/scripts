#!/bin/bash
#
# curl https://raw.githubusercontent.com/marcelofmatos/scripts/refs/heads/main/portainer/migrate_stacks.sh > portainer-stacks-manager.sh
#

#set -x 
set -e

# Configurações iniciais
source .env

SERVER_URL="${SERVER_URL:-http://localhost:9000}"
PORTAINER_USER="${PORTAINER_USER:-admin}"
PORTAINER_PW="${PORTAINER_PW:-admin}"
NEW_SWARM_ID="$1"  # Swarm ID passado como o primeiro argumento
NEW_ENDPOINT_ID="${NEW_ENDPOINT_ID:-2}"
STACK_ID="$2"      # Parâmetro opcional para STACK_ID

# Função para autenticação e obtenção do JWT token
function get_jwt_token() {
  RESPONSE=$(curl -s -X POST \
    -H "Content-Type:application/json" \
    -d "{\"Username\":\"$PORTAINER_USER\",\"Password\":\"$PORTAINER_PW\"}" \
    $SERVER_URL/api/auth)

  echo "Resposta da API de autenticação: $RESPONSE"

  JWT_TOKEN=$(echo "$RESPONSE" | jq -r '.jwt')
  
  if [[ -z "$JWT_TOKEN" || "$JWT_TOKEN" == "null" ]]; then
    echo "Erro ao obter JWT token."
    exit 1
  fi
}

# Função para listar as stacks disponíveis
function list_stacks() {
  RESPONSE=$(curl -s -H "Authorization: Bearer $JWT_TOKEN" \
    "$SERVER_URL/api/stacks")
  
  if echo "$RESPONSE" | jq empty > /dev/null 2>&1; then
    echo "$RESPONSE" | jq -r '.[] | "ID: \(.Id) - Name: \(.Name)"'
  else
    echo "Erro ao listar stacks. Resposta da API:"
    echo "$RESPONSE"
    exit 1
  fi
}

# Função para migrar a stack
function migrate_stack() {
  local STACK_ID=$1

  if [[ -z "$STACK_ID" ]]; then
    echo "ID da stack não fornecido."
    exit 1
  fi

  curl -s -X POST \
    -H "Authorization: Bearer $JWT_TOKEN" \
    -H "Content-Type:application/json" \
    -d "{\"EndpointId\":$NEW_ENDPOINT_ID,\"SwarmID\":\"$NEW_SWARM_ID\"}" \
    "$SERVER_URL/api/stacks/$STACK_ID/migrate" | jq
}

# Função para iniciar a stack
function start_stack() {
  local STACK_ID=$1

  if [[ -z "$STACK_ID" ]]; then
    echo "ID da stack não fornecido."
    exit 1
  fi

  curl -s -X POST \
    -H "Authorization: Bearer $JWT_TOKEN" \
    "$SERVER_URL/api/stacks/$STACK_ID/start?endpointId=$NEW_ENDPOINT_ID" | jq
}

# Função para parar a stack
function stop_stack() {
  local STACK_ID=$1

  if [[ -z "$STACK_ID" ]]; then
    echo "ID da stack não fornecido."
    exit 1
  fi

  curl -s -X POST \
    -H "Authorization: Bearer $JWT_TOKEN" \
    "$SERVER_URL/api/stacks/$STACK_ID/stop?endpointId=$NEW_ENDPOINT_ID" | jq
  sleep 4
}

# Verifica se o Swarm ID foi passado como parâmetro
if [[ -z "$NEW_SWARM_ID" ]]; then
  echo "Uso: $0 <NEW_SWARM_ID> [<STACK_ID>]"
  exit 1
fi

# Obter o JWT Token
get_jwt_token

# Verifica se o STACK_ID foi passado como segundo parâmetro
if [[ -n "$STACK_ID" ]]; then
  echo "Migrando a stack ID $STACK_ID para o Swarm ID $NEW_SWARM_ID..."
  migrate_stack "$STACK_ID"
  
  echo "Parando a stack ID $STACK_ID..."
  stop_stack "$STACK_ID"
 
  #echo "Iniciando a stack ID $STACK_ID..."
  #start_stack "$STACK_ID"
else
  echo "Stacks disponíveis:"
  list_stacks

  echo -n "Digite o ID da stack que deseja migrar: "
  read STACK_ID

  echo "Migrando a stack ID $STACK_ID para o Swarm ID $NEW_SWARM_ID..."
  migrate_stack "$STACK_ID"
  
  echo "Parando a stack ID $STACK_ID..."
  stop_stack "$STACK_ID"
 
  #echo "Iniciando a stack ID $STACK_ID..."
  #start_stack "$STACK_ID"
fi

echo "Migração concluída."

