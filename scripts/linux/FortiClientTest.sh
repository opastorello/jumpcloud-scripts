#!/bin/bash
#
# Script: Verificação do FortiClient
# Versão: 1.0
# Autor: Nícolas Pastorello
# Data: 24/09/2025
#
# Descrição:
#   Verifica se o FortiClient está instalado e compara com a versão alvo.
#   Códigos de saída:
#     0 = FortiClient instalado na versão correta
#     1 = FortiClient instalado, mas versão diferente
#     2 = FortiClient não instalado
#     3 = Erro inesperado
#

TARGET_VERSION="7.4.3.1736"

echo "🔎 Verificando instalação do FortiClient..."

# Tenta obter a versão instalada
INSTALLED_VERSION=$(dpkg -l | awk '/forticlient/ && $1=="ii" {print $3}')

if [ -z "$INSTALLED_VERSION" ]; then
    echo "❌ FortiClient NÃO está instalado."
    exit 2
fi

echo "📦 FortiClient instalado. Versão detectada: $INSTALLED_VERSION"

if [ "$INSTALLED_VERSION" = "$TARGET_VERSION" ]; then
    echo "✅ A versão instalada corresponde à versão alvo ($TARGET_VERSION)."
    exit 0
else
    echo "⚠️ A versão instalada ($INSTALLED_VERSION) é diferente da versão alvo ($TARGET_VERSION)."
    exit 1
fi

echo "❌ Erro inesperado."
exit 3
