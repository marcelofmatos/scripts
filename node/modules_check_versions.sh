#!/bin/sh

# Script para listar versões de todos os módulos em node_modules
# Uso: ./list_versions.sh
# curl https://raw.githubusercontent.com/marcelofmatos/scripts/refs/heads/main/node/modules_check_versions.sh | sh

echo "📦 LISTANDO VERSÕES DOS MÓDULOS INSTALADOS"
echo "=========================================="

# Verificar se node_modules existe
if [ ! -d "node_modules" ]; then
    echo "❌ Pasta node_modules não encontrada!"
    echo "Execute 'yarn install' ou 'npm install' primeiro."
    exit 1
fi

# Contador para estatísticas
total_modules=0
found_versions=0

# Função para extrair versão do package.json
get_version() {
    package_json="$1"
    if [ -f "$package_json" ]; then
        # Extrai a versão usando grep e sed (compatível com sh)
        version=$(grep '"version"' "$package_json" | head -1 | sed 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
        echo "$version"
    else
        echo "N/A"
    fi
}

# Função para verificar se string começa com ponto
starts_with_dot() {
    case "$1" in
        .*) return 0 ;;
        *) return 1 ;;
    esac
}

# Função para verificar se string começa com @
starts_with_at() {
    case "$1" in
        @*) return 0 ;;
        *) return 1 ;;
    esac
}

# Função para verificar se terminal suporta cores
supports_color() {
    [ -t 1 ] && [ "${TERM:-}" != "dumb" ]
}

# Percorrer todos os diretórios em node_modules
if [ -d "node_modules" ]; then
    for module_dir in node_modules/*/; do
        # Verificar se o glob retornou resultados válidos
        [ -d "$module_dir" ] || continue
        
        # Remover trailing slash e prefixo node_modules/
        module_name=$(basename "$module_dir")
        
        # Pular diretórios que começam com . (como .bin)
        if starts_with_dot "$module_name"; then
            continue
        fi
        
        # Verificar se é um módulo com escopo (@nome)
        if starts_with_at "$module_name"; then
            # Processar módulos dentro do escopo
            for scoped_dir in "$module_dir"*/; do
                [ -d "$scoped_dir" ] || continue
                
                scoped_name=$(basename "$scoped_dir")
                full_name="$module_name/$scoped_name"
                
                total_modules=$((total_modules + 1))
                
                # Caminho para o package.json do módulo
                package_json="$scoped_dir/package.json"
                
                # Extrair versão
                version=$(get_version "$package_json")
                
                if [ "$version" != "N/A" ]; then
                    found_versions=$((found_versions + 1))
                    # Formatação com cores se suportado
                    if supports_color; then
                        printf "%-30s \033[32m%s\033[0m\n" "$full_name" "$version"
                    else
                        printf "%-30s %s\n" "$full_name" "$version"
                    fi
                else
                    if supports_color; then
                        printf "%-30s \033[31m%s\033[0m\n" "$full_name" "$version"
                    else
                        printf "%-30s %s\n" "$full_name" "$version"
                    fi
                fi
            done
        else
            # Módulo normal (não scoped)
            total_modules=$((total_modules + 1))
            
            # Caminho para o package.json do módulo
            package_json="$module_dir/package.json"
            
            # Extrair versão
            version=$(get_version "$package_json")
            
            if [ "$version" != "N/A" ]; then
                found_versions=$((found_versions + 1))
                # Formatação com cores se suportado
                if supports_color; then
                    printf "%-30s \033[32m%s\033[0m\n" "$module_name" "$version"
                else
                    printf "%-30s %s\n" "$module_name" "$version"
                fi
            else
                if supports_color; then
                    printf "%-30s \033[31m%s\033[0m\n" "$module_name" "$version"
                else
                    printf "%-30s %s\n" "$module_name" "$version"
                fi
            fi
        fi
    done
fi

echo ""
echo "=========================================="
echo "📊 ESTATÍSTICAS:"
echo "Total de módulos: $total_modules"
echo "Versões encontradas: $found_versions"
echo "Versões não encontradas: $((total_modules - found_versions))"

# Informação sobre compatibilidade
echo ""
echo "ℹ️  Script compatível com sh (POSIX)"
