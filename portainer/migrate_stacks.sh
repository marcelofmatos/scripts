#!/bin/bash
#
# curl https://raw.githubusercontent.com/marcelofmatos/scripts/refs/heads/main/portainer/migrate_stacks.sh | bash
#
# curl https://raw.githubusercontent.com/marcelofmatos/scripts/refs/heads/main/portainer/migrate_stacks.sh > portainer-stacks-manager.sh
# bash portainer-stacks-manager.sh
#

#set -x 
set -e

# Configurações iniciais
if [[ -f .env ]]; then
  source .env
fi

SERVER_URL="${SERVER_URL:-http://localhost:9000}"
PORTAINER_USER="${PORTAINER_USER:-admin}"
PORTAINER_PW="${PORTAINER_PW:-admin}"
NEW_ENDPOINT_ID="${NEW_ENDPOINT_ID:-$1}"  # Endpoint ID da variável de ambiente ou do primeiro argumento
STACK_ID="${STACK_ID:-$2}"                # Stack ID da variável de ambiente ou do segundo argumento
NEW_SWARM_ID="${NEW_SWARM_ID:-$3}"        # Swarm ID da variável de ambiente ou do terceiro argumento

# Função para autenticação e obtenção do JWT token
function get_jwt_token() {
  RESPONSE=$(curl -s -X POST \
    -H "Content-Type:application/json" \
    -d "{\"Username\":\"$PORTAINER_USER\",\"Password\":\"$PORTAINER_PW\"}" \
    $SERVER_URL/api/auth)

  #echo "Resposta da API de autenticação: $RESPONSE"

  JWT_TOKEN=$(echo "$RESPONSE" | jq -r '.jwt')
  
  if [[ -z "$JWT_TOKEN" || "$JWT_TOKEN" == "null" ]]; then
    echo "Erro ao obter JWT token."
    exit 1
  fi
}

# Função para listar os endpoints disponíveis
function list_endpoints() {
  RESPONSE=$(curl -s -H "Authorization: Bearer $JWT_TOKEN" \
    "$SERVER_URL/api/endpoints")
  
  if echo "$RESPONSE" | jq empty > /dev/null 2>&1; then
    echo "$RESPONSE" | jq -r '.[] | "ID: \(.Id) - Nome: \(.Name) - Tipo: \(if .Type == 1 then "Docker" elif .Type == 2 then "Docker Swarm" elif .Type == 3 then "Azure" elif .Type == 4 then "Agent" elif .Type == 5 then "Edge Agent" else "Outro" end) - URL: \(.URL)"'
  else
    echo "Erro ao listar endpoints. Resposta da API:"
    echo "$RESPONSE"
    exit 1
  fi
}

# Função para selecionar o endpoint interativamente
function select_endpoint() {
  echo "Endpoints disponíveis:" >&2
  list_endpoints >&2
  
  echo "" >&2
  echo -n "Digite o ID do endpoint de destino: " >&2
  read ENDPOINT_ID
  
  if [[ -z "$ENDPOINT_ID" ]]; then
    echo "ID do endpoint não fornecido." >&2
    exit 1
  fi
  
  echo "$ENDPOINT_ID"
}

# Função para obter o Swarm ID de um endpoint
function get_swarm_id() {
  local ENDPOINT_ID=$1
  
  if [[ -z "$ENDPOINT_ID" ]]; then
    echo "ID do endpoint não fornecido." >&2
    exit 1
  fi
  
  RESPONSE=$(curl -s -H "Authorization: Bearer $JWT_TOKEN" \
    "$SERVER_URL/api/endpoints/$ENDPOINT_ID/docker/swarm")
  
  SWARM_ID=$(echo "$RESPONSE" | jq -r '.ID')
  
  if [[ -z "$SWARM_ID" || "$SWARM_ID" == "null" ]]; then
    echo "Erro: Não foi possível obter o Swarm ID do endpoint $ENDPOINT_ID." >&2
    echo "Resposta da API: $RESPONSE" >&2
    exit 1
  fi
  
  echo "$SWARM_ID"
}

# Função para listar as stacks disponíveis (exceto as que já estão no endpoint escolhido)
function list_stacks() {
  local EXCLUDE_ENDPOINT_ID=$1
  
  RESPONSE=$(curl -s -H "Authorization: Bearer $JWT_TOKEN" \
    "$SERVER_URL/api/stacks")
  
  if echo "$RESPONSE" | jq empty > /dev/null 2>&1; then
    if [[ -n "$EXCLUDE_ENDPOINT_ID" ]]; then
      echo "$RESPONSE" | jq -r --arg endpoint "$EXCLUDE_ENDPOINT_ID" '.[] | select(.EndpointId != ($endpoint | tonumber)) | "ID: \(.Id) - Name: \(.Name) - Endpoint: \(.EndpointId)"'
    else
      echo "$RESPONSE" | jq -r '.[] | "ID: \(.Id) - Name: \(.Name) - Endpoint: \(.EndpointId)"'
    fi
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

# Obter o JWT Token
get_jwt_token

# Se NEW_ENDPOINT_ID não foi fornecido, permite escolha interativa
if [[ -z "$NEW_ENDPOINT_ID" ]]; then
  NEW_ENDPOINT_ID=$(select_endpoint)
fi

echo ""
echo "Usando Endpoint ID: $NEW_ENDPOINT_ID"

# Se NEW_SWARM_ID não foi fornecido, obtém do endpoint selecionado
if [[ -z "$NEW_SWARM_ID" ]]; then
  echo "Obtendo Swarm ID do endpoint $NEW_ENDPOINT_ID..."
  NEW_SWARM_ID=$(get_swarm_id "$NEW_ENDPOINT_ID")
  echo "Swarm ID obtido: $NEW_SWARM_ID"
fi

# Se STACK_ID não foi fornecido, permite escolha interativa
if [[ -z "$STACK_ID" ]]; then
  echo ""
  echo "Stacks disponíveis (exceto as que já estão no endpoint $NEW_ENDPOINT_ID):"
  list_stacks "$NEW_ENDPOINT_ID"

  echo ""
  echo -n "Digite o ID da stack que deseja migrar: "
  read STACK_ID
  
  if [[ -z "$STACK_ID" ]]; then
    echo "ID da stack não fornecido."
    exit 1
  fi
fi

echo ""
echo "Migrando a stack ID $STACK_ID para o Swarm ID $NEW_SWARM_ID..."
migrate_stack "$STACK_ID"

echo "Parando a stack ID $STACK_ID..."
stop_stack "$STACK_ID"

#echo "Iniciando a stack ID $STACK_ID..."
#start_stack "$STACK_ID"

echo "Migração concluída."

