#!/bin/bash

# Script interativo para sincronizar volumes Docker entre servidores
#
# curl https://raw.githubusercontent.com/marcelofmatos/scripts/main/docker/volumes-sync.sh | bash

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configurações padrão
DRY_RUN=true
DEBUG_MODE=false
ORIGEM=""
DESTINO=""

# Parse argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        --no-dry-run)
            DRY_RUN=false
            shift
            ;;
        --debug)
            DEBUG_MODE=true
            shift
            ;;
        *)
            if [ -z "$ORIGEM" ]; then
                ORIGEM="$1"
            elif [ -z "$DESTINO" ]; then
                DESTINO="$1"
            fi
            shift
            ;;
    esac
done

# Banner
echo -e "${CYAN}======================================${NC}"
echo -e "${CYAN}  Sincronização de Volumes Docker${NC}"
echo -e "${CYAN}======================================${NC}"
echo ""

# Solicitar servidores se não fornecidos
if [ -z "$ORIGEM" ]; then
    echo -e "${BLUE}Digite o servidor ORIGEM (ex: usuario@ip ou 'local'):${NC}"
    read -r ORIGEM
fi

if [ -z "$DESTINO" ]; then
    echo -e "${BLUE}Digite o servidor DESTINO (ex: usuario@ip ou 'local'):${NC}"
    read -r DESTINO
fi

# Configurar comandos Docker
if [ "$ORIGEM" = "local" ]; then
    DOCKER_ORIGEM="docker"
    SSH_ORIGEM=""
else
    DOCKER_ORIGEM="ssh $ORIGEM docker"
    SSH_ORIGEM="ssh $ORIGEM"
fi

if [ "$DESTINO" = "local" ]; then
    DOCKER_DESTINO="docker"
    SSH_DESTINO=""
else
    DOCKER_DESTINO="ssh $DESTINO docker"
    SSH_DESTINO="ssh $DESTINO"
fi

echo ""
echo -e "${GREEN}✓ Origem:${NC} $ORIGEM"
echo -e "${GREEN}✓ Destino:${NC} $DESTINO"
if $DRY_RUN; then
    echo -e "${YELLOW}⚠ Modo:${NC} DRY-RUN (use --no-dry-run para executar)"
else
    echo -e "${RED}⚠ Modo:${NC} EXECUÇÃO REAL"
fi
if $DEBUG_MODE; then
    echo -e "${CYAN}⚠ Debug:${NC} Apenas mostrar comandos"
fi
echo ""

# Função para listar volumes
listar_volumes() {
    local servidor=$1
    local docker_cmd=$2
    
    echo -e "${BLUE}Volumes em $servidor:${NC}"
    $docker_cmd volume ls --format "{{.Name}}" | nl -w2 -s'. '
    echo ""
}

# Listar volumes da origem
echo -e "${CYAN}Carregando volumes da origem...${NC}"
VOLUMES_ORIGEM=($($DOCKER_ORIGEM volume ls --format "{{.Name}}"))

if [ ${#VOLUMES_ORIGEM[@]} -eq 0 ]; then
    echo -e "${RED}✗ Nenhum volume encontrado na origem!${NC}"
    exit 1
fi

# Mostrar volumes com índices
echo ""
listar_volumes "$ORIGEM" "$DOCKER_ORIGEM"

# Solicitar seleção
echo -e "${BLUE}Digite os números dos volumes para sincronizar (ex: 1 3 5 ou 'all'):${NC}"
read -r SELECAO

# Processar seleção
if [ "$SELECAO" = "all" ]; then
    VOLUMES_SELECIONADOS=("${VOLUMES_ORIGEM[@]}")
else
    VOLUMES_SELECIONADOS=()
    for num in $SELECAO; do
        idx=$((num - 1))
        if [ $idx -ge 0 ] && [ $idx -lt ${#VOLUMES_ORIGEM[@]} ]; then
            VOLUMES_SELECIONADOS+=("${VOLUMES_ORIGEM[$idx]}")
        else
            echo -e "${YELLOW}⚠ Índice $num ignorado (fora do intervalo)${NC}"
        fi
    done
fi

if [ ${#VOLUMES_SELECIONADOS[@]} -eq 0 ]; then
    echo -e "${RED}✗ Nenhum volume selecionado!${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}Volumes selecionados:${NC}"
printf '%s\n' "${VOLUMES_SELECIONADOS[@]}" | nl -w2 -s'. '
echo ""

# Confirmar
if ! $DEBUG_MODE; then
    echo -e "${YELLOW}Deseja continuar? (s/N):${NC}"
    read -r CONFIRMAR
    if [[ ! "$CONFIRMAR" =~ ^[Ss]$ ]]; then
        echo "Cancelado."
        exit 0
    fi
    echo ""
fi

# Função para obter mountpoint
get_mountpoint() {
    local servidor=$1
    local docker_cmd=$2
    local volume=$3
    
    $docker_cmd volume inspect "$volume" --format '{{.Mountpoint}}' 2>/dev/null || echo ""
}

# Função para executar ou mostrar rsync
sync_volume() {
    local volume=$1
    
    echo -e "${CYAN}─────────────────────────────────────${NC}"
    echo -e "${CYAN}Volume: $volume${NC}"
    echo -e "${CYAN}─────────────────────────────────────${NC}"
    
    # Obter mountpoints
    if [ "$ORIGEM" = "local" ]; then
        MOUNT_ORIGEM=$(get_mountpoint "$ORIGEM" "$DOCKER_ORIGEM" "$volume")
    else
        MOUNT_ORIGEM=$($SSH_ORIGEM "docker volume inspect $volume --format '{{.Mountpoint}}' 2>/dev/null" || echo "")
    fi
    
    if [ "$DESTINO" = "local" ]; then
        MOUNT_DESTINO=$(get_mountpoint "$DESTINO" "$DOCKER_DESTINO" "$volume")
    else
        MOUNT_DESTINO=$($SSH_DESTINO "docker volume inspect $volume --format '{{.Mountpoint}}' 2>/dev/null" || echo "")
    fi
    
    if [ -z "$MOUNT_ORIGEM" ]; then
        echo -e "${RED}✗ Volume não encontrado na origem!${NC}"
        return 1
    fi
    
    # Verificar/criar volume no destino
    if [ -z "$MOUNT_DESTINO" ]; then
        echo -e "${YELLOW}⚠ Volume não existe no destino. Criando...${NC}"
        if $DEBUG_MODE; then
            if [ "$DESTINO" = "local" ]; then
                echo "docker volume create $volume"
            else
                echo "ssh $DESTINO docker volume create $volume"
            fi
        else
            $DOCKER_DESTINO volume create "$volume" > /dev/null
            echo -e "${GREEN}✓ Volume criado no destino${NC}"
            
            # Obter mountpoint novamente
            if [ "$DESTINO" = "local" ]; then
                MOUNT_DESTINO=$(get_mountpoint "$DESTINO" "$DOCKER_DESTINO" "$volume")
            else
                MOUNT_DESTINO=$($SSH_DESTINO "docker volume inspect $volume --format '{{.Mountpoint}}' 2>/dev/null")
            fi
        fi
    fi
    
    # Construir comando rsync
    RSYNC_OPTS="-avz --progress"
    if $DRY_RUN; then
        RSYNC_OPTS="$RSYNC_OPTS --dry-run"
    fi
    
    # Montar comando baseado em origem/destino local ou remoto
    if [ "$ORIGEM" = "local" ] && [ "$DESTINO" = "local" ]; then
        RSYNC_CMD="rsync $RSYNC_OPTS $MOUNT_ORIGEM/ $MOUNT_DESTINO/"
    elif [ "$ORIGEM" = "local" ]; then
        RSYNC_CMD="rsync $RSYNC_OPTS $MOUNT_ORIGEM/ $DESTINO:$MOUNT_DESTINO/"
    elif [ "$DESTINO" = "local" ]; then
        RSYNC_CMD="rsync $RSYNC_OPTS $ORIGEM:$MOUNT_ORIGEM/ $MOUNT_DESTINO/"
    else
        # Ambos remotos - usar SSH tunnel
        RSYNC_CMD="ssh $ORIGEM \"rsync $RSYNC_OPTS $MOUNT_ORIGEM/ $DESTINO:$MOUNT_DESTINO/\""
    fi
    
    echo ""
    echo -e "${BLUE}Origem:${NC}  $MOUNT_ORIGEM"
    echo -e "${BLUE}Destino:${NC} $MOUNT_DESTINO"
    echo ""
    
    if $DEBUG_MODE; then
        echo -e "${YELLOW}Comando rsync:${NC}"
        echo "$RSYNC_CMD"
        echo ""
    else
        if $DRY_RUN; then
            echo -e "${YELLOW}Executando DRY-RUN...${NC}"
        else
            echo -e "${GREEN}Sincronizando...${NC}"
        fi
        echo ""
        
        # Executar rsync
        eval "$RSYNC_CMD"
        
        echo ""
        if $DRY_RUN; then
            echo -e "${YELLOW}✓ DRY-RUN completo (nenhum arquivo foi transferido)${NC}"
        else
            echo -e "${GREEN}✓ Sincronização completa!${NC}"
        fi
    fi
    
    echo ""
}

# Processar cada volume selecionado
for volume in "${VOLUMES_SELECIONADOS[@]}"; do
    sync_volume "$volume"
done

# Resumo final
echo ""
echo -e "${CYAN}======================================${NC}"
echo -e "${GREEN}✓ Processo concluído!${NC}"
echo -e "${CYAN}======================================${NC}"
echo ""
echo -e "Total de volumes processados: ${#VOLUMES_SELECIONADOS[@]}"
if $DRY_RUN; then
    echo -e "${YELLOW}Use --no-dry-run para executar a sincronização real${NC}"
fi
if $DEBUG_MODE; then
    echo -e "${CYAN}Modo debug ativo - apenas comandos foram mostrados${NC}"
fi
echo ""
