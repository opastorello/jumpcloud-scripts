#!/bin/bash
#
# Script: Instalador do Visual Studio Code
# Versão do script: 1.0
# Autor: Nícolas Pastorello
# Data de criação: 26/09/2025
#
# Descrição:
#   Este script automatiza a instalação do Visual Studio Code
#   em sistemas baseados em Debian/Ubuntu.
#
#   Funcionamento:
#     1. Verifica se já existe uma versão instalada do VSCode.
#     2. Se existir, informa e finaliza.
#     3. Se não existir, baixa o pacote .deb oficial e instala.
#     4. Valida se a instalação foi concluída com sucesso.
#
# Observações:
#   - Utiliza `wget` para baixar o pacote.
#   - O arquivo .deb é salvo em /tmp.
#   - Necessário rodar como root (ou com sudo).
#

# URL fixa do pacote .deb (sempre aponta para a última versão estável)
URL="https://update.code.visualstudio.com/latest/linux-deb-x64/stable"

# Arquivo temporário
ARQUIVO="/tmp/vscode_latest_amd64.deb"

# Tempo limite para o download
TIMEOUT=1200

# Função de limpeza automática
cleanup() {
    rm -f "$ARQUIVO" || true
}
trap cleanup EXIT

# Função para aguardar liberação do lock do dpkg/apt
wait_for_dpkg_lock() {
    while pgrep -x "apt" >/dev/null || pgrep -x "dpkg" >/dev/null; do
        echo "⏳ Outro processo apt/dpkg está em execução. Aguardando liberação..."
        sleep 5
    done

    for lock in /var/lib/dpkg/lock /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock /var/cache/apt/archives/lock; do
        while fuser "$lock" >/dev/null 2>&1; do
            echo "⏳ O lock do dpkg/apt está ativo em $lock. Aguardando liberação..."
            sleep 5
        done
    done
}

echo "🔎 Verificando versão instalada do VSCode..."
INSTALLED_VERSION=$(dpkg-query -W -f='${Version}' code 2>/dev/null || true)

if [ -n "$INSTALLED_VERSION" ]; then
    echo "✅ O VSCode já está instalado (versão $INSTALLED_VERSION). Nada a fazer."
    exit 0
else
    echo "🆕 VSCode não está instalado. Vou instalar."
fi

# Download do pacote
echo "⬇️  Baixando o VSCode (tempo limite ${TIMEOUT}s)..."
if ! wget --timeout="$TIMEOUT" --tries=3 --progress=dot:giga -O "$ARQUIVO" "$URL"; then
    echo "❌ Erro ao baixar o VSCode. Verifique sua conexão e a URL: $URL"
    exit 1
fi

if [ ! -s "$ARQUIVO" ]; then
    echo "❌ Arquivo baixado está vazio ou corrompido: $ARQUIVO"
    exit 1
fi

# Garante que não há lock no dpkg
wait_for_dpkg_lock

# Instalação
echo "⚙️ Instalando o pacote VSCode..."
if ! dpkg -i --force-confnew "$ARQUIVO"; then
    echo "⚠️ dpkg retornou erro ao instalar — tentando corrigir dependências com apt."
    apt-get install -f -y
fi

# Reconfigura pacotes pendentes
dpkg --configure -a || true

# Verifica instalação final
FINAL_VERSION=$(dpkg-query -W -f='${Version}' code 2>/dev/null || true)

if [ -n "$FINAL_VERSION" ]; then
    echo "🎉 VSCode $FINAL_VERSION instalado com sucesso!"
    exit 0
else
    echo "❌ Erro: VSCode não foi instalado corretamente."
    exit 1
fi
