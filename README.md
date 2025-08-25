# Scripts

Uma coleção de scripts úteis para automação de tarefas de desenvolvimento e infraestrutura.

## 📋 Sobre

Este repositório contém diversos scripts para automatizar processos comuns de desenvolvimento, implantação e manutenção de ambientes. Os scripts são organizados por categoria e projetados para serem reutilizáveis e fáceis de usar.

## 🚀 Funcionalidades

### Docker & Containerização
- **Instalação automatizada do Docker**: Scripts para instalar Docker em diferentes distribuições Linux
- **Docker Swarm**: Automação para configuração de clusters Docker Swarm (manager e worker nodes)
- **Configurações otimizadas**: Inclui ajustes de kernel e configurações de sistema recomendadas

### Node.js
- **Verificação de dependências**: Ferramentas para listar e verificar versões de módulos instalados
- **Compatibilidade multiplataforma**: Scripts POSIX compatíveis com diferentes shells

### Portainer
- **Instalação simplificada**: Setup automatizado do Portainer para gerenciamento de containers
- **Templates customizados**: Configurações pré-definidas para stacks comuns
- **Configuração de usuários**: Automação da criação de usuários administrativos

## 💻 Requisitos

- Sistema operacional Linux (Ubuntu, CentOS, RHEL, etc.)
- Permissões de root/sudo para instalação de pacotes
- Acesso à internet para download de dependências
- Git (instalado automaticamente se não disponível)

## 🔧 Como Usar

### Execução Direta
Para executar qualquer script diretamente do repositório:

```bash
curl -sSL https://raw.githubusercontent.com/marcelofmatos/scripts/main/[caminho-do-script] | bash
```

### Clone Local
Para usar localmente:

```bash
git clone https://github.com/marcelofmatos/scripts.git
cd scripts
chmod +x [nome-do-script]
./[nome-do-script]
```

### Variáveis de Ambiente
Muitos scripts suportam personalização através de variáveis de ambiente. Crie um arquivo `.env` no diretório do script ou defina as variáveis antes da execução:

```bash
export VARIAVEL_EXEMPLO="valor"
./script.sh
```

## 🛠️ Personalização

### Configuração via .env
Os scripts verificam automaticamente por arquivos `.env` no diretório atual e carregam as configurações personalizadas.

### Detecção Automática
- **Gerenciador de pacotes**: Detecta automaticamente `apt`, `yum` ou outros gerenciadores
- **Init system**: Identifica `systemctl` ou outros sistemas de inicialização
- **Arquitetura**: Adapta-se automaticamente à arquitetura do sistema

## 📦 Pacotes Instalados

Os scripts instalam automaticamente as dependências necessárias:
- Git
- Python3 e pip
- Docker e Docker Compose
- Ferramentas de sistema (htop, ncdu, rsync, vim)

## 🔒 Segurança

- Scripts verificam permissões antes da execução
- Validação de comandos disponíveis no sistema
- Configurações de segurança recomendadas aplicadas automaticamente
- Uso de HTTPS para todos os downloads

## 🌐 Compatibilidade

### Distribuições Linux Suportadas
- Ubuntu (18.04+)
- CentOS/RHEL (7+)
- Debian (9+)
- Amazon Linux
- Outras distribuições baseadas em apt/yum

### Shells Compatíveis
- Bash
- Zsh
- Dash (sh POSIX)

## 📚 Documentação

Cada script inclui:
- Comentários explicativos no código
- Detecção de erros e mensagens informativas
- Logs de execução para diagnóstico
- Instruções de uso nos cabeçalhos

## 🤝 Contribuindo

Contribuições são bem-vindas! Ao contribuir:

1. Fork o repositório
2. Crie uma branch para sua feature (`git checkout -b feature/nova-funcionalidade`)
3. Faça commit das mudanças (`git commit -am 'Adiciona nova funcionalidade'`)
4. Push para a branch (`git push origin feature/nova-funcionalidade`)
5. Abra um Pull Request

## 📋 Padrões de Código

- Use `#!/bin/bash` para scripts Bash específicos
- Use `#!/bin/sh` para máxima compatibilidade POSIX
- Inclua comentários explicativos
- Teste em múltiplas distribuições quando possível
- Implemente verificação de erros (`set -e`)

## 🔧 Resolução de Problemas

### Problemas Comuns

**Erro de permissão**: Execute com `sudo` ou como root
```bash
sudo ./script.sh
```

**Comando não encontrado**: Certifique-se de que o script tem permissão de execução
```bash
chmod +x script.sh
```

**Falha no download**: Verifique conectividade com a internet e firewall

### Logs e Diagnóstico

Os scripts geram logs informativos durante a execução. Para debug adicional:
```bash
bash -x script.sh  # Execução verbosa
```

## 📞 Suporte

Para suporte, dúvidas ou relatório de bugs:
- Abra uma [Issue no GitHub](https://github.com/marcelofmatos/scripts/issues)
- Descreva o problema incluindo:
  - Distribuição Linux e versão
  - Comando executado
  - Mensagem de erro completa
  - Logs relevantes

## 📄 Licença

Este projeto está sob a licença MIT. Veja o arquivo `LICENSE` para mais detalhes.

## 🔄 Atualizações

O repositório é atualizado regularmente com:
- Correções de bugs
- Suporte para novas distribuições
- Melhorias de performance
- Novos scripts e funcionalidades

Para manter seus scripts atualizados:
```bash
git pull origin main
```

---

**Nota**: Sempre revise scripts antes de executá-los em ambientes de produção. Teste primeiro em ambientes de desenvolvimento.
