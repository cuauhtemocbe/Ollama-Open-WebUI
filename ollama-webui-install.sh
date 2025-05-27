#!/bin/bash

# 🚀 Instalación de Ollama + Open WebUI con Docker

set -e

echo "🔍 Verificando si Docker está instalado..."
if ! command -v docker &> /dev/null
then
    echo "🧱 Instalando Docker..."
    sudo apt update
    sudo apt install -y docker.io
    sudo systemctl enable docker
    sudo usermod -aG docker $USER
    echo "✅ Docker instalado. Reinicia tu sesión para aplicar cambios de grupo."
fi

echo "📁 Creando carpeta de proyecto: ~/ollama-webui"
mkdir -p ~/ollama-webui
cd ~/ollama-webui

echo "🐳 Iniciando servicio de Ollama..."
docker run -d \
  --name ollama \
  -v ollama:/root/.ollama \
  -p 11434:11434 \
  --restart always \
  ollama/ollama

echo "🌐 Iniciando Open WebUI conectado a Ollama..."
docker run -d -p 3000:8080 \
  --add-host=host.docker.internal:host-gateway \
  -v open-webui:/app/backend/data \
  --name open-webui \
  --restart always \
  ghcr.io/open-webui/open-webui:main

echo "✅ Todo listo. Abre tu navegador y ve a http://localhost:3000"
echo "👤 En tu primer acceso, crea una cuenta para usar el chat."
echo "🧠 Puedes iniciar modelos en la terminal con: ollama run llama2"
