#!/bin/bash
#
# Script: Configuração do NetworkManager para ignorar interfaces Docker
# Versão do script: 1.0
# Autor: Nícolas Pastorello
# Data de criação: 24/09/2025
#
# Descrição:
#   Este script ajusta a configuração do NetworkManager para ignorar
#   as interfaces de rede criadas pelo Docker (`docker0` e `br-*`).
#
#   O funcionamento segue as seguintes etapas:
#     1. Verifica se o arquivo de configuração existe.
#     2. Checa se o bloco de configuração já está presente no arquivo.
#     3. Caso não esteja, adiciona as linhas necessárias e reinicia o serviço.
#     4. Se já existir, apenas informa e finaliza sem reiniciar.
#
# Requisitos:
#   - Executar como root (ou com sudo).
#   - Dependências: systemctl, grep, tee.
#
# Observações:
#   - O conteúdo adicionado será: 
#       [keyfile]
#       unmanaged-devices=interface-name:docker0;interface-name:br-*
#

# Caminho do arquivo de configuração
CONFIG_FILE="/etc/NetworkManager/NetworkManager.conf"

# Bloco esperado
BLOCK="[keyfile]
unmanaged-devices=interface-name:docker0;interface-name:br-*"

echo "🔎 Verificando arquivo de configuração do NetworkManager..."

# Verifica se o arquivo existe
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Erro: Arquivo $CONFIG_FILE não encontrado!"
    exit 1
fi

# Verifica se o bloco já existe (as duas linhas consecutivas)
if grep -A1 "^\[keyfile\]$" "$CONFIG_FILE" | grep -q "unmanaged-devices=interface-name:docker0;interface-name:br-\*"; then
    echo "ℹ️  Configuração já existe em $CONFIG_FILE. Nenhuma alteração necessária."
    exit 0
else
    echo "📝 Adicionando configuração ao $CONFIG_FILE..."
    {
        echo "[keyfile]"
        echo "unmanaged-devices=interface-name:docker0;interface-name:br-*"
    } | sudo tee -a "$CONFIG_FILE" >/dev/null
    if [ $? -eq 0 ]; then
        echo "✅ Configuração adicionada com sucesso."
    else
        echo "❌ Erro ao adicionar configuração ao $CONFIG_FILE."
        exit 1
    fi
fi

echo "🔄 Reiniciando o serviço NetworkManager..."
if sudo systemctl restart NetworkManager; then
    echo "✅ Serviço NetworkManager reiniciado com sucesso."
    exit 0
else
    echo "❌ Erro ao reiniciar o serviço NetworkManager."
    echo "   → Verifique logs com: journalctl -xeu NetworkManager.service"
    exit 1
fi
