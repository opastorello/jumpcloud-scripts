#!/bin/bash
#
# Script: Remoção Completa do FortiClient
# Versão do script: 1.0
# Autor: Nícolas Pastorello
# Data de criação: 23/09/2025
#
# Descrição:
#   Este script automatiza a desinstalação e remoção completa do FortiClient
#   em sistemas baseados em Debian/Ubuntu.
#
#   O funcionamento segue as seguintes etapas:
#     1. Para serviços e processos relacionados ao FortiClient.
#     2. Remove o pacote forticlient via apt-get/dpkg (com forçamento se necessário).
#     3. Executa limpeza de pacotes não utilizados (autoremove/autoclean).
#     4. Remove diretórios e arquivos residuais comuns do FortiClient
#        localizados em /opt, /etc, /usr, /var, /run, /tmp e diretórios ocultos do usuário (~/.forticlient, ~/.config/forticlient, etc.).
#     5. Exclui atalhos, ícones, entradas de menu e fontes de repositório relacionadas ao FortiClient.
#     6. Recarrega o systemd para refletir as mudanças.
#     7. Realiza uma verificação final garantindo que não restaram pacotes nem resíduos do FortiClient.
#
# Observações:
#   - Necessário rodar como root (ou com sudo).
#   - O script limita a remoção a diretórios do sistema e configurações ocultas do usuário, não apagando documentos pessoais.
#   - Útil para corrigir instalações corrompidas ou remover totalmente o FortiClient do sistema.
#

remove_forticlient_files() {
    echo "➡️ Etapa 4: Removendo arquivos e pastas residuais..."
    for location in \
        "/opt/forticlient" \
        "/etc/forticlient" \
        "/usr/lib/forticlient" \
        "/usr/local/lib/forticlient" \
        "/var/lib/forticlient" \
        "/var/log/forticlient" \
        "/var/opt/forticlient" \
        "/usr/share/forticlient" \
        "/usr/bin/forticlient" \
        "/usr/sbin/forticlient" \
        "/usr/local/bin/forticlient" \
        "$HOME/.forticlient" \
        "$HOME/.config/forticlient" \
        "$HOME/.local/share/forticlient"
    do
        if [ -d "$location" ] || [ -f "$location" ]; then
            echo "   🗑️ Removendo: $location"
            rm -rf "$location"
        fi
    done

    echo "   🔎 Buscando resíduos adicionais..."
    find /opt /etc /usr /var /run /tmp -iname "*forticlient*" 2>/dev/null | while read -r found_item; do
        echo "   🗑️ Removendo: $found_item"
        rm -rf "$found_item"
    done
}

echo "➡️ Etapa 1: Parando serviços e processos..."
systemctl stop forticlient* 2>/dev/null
systemctl disable forticlient* 2>/dev/null
pkill -f forticlient 2>/dev/null

echo "➡️ Etapa 2: Removendo pacote FortiClient..."
if dpkg -l | grep -q forticlient; then
    if ! apt-get remove --purge forticlient -y -qq; then
        echo "⚠️ Erro ao remover com apt-get. Forçando via dpkg..."
        dpkg --remove --force-remove-reinstreq forticlient >/dev/null 2>&1
        dpkg --purge --force-all forticlient >/dev/null 2>&1
    fi
else
    echo "   ℹ️ FortiClient não está instalado como pacote."
fi

echo "➡️ Etapa 3: Limpando pacotes não utilizados..."
apt-get install -f -y -qq
apt-get autoremove -y -qq
apt-get autoclean -y -qq

remove_forticlient_files

echo "➡️ Etapa 5: Removendo atalhos e fontes do sistema..."
rm -f /usr/share/applications/forticlient.desktop
rm -f /usr/share/applications/forticlient-register.desktop
rm -f /usr/share/icons/hicolor/*/apps/forticlient.png
rm -f /etc/apt/sources.list.d/forticlient.list

echo "➡️ Etapa 6: Recarregando systemd..."
systemctl daemon-reload

echo "➡️ Etapa 7: Verificação final..."
if dpkg -l | grep -q forticlient; then
    apt-get purge --auto-remove forticlient -y -qq
    echo "   ⚠️ Pacote forticlient ainda estava presente e foi purgado."
else
    echo "   ✅ Nenhum pacote forticlient instalado."
fi

if ! find /opt /etc /usr /var /run /tmp -iname "*forticlient*" 2>/dev/null | grep -q .; then
    echo "   ✅ Nenhum resíduo encontrado nos diretórios do sistema."
else
    echo "   ⚠️ Ainda restam resíduos no sistema. Verifique manualmente."
fi

echo "🎉 Remoção completa do FortiClient concluída!"
exit 0
