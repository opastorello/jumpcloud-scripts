#!/bin/bash
#
# Script: Verificação e desativação do Wayland no GDM3
# Versão do script: 1.0
# Autor: Nícolas Pastorello
# Data de criação: 23/09/2025
#
# Descrição:
#   Este script desativa o Wayland no GDM3 em sistemas Debian/Ubuntu.
#   O Wayland é um protocolo gráfico mais moderno que substitui o X11 em algumas distribuições Linux, porém alguns aplicativos (como o TeamViewer) não funcionam corretamente com ele.
#
#   Etapas:
#     1. Verifica se o arquivo de configuração existe.
#     2. Confere se o Wayland já está desativado.
#     3. Se não estiver, aplica "WaylandEnable=false".
#     4. Reinicia o serviço gdm3 (isso reinicia a sessão gráfica do usuário).
#
# Observações:
#   - Necessário rodar como root (ou com sudo).
#   - Reiniciar o gdm3 encerra a sessão gráfica atual, derrubando programas abertos.
#   - Relevante para apps como TeamViewer, que não funcionam bem com Wayland ativo.
#

# Caminho do arquivo de configuração
CONF_FILE="/etc/gdm3/custom.conf"

# Linha que desabilita o Wayland
WAYLAND_LINE="WaylandEnable=false"

# Verificar se o arquivo existe
if [ ! -f "$CONF_FILE" ]; then
    echo "❌ Erro: arquivo $CONF_FILE não encontrado."
    exit 1
fi

# Verificar se já está desativado
if grep -q "^\s*${WAYLAND_LINE}" "$CONF_FILE"; then
    echo "✅ Wayland já está desativado em $CONF_FILE. Nada a fazer."
    exit 0
fi

# Forçar a configuração no arquivo (mesmo que a linha não exista)
if grep -q "^#\s*${WAYLAND_LINE}" "$CONF_FILE"; then
    # Apenas descomentar se estiver comentada
    sed -i "s/^#\s*${WAYLAND_LINE}/${WAYLAND_LINE}/" "$CONF_FILE"
else
    # Garante que a linha esteja presente no arquivo
    echo "$WAYLAND_LINE" >> "$CONF_FILE"
fi

echo "✅ Linha '$WAYLAND_LINE' aplicada em $CONF_FILE."

# Reiniciar o serviço gdm3
echo "🔄 Reiniciando o serviço gdm3..."
if systemctl restart gdm3; then
    echo "✅ Serviço gdm3 reiniciado com sucesso."
    echo "📌 Wayland foi desabilitado em $CONF_FILE."
else
    echo "❌ Erro ao reiniciar o serviço gdm3."
    exit 1
fi

echo "🎉 Script concluído com sucesso!"
exit 0
