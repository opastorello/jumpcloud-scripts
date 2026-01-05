#!/bin/bash
#
# Script: Instalador/Atualizador do FortiClient
# Versão do script: 1.0
# Autor: Nícolas Pastorello
# Data de criação: 23/09/2025
#
# Descrição:
#   Este script automatiza a instalação e atualização do FortiClient
#   em sistemas baseados em Debian/Ubuntu.
#
#   O funcionamento segue as seguintes etapas:
#     1. Verifica se já existe uma versão instalada do FortiClient.
#     2. Compara com a versão alvo definida no script.
#     3. Se já estiver na mesma versão → não faz nada.
#     4. Se a instalada for mais nova → não faz nada.
#     5. Se a instalada for mais antiga ou inexistente → baixa e instala a versão alvo.
#     6. Instala dependências necessárias e valida se a versão final corresponde à desejada.
#
# Observações:
#   - O script utiliza `wget` para baixar o pacote .deb.
#   - O arquivo é salvo em /tmp e removido ao final.
#   - Necessário rodar como root (ou com sudo).
#

# Versão alvo a ser instalada (ajuste se necessário)
TARGET_VERSION="7.4.4.1796"

# URL do pacote FortiClient
URL="https://site.com.br/FortiClientEMS/FortiClient_7.4.4.deb"

# Caminho do arquivo temporário
ARQUIVO="/tmp/FortiClient.deb"

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

echo "🔎 Verificando versão instalada do FortiClient..."
INSTALLED_VERSION=$(dpkg-query -W -f='${Version}' forticlient 2>/dev/null || true)

if [ -n "$INSTALLED_VERSION" ]; then
    echo "💻 Versão instalada encontrada: $INSTALLED_VERSION"
    if dpkg --compare-versions "$INSTALLED_VERSION" eq "$TARGET_VERSION"; then
        echo "✅ A mesma versão ($TARGET_VERSION) já está instalada. Nada a fazer."
        exit 0
    elif dpkg --compare-versions "$INSTALLED_VERSION" gt "$TARGET_VERSION"; then
        echo "ℹ️ A versão instalada ($INSTALLED_VERSION) é mais nova que a alvo ($TARGET_VERSION). Nada a fazer."
        exit 0
    else
        echo "⬆️ A versão instalada ($INSTALLED_VERSION) é mais antiga que a alvo ($TARGET_VERSION). Vou atualizar."
    fi
else
    echo "🆕 FortiClient não está instalado. Vou instalar a versão $TARGET_VERSION."
fi

# Download do pacote
echo "⬇️ Baixando o FortiClient (tempo limite ${TIMEOUT}s)..."
if ! wget --timeout="$TIMEOUT" --tries=3 --progress=dot:giga -O "$ARQUIVO" "$URL"; then
    echo "❌ Erro ao baixar o FortiClient. Verifique sua conexão e a URL: $URL"
    exit 1
fi

# Verifica se o arquivo foi baixado corretamente
if [ ! -s "$ARQUIVO" ]; then
    echo "❌ Arquivo baixado está vazio ou corrompido: $ARQUIVO"
    exit 1
fi

# Garante que não há lock no dpkg
wait_for_dpkg_lock

# Instalação do pacote
echo "⚙️ Instalando o pacote FortiClient..."
if ! dpkg -i "$ARQUIVO"; then
    echo "⚠️ dpkg retornou erro ao instalar — tentando corrigir dependências com apt."
fi

# Atualiza lista de pacotes e corrige dependências
apt-get update -y
apt-get install -f -y

# Reconfigura pacotes pendentes (se houver)
dpkg --configure -a || true

# Verifica versão final instalada
FINAL_VERSION=$(dpkg-query -W -f='${Version}' forticlient 2>/dev/null || true)

if [ -n "$FINAL_VERSION" ] && dpkg --compare-versions "$FINAL_VERSION" eq "$TARGET_VERSION"; then
    echo "🎉 FortiClient $FINAL_VERSION instalado/atualizado com sucesso!"
    exit 0
elif [ -n "$FINAL_VERSION" ]; then
    echo "⚠️ Instalação concluída, mas a versão instalada é $FINAL_VERSION (esperada $TARGET_VERSION)."
    exit 0
else
    echo "❌ Erro: FortiClient não foi instalado corretamente."
    exit 1
fi
