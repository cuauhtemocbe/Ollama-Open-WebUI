# 🧠 Ollama + Open WebUI

Este repositorio instala automáticamente Ollama y Open WebUI usando Docker.  
Te permite ejecutar modelos de lenguaje de forma local con una interfaz web tipo ChatGPT.

## 🚀 Instalación rápida

1. Guarda el archivo de instalación
wget https://raw.githubusercontent.com/tu_usuario/tu_repositorio/main/ollama-webui-install.sh

2. Dale permisos de ejecución

`chmod +x ollama-webui-install.sh`

3. Ejecuta el instalador

`./ollama-webui-install.sh`

## Sobre el script:
1. Verifica e instala Docker si no está instalado.
2. Crea los contenedores ollama y open-webui.
3. Expone Open WebUI en http://localhost:3000

## ✅ Cómo usarlo

1. Abre tu navegador y entra a:

`http://localhost:3000`
2. Crea una cuenta en la interfaz y comienza a chatear con modelos locales
3. Puedes gestionar modelos desde la terminal (ver ejemplos abajo)

## 🐳 Comandos útiles con Docker

- Entrar al contenedor de Ollama

`docker exec -it ollama /bin/bash`

- Detener los contenedores

`docker stop ollama open-webui`

- Eliminar los contenedores

`docker rm -f ollama open-webui`

## 🤖 Instalar modelos en Ollama

### LLaMA 3
`ollama pull llama3`

### DeepSeek Coder
`ollama pull deepseek-coder`

### DeepSeek LLM
`ollama pull deepseek-llm`

### Ejecutar un modelo
`ollama run llama3`

## 📂 Estructura del repositorio
```
.
├── ollama-webui-install.sh     # Script de instalación
└── README.md                   # Instrucciones de uso
```
