#!/bin/bash
#
# Script: Instalador/Atualizador do Google Chrome
# Versão do script: 1.0
# Autor: Nícolas Pastorello
# Data de criação: 23/09/2025
#
# Descrição:
#   Este script automatiza a instalação e atualização do navegador
#   Google Chrome em sistemas baseados em Debian/Ubuntu.
#
#   O funcionamento segue as seguintes etapas:
#     1. Verifica se já existe uma versão instalada do Google Chrome.
#     2. Consulta no repositório oficial do Google qual é a versão mais recente.
#     3. Compara a versão instalada com a disponível:
#          - Se forem iguais → não faz nada.
#          - Se a instalada for mais nova → não faz nada.
#          - Se a instalada for mais antiga ou não existir → baixa e instala.
#     4. Faz o download do pacote .deb diretamente do Google.
#     5. Instala o pacote e corrige dependências se necessário.
#     6. Confirma se a versão final corresponde à mais recente.
#
# Observações:
#   - O script utiliza `wget` para baixar o pacote.
#   - O arquivo .deb é salvo temporariamente em /tmp.
#   - Ao final da execução o arquivo temporário é removido automaticamente.
#   - Necessário rodar como root (ou com sudo) para instalar pacotes.
#

# URL do pacote mais recente (link fixo fornecido pelo Google)
URL="https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"

# Caminho do arquivo temporário
ARQUIVO="/tmp/google-chrome-stable.deb"

# Tempo limite para o download (em segundos)
TIMEOUT=1200

# Função de limpeza automática ao sair do script
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

echo "🔎 Verificando versão instalada do Google Chrome..."
INSTALLED_VERSION=$(dpkg-query -W -f='${Version}' google-chrome-stable 2>/dev/null || true)

echo "🌐 Consultando repositório oficial do Google para obter a versão mais recente..."
LATEST_VERSION=$(wget -qO- https://dl.google.com/linux/chrome/deb/dists/stable/main/binary-amd64/Packages \
    | grep -A 1 "Package: google-chrome-stable" \
    | grep "Version:" \
    | head -n 1 \
    | awk '{print $2}')

# Valida se conseguiu obter a versão mais recente
if [ -z "$LATEST_VERSION" ]; then
    echo "❌ Erro: não foi possível determinar a versão mais recente do Google Chrome."
    exit 1
fi

echo "📦 Versão mais recente disponível: $LATEST_VERSION"

# Se já existe versão instalada, comparar
if [ -n "$INSTALLED_VERSION" ]; then
    echo "💻 Versão instalada atualmente: $INSTALLED_VERSION"

    if dpkg --compare-versions "$INSTALLED_VERSION" eq "$LATEST_VERSION"; then
        echo "✅ A versão $INSTALLED_VERSION já está instalada. Nada a fazer."
        exit 0
    elif dpkg --compare-versions "$INSTALLED_VERSION" gt "$LATEST_VERSION"; then
        echo "ℹ️ A versão instalada ($INSTALLED_VERSION) é mais nova que a disponível ($LATEST_VERSION). Nada a fazer."
        exit 0
    else
        echo "⬆️ A versão instalada ($INSTALLED_VERSION) é mais antiga. Atualizando para $LATEST_VERSION..."
    fi
else
    echo "🆕 Google Chrome não está instalado. Instalando a versão $LATEST_VERSION..."
fi

# Download do pacote
echo "⬇️ Baixando o Google Chrome (tempo limite ${TIMEOUT}s)..."
if ! wget --timeout="$TIMEOUT" --tries=3 --progress=dot:giga -O "$ARQUIVO" "$URL"; then
    echo "❌ Erro ao baixar o Google Chrome. Verifique sua conexão e a URL: $URL"
    exit 1
fi

# Verifica se o arquivo baixado não está vazio ou corrompido
if [ ! -s "$ARQUIVO" ]; then
    echo "❌ Arquivo baixado está vazio ou corrompido: $ARQUIVO"
    exit 1
fi

# Garante que não há lock no dpkg
wait_for_dpkg_lock

# Instalação do pacote
echo "⚙️ Instalando o pacote..."
if ! dpkg -i "$ARQUIVO"; then
    echo "⚠️ dpkg retornou erro ao instalar — tentando corrigir dependências com apt."
fi

# Atualiza lista de pacotes e instala dependências necessárias
apt-get update -y
apt-get install -f -y

# Reconfigura pacotes pendentes (se houver)
dpkg --configure -a || true

# Remove pacotes desnecessários
apt autoremove -y

# Verifica versão final instalada
FINAL_VERSION=$(dpkg-query -W -f='${Version}' google-chrome-stable 2>/dev/null || true)

if [ -n "$FINAL_VERSION" ] && dpkg --compare-versions "$FINAL_VERSION" eq "$LATEST_VERSION"; then
    echo "🎉 Google Chrome $FINAL_VERSION instalado/atualizado com sucesso!"
    exit 0
elif [ -n "$FINAL_VERSION" ]; then
    echo "⚠️ Instalação concluída, mas a versão instalada é $FINAL_VERSION (esperada $LATEST_VERSION)."
    exit 0
else
    echo "❌ Erro: Google Chrome não foi instalado corretamente."
    exit 1
fi
