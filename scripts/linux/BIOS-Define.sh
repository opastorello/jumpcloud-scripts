#!/bin/bash
#
# Script: Definição de Senha de Setup da BIOS Dell
# Versão do script: 1.0
# Autor: Nícolas Pastorello
# Data de criação: 22/10/2025
#
# Descrição:
#   Este script automatiza a definição da senha de setup (SetupPwd) da BIOS
#   em equipamentos Dell compatíveis, utilizando a ferramenta oficial
#   **Dell Command | Configure (CCTK)**.
#
#   Etapas:
#     1. Verifica se o equipamento é Dell.
#     2. Garante que o Dell Command | Configure esteja instalado.
#     3. Define a senha de setup (SetupPwd) da BIOS.
#     4. Exibe status detalhado de cada operação.
#
# Observações:
#   - Necessário executar como **root** (ou via `sudo`).
#   - A senha ser configurada na BIOS deve ser informada na variável `SENHA_UNICA`.
#   - Compatível com sistemas **Ubuntu/Debian**.
#   - Este script define apenas a senha de **SetupPwd** (senha de setup).
#

URL="https://dl.dell.com/FOLDER12705833M/1/command-configure_5.1.0-6.ubuntu22_amd64.tar.gz"
USER_AGENT="Mozilla/5.0 (X11; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/109.0"
ARQUIVO="/tmp/command-configure.tar.gz"
CCTK_BIN="/opt/dell/dcc/cctk"
SENHA_UNICA="SenhaSegura"  # Senha atual configurada na BIOS

echo "🔎 Validando fabricante..."
if [ -f /sys/class/dmi/id/sys_vendor ]; then
    FABRICANTE=$(cat /sys/class/dmi/id/sys_vendor)
else
    FABRICANTE=$(dmidecode -s system-manufacturer 2>/dev/null || echo "Desconhecido")
fi

if ! echo "$FABRICANTE" | grep -qi "Dell"; then
    echo "❌ Este equipamento não é Dell (fabricante: $FABRICANTE)."
    exit 1
fi
echo "✅ Fabricante confirmado: $FABRICANTE"

echo "🔍 Verificando Dell Command | Configure..."
if [ ! -x "$CCTK_BIN" ] && ! command -v cctk >/dev/null 2>&1; then
    echo "🌐 Baixando Dell Command | Configure..."
    wget -q "$URL" -O "$ARQUIVO" --user-agent="$USER_AGENT" || { echo "❌ Falha ao baixar pacote."; exit 1; }
    echo "⚙️ Instalando Dell Command | Configure..."
    tar -xzf "$ARQUIVO" -C /tmp || { echo "❌ Erro ao extrair."; exit 1; }
    dpkg -i /tmp/*.deb >/dev/null 2>&1 || apt-get install -f -y >/dev/null 2>&1
    [ -x "$CCTK_BIN" ] || CCTK_BIN=$(command -v cctk)
    echo "✅ Dell Command | Configure instalado: $CCTK_BIN"
else
    [ -x "$CCTK_BIN" ] || CCTK_BIN=$(command -v cctk)
    echo "✅ Já instalado: $CCTK_BIN"
fi

echo "🔐 Definindo senha de setup na BIOS..."
OUT=$("$CCTK_BIN" --SetupPwd="$SENHA_UNICA" 2>&1)

if echo "$OUT" | grep -qi "password is set successfully."; then
    echo "✅ Senha de setup definida com sucesso."
elif echo "$OUT" | grep -qi "password must be provided"; then
    echo "ℹ️ Senha de setup já está configurada."
else
    echo "❌ Falha ao definir senha de setup."
    echo "   Saída: $OUT"
    exit 1
fi

echo "🏁 Processo concluído."
exit 0
