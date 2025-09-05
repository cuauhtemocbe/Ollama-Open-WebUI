<#
  Instalacion de Open WebUI en Windows (sin Ollama)
  Guardar como: install_openwebui
  Recomendado: guardar en codificacion UTF-8 con BOM o ASCII para evitar problemas de caracteres.

  Ejecucion:
    - Abrir PowerShell (si va a instalar Docker Desktop, mejor como Administrador).
    - Si la ejecucion de scripts esta bloqueada:
        powershell -ExecutionPolicy Bypass -File .\instalar_openwebui_sin_ollama.ps1
    - Ejecutar:
        .\install_openwebui.ps1
#>

[CmdletBinding()]
param(
  [string]$ProjectDir = "$HOME\ollama-webui",
  [string]$ContainerName = "open-webui",
  [string]$Image = "ghcr.io/open-webui/open-webui:main"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Forzar codificacion de consola a UTF-8 para evitar caracteres extraños en salida
try {
  [Console]::InputEncoding  = [System.Text.Encoding]::UTF8
  [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
} catch { }

function Info($m){ Write-Host $m -ForegroundColor Cyan }
function Ok($m){ Write-Host $m -ForegroundColor Green }
function Warn($m){ Write-Host $m -ForegroundColor Yellow }
function Err($m){ Write-Host $m -ForegroundColor Red }

# 1) Verificar / instalar Docker Desktop (no instala Ollama)
Info "Verificando si Docker esta instalado..."
$dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
if (-not $dockerCmd) {
  if (Get-Command winget -ErrorAction SilentlyContinue) {
    Info "Instalando Docker Desktop con winget..."
    try {
      winget install -e --id Docker.DockerDesktop --accept-source-agreements --accept-package-agreements --source winget
      Ok "Docker Desktop instalado (puede requerir reiniciar o cerrar sesion)."
    } catch {
      Err "No se pudo instalar Docker Desktop automaticamente."
      Write-Host "Instalacion manual: https://www.docker.com/products/docker-desktop/" -ForegroundColor Yellow
      exit 1
    }
  } else {
    Err "winget no esta disponible y Docker no esta instalado."
    Write-Host "Instala Docker Desktop manualmente: https://www.docker.com/products/docker-desktop/" -ForegroundColor Yellow
    exit 1
  }
} else {
  Ok "Docker ya esta instalado."
}

# 2) Iniciar Docker Desktop si no esta corriendo
$dockerExe = Join-Path $Env:ProgramFiles "Docker\Docker\Docker Desktop.exe"
if (Test-Path $dockerExe) {
  $running = Get-Process -Name "Docker Desktop" -ErrorAction SilentlyContinue
  if (-not $running) {
    Info "Iniciando Docker Desktop..."
    Start-Process -FilePath $dockerExe | Out-Null
  }
}

# 3) Esperar a que el daemon de Docker este listo
Info "Esperando a que Docker inicie..."
$deadline = (Get-Date).AddMinutes(5)
$ready = $false
do {
  Start-Sleep -Seconds 3
  try {
    & docker info *> $null
    if ($LASTEXITCODE -eq 0) { $ready = $true }
  } catch { }
} until ($ready -or (Get-Date) -gt $deadline)

if (-not $ready) {
  Err "Docker no se inicializo a tiempo. Abre Docker Desktop y reintenta."
  exit 1
}
Ok "Docker esta listo."

# 4) Preparar carpeta del proyecto
Info "Creando carpeta de proyecto: $ProjectDir"
New-Item -ItemType Directory -Path $ProjectDir -Force | Out-Null
Set-Location $ProjectDir

# 5) Desplegar solo Open WebUI (sin contenedor de Ollama)
Info "Descargando imagen de Open WebUI..."
docker pull $Image | Out-Null

# Eliminar contenedor previo si existe
$exists = (& docker ps -a --format "{{.Names}}") | Where-Object { $_ -eq $ContainerName }
if ($exists) {
  Info "Eliminando contenedor existente '$ContainerName'..."
  docker rm -f $ContainerName | Out-Null
}

Info "Iniciando Open WebUI (sin Ollama)..."
docker run -d `
  --name $ContainerName `
  --restart always `
  -p 3000:8080 `
  -v open-webui:/app/backend/data `
  $Image | Out-Null

Ok "Open WebUI esta en marcha."
Write-Host "Abrir en el navegador: http://localhost:3000" -ForegroundColor Cyan
Write-Host "Configure su proveedor (OpenAI, Azure OpenAI, etc.) en Settings > Connections dentro de la WebUI." -ForegroundColor Yellow
