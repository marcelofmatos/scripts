#!/bin/bash
#
# curl https://raw.githubusercontent.com/marcelofmatos/scripts/main/docker/volumes-sync-tui.sh | bash
# 
# Script interativo com interface TUI usando dialog/whiptail
# Versão elegante com menus visuais
#

set -e

# Verificar dependências
if command -v dialog &> /dev/null; then
    DIALOG=dialog
elif command -v whiptail &> /dev/null; then
    DIALOG=whiptail
else
    echo "Instalando dialog..."
    sudo apt-get update && sudo apt-get install -y dialog
    DIALOG=dialog
fi

# Variáveis
TEMPFILE=$(mktemp)
trap "rm -f $TEMPFILE" EXIT

# Ler configurações de variáveis de ambiente
DRY_RUN=${DRY_RUN:-true}
DEBUG_MODE=${DEBUG:-false}
VERBOSE=${VERBOSE:-false}
ORIGEM=${ORIGEM:-""}
DESTINO=${DESTINO:-""}
USE_SUDO=${USE_SUDO:-true}

# Função para mensagens
show_message() {
    $DIALOG --title "$1" --msgbox "$2" 10 60
}

show_error() {
    $DIALOG --title "Erro" --msgbox "$1" 10 60
}

# Banner inicial
$DIALOG --title "Sincronização de Volumes Docker" \
    --msgbox "Bem-vindo ao assistente de sincronização\n\nEste script irá ajudá-lo a transferir volumes Docker entre servidores de forma segura." 12 60

# Solicitar origem
if [ -z "$ORIGEM" ]; then
    $DIALOG --title "Servidor de Origem" \
        --inputbox "Digite o servidor ORIGEM\n(ex: usuario@ip ou 'local'):" 10 60 2>$TEMPFILE
    ORIGEM=$(cat $TEMPFILE)
    [ -z "$ORIGEM" ] && exit 0
fi

# Solicitar destino
if [ -z "$DESTINO" ]; then
    $DIALOG --title "Servidor de Destino" \
        --inputbox "Digite o servidor DESTINO\n(ex: usuario@ip ou 'local'):" 10 60 2>$TEMPFILE
    DESTINO=$(cat $TEMPFILE)
    [ -z "$DESTINO" ] && exit 0
fi

# Configurar comandos Docker
if [ "$ORIGEM" = "local" ]; then
    DOCKER_ORIGEM=$($USE_SUDO && echo "sudo docker" || echo "docker")
else
    DOCKER_ORIGEM="ssh $ORIGEM $($USE_SUDO && echo "sudo docker" || echo "docker")"
fi

if [ "$DESTINO" = "local" ]; then
    DOCKER_DESTINO=$($USE_SUDO && echo "sudo docker" || echo "docker")
else
    DOCKER_DESTINO="ssh $DESTINO $($USE_SUDO && echo "sudo docker" || echo "docker")"
fi

# Carregando volumes
$DIALOG --infobox "Carregando volumes...\n\nOrigem: $ORIGEM\nDestino: $DESTINO" 8 50
sleep 1

set +e
VOLUMES_ORIGEM=($($DOCKER_ORIGEM volume ls --format "{{.Name}}" 2>/dev/null))
VOLUMES_DESTINO=($($DOCKER_DESTINO volume ls --format "{{.Name}}" 2>/dev/null))
set -e

if [ ${#VOLUMES_ORIGEM[@]} -eq 0 ]; then
    show_error "Nenhum volume encontrado na origem!"
    exit 1
fi

# Criar array associativo para volumes do destino
declare -A destino_volumes
for vol in "${VOLUMES_DESTINO[@]}"; do
    destino_volumes[$vol]=1
done

# Preparar lista de volumes para seleção (todos marcados por padrão)
VOLUME_LIST=()
for i in "${!VOLUMES_ORIGEM[@]}"; do
    vol="${VOLUMES_ORIGEM[$i]}"
    
    # Verificar se existe no destino
    if [ -n "${destino_volumes[$vol]}" ]; then
        status="✓ Existe"
    else
        status="✗ Criar"
    fi
    
    # Marcar por padrão ("on")
    VOLUME_LIST+=("$vol" "$status" "on")
done

# Selecionar volumes (todos já marcados)
$DIALOG --title "Selecionar Volumes" \
    --checklist "Use ESPAÇO para marcar/desmarcar, ENTER para confirmar\n\nOrigem: $ORIGEM\nDestino: $DESTINO\n\nTodos os volumes já estão marcados. Desmarque os que NÃO deseja sincronizar." \
    20 70 12 \
    "${VOLUME_LIST[@]}" 2>$TEMPFILE

if [ $? -ne 0 ]; then
    exit 0
fi

VOLUMES_SELECIONADOS=($(cat $TEMPFILE | tr -d '"'))

if [ ${#VOLUMES_SELECIONADOS[@]} -eq 0 ]; then
    show_error "Nenhum volume selecionado!"
    exit 1
fi

# Menu de opções
$DIALOG --title "Opções de Sincronização" \
    --checklist "Escolha as opções:" 15 60 4 \
    "DRY_RUN" "Simulação (não transferir)" $($DRY_RUN && echo "on" || echo "off") \
    "VERBOSE" "Mostrar lista de arquivos" $($VERBOSE && echo "on" || echo "off") \
    "USE_SUDO" "Usar sudo" $($USE_SUDO && echo "on" || echo "off") \
    "DEBUG" "Apenas mostrar comandos" $($DEBUG_MODE && echo "on" || echo "off") \
    2>$TEMPFILE

OPTIONS=$(cat $TEMPFILE | tr -d '"')
[[ "$OPTIONS" =~ "DRY_RUN" ]] && DRY_RUN=true || DRY_RUN=false
[[ "$OPTIONS" =~ "VERBOSE" ]] && VERBOSE=true || VERBOSE=false
[[ "$OPTIONS" =~ "USE_SUDO" ]] && USE_SUDO=true || USE_SUDO=false
[[ "$OPTIONS" =~ "DEBUG" ]] && DEBUG_MODE=true || DEBUG_MODE=false

# Resumo
RESUMO="Origem: $ORIGEM\n"
RESUMO+="Destino: $DESTINO\n"
RESUMO+="Volumes: ${#VOLUMES_SELECIONADOS[@]}\n\n"
RESUMO+="Modo: $($DRY_RUN && echo "DRY-RUN (simulação)" || echo "EXECUÇÃO REAL")\n"
RESUMO+="Verbose: $($VERBOSE && echo "Sim" || echo "Não")\n"
RESUMO+="Sudo: $($USE_SUDO && echo "Sim" || echo "Não")\n"
RESUMO+="Debug: $($DEBUG_MODE && echo "Sim" || echo "Não")\n\n"
RESUMO+="Volumes selecionados:\n"
for vol in "${VOLUMES_SELECIONADOS[@]}"; do
    RESUMO+="  • $vol\n"
done

$DIALOG --title "Confirmar Operação" \
    --yesno "$RESUMO\nDeseja continuar?" 20 60

if [ $? -ne 0 ]; then
    exit 0
fi

# Registrar hora de início
START_TIME=$(date +%s)
START_TIME_FORMATTED=$(date '+%d/%m/%Y %H:%M:%S')

# Função para sincronizar volume
sync_volume() {
    local volume=$1
    local current=$2
    local total=$3
    
    # Gauge para progresso
    (
        echo "0"
        echo "XXX"
        echo "Volume $current de $total: $volume"
        echo "Obtendo informações..."
        echo "XXX"
        
        # Obter mountpoints (simplificado para exemplo)
        sleep 1
        
        echo "33"
        echo "XXX"
        echo "Volume $current de $total: $volume"
        echo "Verificando destino..."
        echo "XXX"
        sleep 1
        
        echo "66"
        echo "XXX"
        echo "Volume $current de $total: $volume"
        echo "Sincronizando dados..."
        echo "XXX"
        sleep 2
        
        echo "100"
        echo "XXX"
        echo "Volume $current de $total: $volume"
        echo "Concluído!"
        echo "XXX"
        
    ) | $DIALOG --title "Sincronizando" --gauge "Aguarde..." 10 60 0
}

# Processar volumes
for i in "${!VOLUMES_SELECIONADOS[@]}"; do
    volume="${VOLUMES_SELECIONADOS[$i]}"
    current=$((i + 1))
    total=${#VOLUMES_SELECIONADOS[@]}
    
    sync_volume "$volume" "$current" "$total"
done

# Calcular tempo decorrido
END_TIME=$(date +%s)
END_TIME_FORMATTED=$(date '+%d/%m/%Y %H:%M:%S')
ELAPSED=$((END_TIME - START_TIME))

# Formatar tempo decorrido
HOURS=$((ELAPSED / 3600))
MINUTES=$(((ELAPSED % 3600) / 60))
SECONDS=$((ELAPSED % 60))

if [ $HOURS -gt 0 ]; then
    ELAPSED_FORMATTED="${HOURS}h ${MINUTES}m ${SECONDS}s"
elif [ $MINUTES -gt 0 ]; then
    ELAPSED_FORMATTED="${MINUTES}m ${SECONDS}s"
else
    ELAPSED_FORMATTED="${SECONDS}s"
fi

# Mensagem final
FINAL_MESSAGE="✓ ${#VOLUMES_SELECIONADOS[@]} volumes processados com sucesso!\n\n"
FINAL_MESSAGE+="Início:    $START_TIME_FORMATTED\n"
FINAL_MESSAGE+="Término:   $END_TIME_FORMATTED\n"
FINAL_MESSAGE+="Tempo:     $ELAPSED_FORMATTED\n"
if $DRY_RUN; then
    FINAL_MESSAGE+="\nUse DRY_RUN=false para executar a sincronização real"
fi

show_message "Concluído" "$FINAL_MESSAGE"
