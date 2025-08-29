#!/bin/bash
# CRON on manager
# *   *  *   *   *     /path/to/manager-rebalanced.sh
# 
# ref.: https://github.com/moby/moby/issues/24103#issuecomment-350563727
FILE=/tmp/worker.nodes
LOCK_FILE=/tmp/worker.nodes.lock

# Verifica lock para evitar execuções concorrentes
if [[ -f "${LOCK_FILE}" ]]; then
    echo "Script já em execução"
    exit 1
fi
trap "rm -f ${LOCK_FILE}" EXIT
touch "${LOCK_FILE}"

# Cria arquivo se não existe
[[ ! -f "${FILE}" ]] && touch "${FILE}"

# Backup do arquivo anterior
cp "${FILE}" "${FILE}.bak" 2>/dev/null

# Obtém nodes workers ativos atuais
current_nodes=$(docker node ls --filter role=worker --format "{{.ID}} {{.Status}} {{.Availability}}" | awk '$2=="Ready" && $3=="Active" {print $1}' | sort)
previous_nodes=$(sort "${FILE}" 2>/dev/null)

# Conta nodes
current_count=$(echo "${current_nodes}" | grep -c '^')
previous_count=$(echo "${previous_nodes}" | grep -c '^' 2>/dev/null || echo 0)

rebalance_needed=false

echo "Nodes atuais: ${current_count}, anteriores: ${previous_count}"

# Verifica se houve mudança no número ou composição
if [[ "${current_nodes}" != "${previous_nodes}" ]]; then
    rebalance_needed=true
    
    if [[ ${current_count} -gt ${previous_count} ]]; then
        echo "Novos nodes detectados (+$((current_count - previous_count)))"
        # Mostra quais são novos
        comm -13 <(echo "${previous_nodes}") <(echo "${current_nodes}") | while read new_node; do
            echo "  + Node adicionado: ${new_node}"
        done
    elif [[ ${current_count} -lt ${previous_count} ]]; then
        echo "Nodes removidos (-$((previous_count - current_count)))"
        # Mostra quais foram removidos
        comm -23 <(echo "${previous_nodes}") <(echo "${current_nodes}") | while read removed_node; do
            echo "  - Node removido: ${removed_node}"
        done
    else
        echo "Mudança na composição dos nodes (mesmo número)"
    fi
fi

# Executa rebalanceamento se necessário
if [[ "${rebalance_needed}" == "true" ]]; then
    echo "Executando rebalanceamento da topologia..."
    if [[ -x "/var/lib/docker/volumes/manager/_data/portainer/update.sh" ]]; then
        /var/lib/docker/volumes/manager/_data/portainer/update.sh
    fi
    
    # Alternativa para force update de todos os services
    #docker service ls -q | xargs -I {} docker service update --with-registry-auth --detach=true --force {}
else
    echo "Nenhuma mudança detectada na topologia"
fi

# Atualiza arquivo com nodes atuais
echo "${current_nodes}" > "${FILE}"
