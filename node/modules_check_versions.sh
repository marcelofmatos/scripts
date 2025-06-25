#!/bin/bash

# Script para listar versões de todos os módulos em node_modules
# Uso: ./list_versions.sh

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
    local package_json="$1"
    if [ -f "$package_json" ]; then
        # Extrai a versão usando grep e sed
        version=$(grep '"version"' "$package_json" | head -1 | sed 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
        echo "$version"
    else
        echo "N/A"
    fi
}

# Percorrer todos os diretórios em node_modules
for module_dir in node_modules/*/; do
    # Remover trailing slash e prefixo node_modules/
    module_name=$(basename "$module_dir")
    
    # Pular diretórios que começam com . (como .bin)
    if [[ "$module_name" == .* ]]; then
        continue
    fi
    
    total_modules=$((total_modules + 1))
    
    # Caminho para o package.json do módulo
    package_json="$module_dir/package.json"
    
    # Extrair versão
    version=$(get_version "$package_json")
    
    if [ "$version" != "N/A" ]; then
        found_versions=$((found_versions + 1))
        # Formatação colorida (se o terminal suportar)
        if [ -t 1 ]; then
            printf "%-30s \033[32m%s\033[0m\n" "$module_name" "$version"
        else
            printf "%-30s %s\n" "$module_name" "$version"
        fi
    else
        printf "%-30s \033[31m%s\033[0m\n" "$module_name" "$version"
    fi
done

# Verificar também módulos com escopo (@nome/pacote)
for scope_dir in node_modules/@*/; do
    if [ -d "$scope_dir" ]; then
        scope_name=$(basename "$scope_dir")
        for module_dir in "$scope_dir"*/; do
            if [ -d "$module_dir" ]; then
                module_name="$scope_name/$(basename "$module_dir")"
                total_modules=$((total_modules + 1))
                
                package_json="$module_dir/package.json"
                version=$(get_version "$package_json")
                
                if [ "$version" != "N/A" ]; then
                    found_versions=$((found_versions + 1))
                    if [ -t 1 ]; then
                        printf "%-30s \033[32m%s\033[0m\n" "$module_name" "$version"
                    else
                        printf "%-30s %s\n" "$module_name" "$version"
                    fi
                else
                    printf "%-30s \033[31m%s\033[0m\n" "$module_name" "$version"
                fi
            fi
        done
    fi
done

echo ""
echo "=========================================="
echo "📊 ESTATÍSTICAS:"
echo "Total de módulos: $total_modules"
echo "Versões encontradas: $found_versions"
echo "Versões não encontradas: $((total_modules - found_versions))"
