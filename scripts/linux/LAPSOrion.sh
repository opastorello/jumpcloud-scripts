#!/bin/bash
#
# Script: Criação e Gerenciamento de Usuário de Service Desk
# Versão: 1.2
# Autor: Nícolas Pastorello
# Data: 24/09/2025
#
# Descrição:
#   Cria ou atualiza o usuário sysadm, gera senha aleatória,
#   testa localmente e só envia ao Orion se a senha funcionar.
#

ADMIN_USER="sysadm"
ADMIN_PASSWORD="123456"   # senha inicial só para criação

# Configurações do Vault no Orion
TOKEN_POST="TokenSeguro123"
API_URL="https://site.com.br/api.php"


# Identificação da máquina
HOST=$(hostname)
SERIAL=$(sudo dmidecode -s system-serial-number 2>/dev/null || echo "NULL")

check_api() {
  echo "🔎 Verificando comunicação com o Vault no Orion..."
  code=$(curl -s -o /dev/null -w "%{http_code}" -d "token=$TOKEN_POST" -X POST "$API_URL")
  if [ "$code" = "200" ]; then
    echo "✅ API do Vault no Orion está respondendo."
  else
    echo "❌ Falha ao conectar no Orion (HTTP $code)"
    exit 1
  fi
}

create_user() {
  if id "$ADMIN_USER" &>/dev/null; then
    echo "ℹ️  Usuário $ADMIN_USER já existe."
  else
    if sudo useradd -m "$ADMIN_USER" &>/dev/null; then
      echo "$ADMIN_USER:$ADMIN_PASSWORD" | sudo chpasswd &>/dev/null
      sudo usermod -aG sudo "$ADMIN_USER" &>/dev/null
      echo "✅ Usuário $ADMIN_USER criado com senha inicial."
    else
      echo "❌ Erro ao criar usuário $ADMIN_USER."
      exit 1
    fi
  fi
}

generate_password() {
  tr -dc "A-Za-z0-9-@$%" </dev/urandom | head -c 13
}

set_local_password() {
  local passwd="$1"
  echo "$ADMIN_USER:$passwd" | sudo chpasswd &>/dev/null || {
    echo "❌ Falha ao redefinir senha local do usuário $ADMIN_USER."
    exit 1
  }
  echo "✅ Senha redefinida localmente."
}

test_password() {
  local passwd="$1"
  echo "$passwd" | timeout 5s su - "$ADMIN_USER" -c "id" >/dev/null 2>&1
  return $?
}

send_to_orion() {
  local passwd="$1"
  response=$(curl -s -X POST \
    -d "token=$TOKEN_POST&hostname=$HOST&serial=$SERIAL&chave=$passwd&sistema=3" \
    "$API_URL")

  response_clean=$(echo "$response" | tr -d '\n' | tr -s ' ')

  if echo "$response_clean" | grep -qi "chave atualizada com sucesso"; then
    echo "✅ Senha atualizada no Vault no Orion."
  elif echo "$response_clean" | grep -qi "Nova máquina"; then
    echo "✅ Máquina registrada no Vault no Orion."
  else
    echo "❌ Erro ao atualizar senha no Orion. Resposta: $response_clean"
    exit 1
  fi
}

check_api
create_user

PASSWORD=$(generate_password)
set_local_password "$PASSWORD"

echo "🔎 Testando autenticação com a nova senha..."
if test_password "$PASSWORD"; then
  echo "✅ Autenticação validada. Enviando ao Orion..."
  send_to_orion "$PASSWORD"
else
  echo "❌ Senha não passou no teste de autenticação. Abortando envio ao Orion."
  exit 1
fi

echo "🎉 Script concluído com sucesso!"
exit 0
