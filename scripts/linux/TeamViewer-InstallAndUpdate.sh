#!/bin/bash
#
# Script: Instalador/Atualizador do TeamViewer
# Versão do script: 1.0
# Autor: Nícolas Pastorello
# Data de criação: 23/09/2025
#
# Descrição:
#   Este script automatiza a instalação e atualização do TeamViewer
#   em sistemas baseados em Debian/Ubuntu.
#
#   O funcionamento segue as seguintes etapas:
#     1. Verifica se já existe uma versão instalada do TeamViewer.
#     2. Consulta no repositório oficial do TeamViewer todas as versões do pacote "teamviewer".
#     3. Seleciona a versão mais recente (a maior).
#     4. Compara a versão instalada com a disponível:
#          - Se forem iguais → não faz nada.
#          - Se a instalada for mais nova → não faz nada.
#          - Se a instalada for mais antiga ou não existir → baixa e instala.
#     5. Faz o download do pacote .deb oficial.
#     6. Instala o pacote e corrige dependências se necessário.
#     7. Confirma se a versão final corresponde à mais recente.
#
# Observações:
#   - O script utiliza `wget` para baixar o pacote.
#   - O arquivo .deb é salvo temporariamente em /tmp.
#   - Necessário rodar como root (ou com sudo).
#

# URL fixa do pacote .deb (sempre aponta para a última versão)
URL="https://download.teamviewer.com/download/linux/teamviewer_amd64.deb"

# Arquivo temporário
ARQUIVO="/tmp/teamviewer.deb"

# Tempo limite para o download (1200 segundos = 20 minutos)
TIMEOUT=1200

# Função de limpeza automática ao sair
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

echo "🔎 Verificando versão instalada do TeamViewer..."
INSTALLED_VERSION=$(dpkg-query -W -f='${Version}' teamviewer 2>/dev/null || true)

echo "🌐 Consultando repositório oficial do TeamViewer para obter a versão mais recente..."
LATEST_VERSION=$(wget -qO- https://linux.teamviewer.com/deb/dists/stable/main/binary-amd64/Packages \
    | awk '
        $1=="Package:" && $2=="teamviewer" {in_pkg=1; next}
        $1=="Package:" && $2!="teamviewer" {in_pkg=0}
        in_pkg && $1=="Version:" {print $2}
    ' \
    | sort -V \
    | tail -n 1)

if [ -z "$LATEST_VERSION" ]; then
    echo "❌ Erro: não foi possível determinar a versão mais recente do TeamViewer."
    exit 1
fi

echo "📦 Versão mais recente disponível: $LATEST_VERSION"

if [ -n "$INSTALLED_VERSION" ]; then
    echo "💻 Versão instalada encontrada: $INSTALLED_VERSION"
    if dpkg --compare-versions "$INSTALLED_VERSION" eq "$LATEST_VERSION"; then
        echo "✅ A versão $INSTALLED_VERSION já está instalada. Nada a fazer."
        exit 0
    elif dpkg --compare-versions "$INSTALLED_VERSION" gt "$LATEST_VERSION"; then
        echo "ℹ️ A versão instalada ($INSTALLED_VERSION) é mais nova que a disponível ($LATEST_VERSION). Nada a fazer."
        exit 0
    else
        echo "⬆️ A versão instalada ($INSTALLED_VERSION) é mais antiga que a disponível ($LATEST_VERSION). Vou atualizar."
    fi
else
    echo "🆕 TeamViewer não está instalado. Vou instalar a versão $LATEST_VERSION."
fi

# Download do pacote
echo "⬇️ Baixando o TeamViewer (tempo limite ${TIMEOUT}s)..."
if ! wget --timeout="$TIMEOUT" --tries=3 --progress=dot:giga -O "$ARQUIVO" "$URL"; then
    echo "❌ Erro ao baixar o TeamViewer. Verifique sua conexão e a URL: $URL"
    exit 1
fi

if [ ! -s "$ARQUIVO" ]; then
    echo "❌ Arquivo baixado está vazio ou corrompido: $ARQUIVO"
    exit 1
fi

# Garante que não há lock no dpkg
wait_for_dpkg_lock

# Instalação do pacote (forçando aceitar o conf novo do maintainer)
echo "⚙️ Instalando o pacote TeamViewer..."
if ! dpkg -i --force-confnew "$ARQUIVO"; then
    echo "⚠️ dpkg retornou erro ao instalar — tentando corrigir dependências com apt."
fi

# Atualiza lista de pacotes e corrige dependências sem interações
DEBIAN_FRONTEND=noninteractive apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -f -y -o Dpkg::Options::="--force-confnew"

# Reconfigura pacotes pendentes
dpkg --configure -a || true

# Remove pacotes desnecessários
apt autoremove -y

# Verifica versão final instalada
FINAL_VERSION=$(dpkg-query -W -f='${Version}' teamviewer 2>/dev/null || true)

if [ -n "$FINAL_VERSION" ] && dpkg --compare-versions "$FINAL_VERSION" eq "$LATEST_VERSION"; then
    echo "🎉 TeamViewer $FINAL_VERSION instalado/atualizado com sucesso!"
    exit 0
elif [ -n "$FINAL_VERSION" ]; then
    echo "⚠️ Instalação concluída, mas a versão instalada é $FINAL_VERSION (esperada $LATEST_VERSION)."
    exit 0
else
    echo "❌ Erro: TeamViewer não foi instalado corretamente."
    exit 1
fi
