#!/bin/bash
#
# Script: Desconexão de VPNs
# Versão do script: 1.2
# Autor: Nícolas Pastorello
# Data de criação: 24/09/2025
#
# Descrição:
#   Este script localiza todas as conexões de rede cadastradas no NetworkManager
#   que sejam do tipo VPN (vpn/tun) e desconecta apenas as que estão ativas.
#
#   O funcionamento segue as seguintes etapas:
#     1. Lista todas as conexões do tipo vpn ou tun.
#     2. Filtra somente as que estão ativas (DEVICE != "--").
#     3. Executa a desconexão de cada uma encontrada.
#
# Requisitos:
#   - Executar como root (ou com sudo).
#   - Dependências: nmcli, awk, grep.
#

echo "🔎 Buscando conexões VPN ativas..."

# Pega conexões cujo tipo seja vpn ou tun e que estejam ativas
VPN_CONNECTIONS=$(nmcli -t -f NAME,TYPE,DEVICE con show --active | grep -E "vpn|tun" | awk -F: '{print $1}')

if [ -z "$VPN_CONNECTIONS" ]; then
    echo "ℹ️  Nenhuma conexão VPN ativa encontrada."
    exit 0
fi

# Loop para desconectar cada conexão VPN ativa
for vpn in $VPN_CONNECTIONS; do
    echo "🔌 Desconectando VPN: $vpn..."
    if nmcli con down "$vpn" >/dev/null 2>&1; then
        echo "✅ Conexão VPN '$vpn' desconectada com sucesso."
    else
        echo "❌ Falha ao desconectar VPN: $vpn"
    fi
done
