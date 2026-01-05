#!/bin/bash
#
# Script: Instalação e configuração do GLPI Agent
# Versão do script: 1.0
# Autor: Nícolas Pastorello
# Data de criação: 23/09/2025
#
# Descrição:
#   Este script automatiza a instalação do GLPI Agent
#   em sistemas baseados em Debian/Ubuntu.
#
#   Etapas:
#     1. Verifica se já existe uma versão instalada.
#     2. Consulta a última versão disponível no GitHub.
#     3. Compara as versões (instalada vs. disponível).
#     4. Faz download do instalador Perl se necessário.
#     5. Executa a instalação.
#     6. Remove o instalador após uso.
#     7. Força inventário imediato no servidor.
#
# Observações:
#   - Necessário rodar como root (ou com sudo).
#   - O agente será vinculado automaticamente ao servidor especificado.
#

GLPI_SERVER="https://glpi.site.com.br/"
TMP_INSTALLER="/tmp/glpi-agent-installer.pl"

cleanup() {
  rm -f "$TMP_INSTALLER" || true
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

echo "🔎 Verificando versão instalada do GLPI Agent..."
INSTALLED_VERSION=""
if command -v glpi-agent &>/dev/null; then
  INSTALLED_VERSION=$(glpi-agent --version 2>/dev/null | awk '{print $3}' | head -n1)
  # Remove parênteses e caracteres inválidos
  INSTALLED_VERSION=$(echo "$INSTALLED_VERSION" | tr -d '()' | sed 's/[^0-9.:-]//g')
  echo "💻 Versão instalada: $INSTALLED_VERSION"
else
  echo "ℹ️ GLPI Agent não encontrado no sistema."
fi

echo "🌐 Consultando última versão no GitHub..."
LATEST_VERSION=$(curl -s https://api.github.com/repos/glpi-project/glpi-agent/releases/latest \
  | grep -oP '"tag_name":\s*"\K[^"]+')

if [ -z "$LATEST_VERSION" ]; then
  echo "❌ Não foi possível determinar a versão mais recente do GLPI Agent." >&2
  exit 1
fi

echo "📌 Última versão disponível: $LATEST_VERSION"

# Se já está atualizado, sai
if [ -n "$INSTALLED_VERSION" ] && dpkg --compare-versions "$INSTALLED_VERSION" ge "$LATEST_VERSION"; then
  echo "✅ O GLPI Agent já está atualizado para a versão $INSTALLED_VERSION."
  echo "📡 Forçando inventário imediato..."
  if ! glpi-agent --force --server="$GLPI_SERVER"; then
    echo "⚠️ GLPI Agent atualizado, mas falha ao forçar inventário."
  else
    echo "✅ Inventário enviado para o servidor com sucesso."
  fi
  exit 0
fi

echo "⬇️  Baixando instalador do GLPI Agent ($LATEST_VERSION)..."
GLPI_AGENT_URL="https://github.com/glpi-project/glpi-agent/releases/download/${LATEST_VERSION}/glpi-agent-${LATEST_VERSION}-linux-installer.pl"
if ! wget -q "$GLPI_AGENT_URL" -O "$TMP_INSTALLER"; then
  echo "❌ Falha ao baixar o instalador: $GLPI_AGENT_URL" >&2
  exit 1
fi

# Garante que não há lock no dpkg
wait_for_dpkg_lock

echo "⚙️  Instalando GLPI Agent..."
if ! perl "$TMP_INSTALLER" --install -S --service --tag=Linux --server="$GLPI_SERVER"; then
  echo "❌ Falha ao instalar o GLPI Agent." >&2
  exit 1
fi

echo "📡 Forçando inventário imediato..."
if ! glpi-agent --force --server="$GLPI_SERVER"; then
  echo "⚠️ GLPI Agent instalado, mas falha ao forçar inventário inicial."
else
  echo "✅ Inventário enviado para o servidor com sucesso."
fi

echo "🎉 GLPI Agent $LATEST_VERSION instalado/atualizado com sucesso!"
exit 0
