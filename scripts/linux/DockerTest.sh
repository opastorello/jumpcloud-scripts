#!/bin/bash
#
# Script: Verificação do Docker e Docker Compose
# Versão do script: 2.0
# Autor: Nícolas Pastorello
# Data de criação: 24/09/2025
#
# Descrição:
#   Verifica se Docker Desktop, Docker Engine e Docker Compose estão instalados.
#   Códigos de saída:
#     0 = Docker + Compose instalados
#     1 = Docker Desktop instalado, mas Docker Engine não
#     2 = Docker Engine instalado, mas Docker Compose não
#     3 = Nenhum instalado
#     4 = Erro inesperado
#

echo "🔎 Verificando instalação do Docker Desktop..."
if dpkg -l | grep -q "^ii\s\+docker-desktop"; then
    echo "✅ Docker Desktop instalado."
else
    echo "ℹ️  Docker Desktop NÃO está instalado."
fi

echo "🔎 Verificando instalação do Docker Engine..."
if command -v docker >/dev/null 2>&1; then
    echo "✅ Docker Engine instalado: $(docker --version | awk '{print $3}')"
    docker_ok=1
else
    echo "❌ Docker Engine NÃO está instalado."
    docker_ok=0
fi

echo "🔎 Verificando instalação do Docker Compose..."
if command -v docker-compose >/dev/null 2>&1; then
    echo "✅ Docker Compose instalado: $(docker-compose --version | awk '{print $3}')"
    compose_ok=1
elif docker compose version >/dev/null 2>&1; then
    echo "✅ Docker Compose (plugin) instalado: $(docker compose version --short)"
    compose_ok=1
else
    echo "❌ Docker Compose NÃO está instalado."
    compose_ok=0
fi

# Definição dos códigos de saída
if [ $docker_ok -eq 1 ] && [ $compose_ok -eq 1 ]; then
    exit 0
elif dpkg -l | grep -q "^ii\s\+docker-desktop" && [ $docker_ok -eq 0 ]; then
    exit 1
elif [ $docker_ok -eq 1 ] && [ $compose_ok -eq 0 ]; then
    exit 2
elif [ $docker_ok -eq 0 ] && [ $compose_ok -eq 0 ]; then
    exit 3
else
    exit 4
fi
