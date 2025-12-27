#!/bin/bash
#
# Script: Reparação do Ubuntu Desktop
# Versão do script: 1.0
# Autor: Nícolas Pastorello
# Data de criação: 23/09/2025
#
# Descrição:
#   Este script automatiza a instalação e configuração inicial do
#   ambiente gráfico Ubuntu Desktop, além de garantir que o Python3
#   esteja instalado no sistema.
#
#   Etapas:
#     1. Corrige pacotes quebrados e pendentes.
#     2. Instala o metapacote ubuntu-desktop.
#     3. Instala o Python3.
#     4. Ativa e inicia o serviço de desktop (gdm3/lightdm).
#
# Observações:
#   - Necessário rodar como root (ou com sudo).
#   - Reiniciar o ambiente gráfico pode encerrar sessões ativas do usuário.
#

echo "🔧 Corrigindo pacotes pendentes..."
dpkg --configure -a
apt-get install -f -y

echo "⬇️ Instalando o Ubuntu Desktop..."
apt-get install ubuntu-desktop -y

echo "⬇️ Instalando o Python3..."
apt-get install python3 -y

# Detecta qual display manager está instalado
if systemctl list-unit-files | grep -q "^gdm3.service"; then
    DM_SERVICE="gdm3"
elif systemctl list-unit-files | grep -q "^lightdm.service"; then
    DM_SERVICE="lightdm"
else
    DM_SERVICE="gdm3" # fallback padrão
fi

echo "🔄 Iniciando e ativando o serviço $DM_SERVICE..."
systemctl start "$DM_SERVICE"
systemctl enable "$DM_SERVICE"

echo "✅ Ambiente Ubuntu Desktop configurado com sucesso."
exit 0
