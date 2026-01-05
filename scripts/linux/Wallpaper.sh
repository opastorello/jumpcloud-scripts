#!/bin/sh
#
# Script: Definir wallpaper padrão no GNOME
# Versão do script: 1.0
# Autor: Nícolas Pastorello
# Data de criação: 23/09/2025
#
# Descrição:
#   Este script baixa e aplica um wallpaper padrão no ambiente GNOME.
#   Ele funciona tanto quando executado como root quanto como usuário comum.
#
#   O funcionamento segue as seguintes etapas:
#     1. Identifica o usuário ativo em sessão GNOME (via gnome-shell).
#     2. Baixa o wallpaper de uma URL fixa para a pasta do usuário:
#          ~/.local/share/wallpapers/wallpaper.png
#     3. Define o wallpaper para:
#          - Área de trabalho (picture-uri)
#          - Modo escuro (picture-uri-dark)
#          - Tela de bloqueio (org.gnome.desktop.screensaver picture-uri)
#     4. Força um refresh imediato alternando opções de exibição (centered → zoom).
#
# Observações:
#   - Necessário estar em uma sessão GNOME em execução.
#   - Ao rodar como root, detecta automaticamente o usuário GNOME ativo.
#   - Usa `gsettings` via DBus do usuário para aplicar as configurações.
#

# URL do wallpaper padrão
WALLPAPER_URL="https://url.com.br/FundoTelaNovaMarca.png"

# Detecta o usuário GNOME ativo (aquele com gnome-shell rodando)
detect_active_gnome_user() {
  loginctl list-sessions --no-legend 2>/dev/null | while read sid tty user seat; do
    if pgrep -u "$user" -x gnome-shell >/dev/null 2>&1; then
      echo "$sid $user"
      return 0
    fi
  done
}

# Função para aplicar o wallpaper para um usuário específico
apply_wallpaper_for_user() {
  target_user="$1"

  # Descobre o HOME real do usuário
  user_home="$(getent passwd "$target_user" | cut -d: -f6)"
  [ -n "$user_home" ] || { echo "❌ Não foi possível resolver o HOME de $target_user"; exit 1; }

  # Caminho do arquivo de wallpaper
  wp_dir="$user_home/.local/share/wallpapers"
  wp_file="$wp_dir/wallpaper.png"

  echo "📂 Preparando diretório de wallpapers em $wp_dir..."
  mkdir -p "$wp_dir"
  chown -R "$target_user:$target_user" "$wp_dir"

  echo "⬇️  Baixando wallpaper em $wp_file..."
  if ! sudo -u "$target_user" wget -q -O "$wp_file" "$WALLPAPER_URL"; then
    echo "❌ Falha ao baixar wallpaper para $target_user."
    exit 1
  fi

  file_uri="file://$wp_file"

  # Variáveis de sessão DBus do usuário
  uid="$(id -u "$target_user")"
  xrtd="/run/user/$uid"
  dbus_addr="unix:path=$xrtd/bus"
  display=":0"

  echo "🖼️  Aplicando wallpaper no GNOME para usuário '$target_user'..."

  # Define para desktop
  sudo -u "$target_user" env XDG_RUNTIME_DIR="$xrtd" DBUS_SESSION_BUS_ADDRESS="$dbus_addr" DISPLAY="$display" \
    gsettings set org.gnome.desktop.background picture-uri "$file_uri" || true

  # Define para modo escuro
  sudo -u "$target_user" env XDG_RUNTIME_DIR="$xrtd" DBUS_SESSION_BUS_ADDRESS="$dbus_addr" DISPLAY="$display" \
    gsettings set org.gnome.desktop.background picture-uri-dark "$file_uri" || true

  # Define para tela de bloqueio
  sudo -u "$target_user" env XDG_RUNTIME_DIR="$xrtd" DBUS_SESSION_BUS_ADDRESS="$dbus_addr" DISPLAY="$display" \
    gsettings set org.gnome.desktop.screensaver picture-uri "$file_uri" || true

  # Força refresh imediato alternando opções válidas
  sudo -u "$target_user" env XDG_RUNTIME_DIR="$xrtd" DBUS_SESSION_BUS_ADDRESS="$dbus_addr" DISPLAY="$display" \
    gsettings set org.gnome.desktop.background picture-options "centered" || true
  sudo -u "$target_user" env XDG_RUNTIME_DIR="$xrtd" DBUS_SESSION_BUS_ADDRESS="$dbus_addr" DISPLAY="$display" \
    gsettings set org.gnome.desktop.background picture-options "zoom" || true

  echo "✅ Wallpaper aplicado com sucesso para '$target_user': $wp_file"
}

# -------------------- fluxo principal --------------------

if [ "$(id -u)" -eq 0 ]; then
  echo "👀 Procurando usuário GNOME ativo..."
  session_info="$(detect_active_gnome_user || true)"
  if [ -n "$session_info" ]; then
    target_user="$(echo "$session_info" | awk '{print $2}')"
    echo "👤 Usuário GNOME ativo: $target_user"
    apply_wallpaper_for_user "$target_user"
  else
    echo "❌ Não foi possível detectar uma sessão GNOME ativa. Faça login no GNOME e tente novamente."
    exit 1
  fi
else
  if ! pgrep -u "$USER" -x gnome-shell >/dev/null 2>&1; then
    echo "❌ Parece que você não está em uma sessão GNOME. Faça login no GNOME e rode novamente."
    exit 1
  fi
  apply_wallpaper_for_user "$USER"
fi

echo "🎉 Script concluído com sucesso!"
exit 0
