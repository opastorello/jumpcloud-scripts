#!/bin/bash
#
# Script: Verificação e remoção do Docker Desktop
# Versão do script: 1.0
# Autor: Nícolas Pastorello
# Data de criação: 23/09/2025
#
# Descrição:
#   Este script verifica se o Docker Desktop está instalado no sistema.
#   - Se estiver instalado, remove usando dpkg -P.
#   - Se não estiver instalado, informa ao usuário.
#
# Observações:
#   - Necessário rodar como root (ou com sudo) para desinstalar pacotes.
#   - Este script remove apenas o pacote "docker-desktop" sem afetar Docker Engine ou Docker Compose.
#

echo "🔎 Verificando instalação do Docker Desktop..."

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

# Verifica se o pacote docker-desktop está instalado
if dpkg -l | grep -q "^ii\s\+docker-desktop"; then
    echo "📦 O Docker Desktop está instalado. Iniciando desinstalação..."
    
    # Garante que não há lock no dpkg
    wait_for_dpkg_lock

    if dpkg -P docker-desktop; then
        echo "✅ Docker Desktop removido com sucesso."
        
        # Confirma se realmente foi removido
        if dpkg -l | grep -q "^ii\s\+docker-desktop"; then
            echo "⚠️ Atenção: o Docker Desktop ainda aparece listado. Verifique manualmente."
            exit 1
        fi
    else
        echo "❌ Falha ao remover o Docker Desktop."
        exit 1
    fi
else
    echo "ℹ️  O Docker Desktop não está instalado no sistema."
    exit 2
fi

# Remove contexto residual criado pelo Docker Desktop
echo "🧹 Removendo contexto 'desktop-linux'..."
docker context rm desktop-linux >/dev/null 2>&1 && echo "✅ Contexto removido." || echo " ℹ️ Contexto não encontrado."

echo "🎉 Script concluído com sucesso!"
exit 0
