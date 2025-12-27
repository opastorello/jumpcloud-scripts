#!/bin/bash
#
# Script: Instalador/Atualizador do Slack
# Versão do script: 1.0
# Autor: Nícolas Pastorello
# Data de criação: 24/09/2025
#
# Descrição:
#   Este script automatiza a instalação e atualização do Slack
#   em sistemas baseados em Debian/Ubuntu.
#
#   O funcionamento segue as seguintes etapas:
#     1. Verifica se o Slack está instalado via Snap:
#          - Se sim → tenta atualizar com `snap refresh`.
#          - Se atualizado com sucesso → finaliza.
#          - Se falhar → retorna erro.
#          - Se não instalado → não faz nada.
#
#     2. Se não estiver via Snap, verifica se está instalado via pacote .deb:
#          - Obtém a versão instalada com `dpkg-query`.
#
#     3. Consulta o repositório oficial do Slack (packagecloud) e identifica
#        a versão mais recente disponível.
#
#     4. Compara a versão instalada com a mais recente:
#          - Se forem iguais → não faz nada.
#          - Se a instalada for mais nova → não faz nada.
#          - Se a instalada for mais antiga ou não existir → baixa e instala.
#
#     5. Monta dinamicamente a URL oficial do Slack no formato:
#          https://downloads.slack-edge.com/desktop-releases/linux/x64/<VERSÃO>/slack-desktop-<VERSÃO>-amd64.deb
#
#     6. Faz o download do pacote .deb para /tmp.
#
#     7. Aguarda liberação de locks do dpkg/apt, se existirem.
#
#     8. Instala o pacote com `dpkg -i`. Se houver erros de dependência:
#          - Executa `apt-get update`
#          - Executa `apt-get install -f -y`
#
#     9. Reconfigura pacotes pendentes com `dpkg --configure -a`.
#
#    10. Remove pacotes órfãos com `apt autoremove -y`.
#
#    11. Confirma a versão final instalada:
#          - Se igual à mais recente → sucesso 🎉
#          - Se diferente → avisa, mas segue.
#          - Se não instalado → erro.
#
# Observações:
#   - O script cobre tanto instalação via Snap quanto via .deb.
#   - O arquivo temporário é sempre removido ao sair.
#   - Necessário rodar como root (ou com sudo).
#

# Caminho do arquivo temporário
ARQUIVO="/tmp/slack.deb"

# Tempo limite para o download (em segundos)
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

echo "🔎 Verificando instalação via Snap..."
SNAP_VERSION=$(snap list slack 2>/dev/null | awk 'NR==2 {print $2}')

if [ -n "$SNAP_VERSION" ]; then
    echo "📦 Slack instalado via Snap (versão: $SNAP_VERSION)."
    echo "🔄 Tentando atualizar com snap refresh..."
    if snap refresh slack; then
        NEW_SNAP_VERSION=$(snap list slack 2>/dev/null | awk 'NR==2 {print $2}')
        echo "🎉 Slack via Snap atualizado com sucesso (versão: $NEW_SNAP_VERSION)."
        exit 0
    else
        echo "❌ Erro ao atualizar o Slack via Snap."
        exit 1
    fi
else
    echo "⚠️  Slack não está instalado via Snap. Nada a fazer."
fi

echo "🔎 Verificando versão instalada do Slack (.deb)..."
INSTALLED_VERSION=$(dpkg-query -W -f='${Version}' slack-desktop 2>/dev/null || true)

echo "🌐 Consultando repositório oficial do Slack para obter a versão mais recente..."
LATEST_VERSION=$(wget -qO- https://packagecloud.io/slacktechnologies/slack/debian/dists/jessie/main/binary-amd64/Packages \
    | awk '
        $1=="Package:" && $2=="slack-desktop" {in_pkg=1; next}
        $1=="Package:" && $2!="slack-desktop" {in_pkg=0}
        in_pkg && $1=="Version:" {print $2}
    ' \
    | sort -V \
    | tail -n 1)

if [ -z "$LATEST_VERSION" ]; then
    echo "❌ Erro: não foi possível determinar a versão mais recente do Slack."
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
        echo "⬆️ A versão instalada ($INSTALLED_VERSION) é mais antiga. Vou atualizar."
    fi
else
    echo "🆕 Slack não está instalado. Vou instalar a versão $LATEST_VERSION."
fi

# Monta a URL dinamicamente com base na versão
URL="https://downloads.slack-edge.com/desktop-releases/linux/x64/${LATEST_VERSION}/slack-desktop-${LATEST_VERSION}-amd64.deb"
echo "🌍 URL detectada: $URL"

# Download do pacote
echo "⬇️  Baixando o Slack (tempo limite ${TIMEOUT}s)..."
if ! wget --timeout="$TIMEOUT" --tries=3 --progress=dot:giga -O "$ARQUIVO" "$URL"; then
    echo "❌ Erro ao baixar o Slack. Verifique sua conexão ou a URL."
    exit 1
fi

if [ ! -s "$ARQUIVO" ]; then
    echo "❌ Arquivo baixado está vazio ou corrompido: $ARQUIVO"
    exit 1
fi

# Garante que não há lock no dpkg
wait_for_dpkg_lock

# Instalação do pacote
echo "⚙️  Instalando o pacote Slack..."
if ! dpkg -i "$ARQUIVO"; then
    echo "⚠️ dpkg retornou erro ao instalar — tentando corrigir dependências com apt."
fi

# Atualiza lista de pacotes e corrige dependências
apt-get update -y
apt-get install -f -y

# Reconfigura pacotes pendentes
dpkg --configure -a || true

# Remove pacotes desnecessários
apt autoremove -y

# Verifica versão final instalada
FINAL_VERSION=$(dpkg-query -W -f='${Version}' slack-desktop 2>/dev/null || true)

if [ -n "$FINAL_VERSION" ] && dpkg --compare-versions "$FINAL_VERSION" eq "$LATEST_VERSION"; then
    echo "🎉 Slack $FINAL_VERSION instalado/atualizado com sucesso!"
    exit 0
elif [ -n "$FINAL_VERSION" ]; then
    echo "⚠️ Instalação concluída, mas a versão instalada é $FINAL_VERSION (esperada $LATEST_VERSION)."
    exit 0
else
    echo "❌ Erro: Slack não foi instalado corretamente."
    exit 1
fi
