<#
  Despliegue de Open WebUI en Windows (sin Ollama)
  Guarda como: instalar_openwebui_sin_ollama.ps1
  Ejecución:
    - Abre PowerShell (idealmente como administrador si necesita instalar Docker).
    - Ejecuta: .\install_openwebui.ps1
#>

[CmdletBinding()]
param(
  [string]$ProjectDir = "$HOME\ollama-webui",
  [string]$ContainerName = "open-webui",
  [string]$Image = "ghcr.io/open-webui/open-webui:main"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Info($m){ Write-Host $m -ForegroundColor Cyan }
function Ok($m){ Write-Host $m -ForegroundColor Green }
function Warn($m){ Write-Host $m -ForegroundColor Yellow }
function Err($m){ Write-Host $m -ForegroundColor Red }

# 1) Verificar/instalar Docker Desktop (no instala Ollama)
Info "🔍 Verificando si Docker está instalado..."
$dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
if (-not $dockerCmd) {
  if (Get-Command winget -ErrorAction SilentlyContinue) {
    Info "🧱 Instalando Docker Desktop con winget..."
    try {
      winget install -e --id Docker.DockerDesktop --accept-source-agreements --accept-package-agreements --source winget
      Ok "✅ Docker Desktop instalado (puede requerir reiniciar/cerrar sesión)."
    } catch {
      Err "❌ No se pudo instalar Docker Desktop automáticamente."
      Write-Host "Instálalo manualmente: https://www.docker.com/products/docker-desktop/" -ForegroundColor Yellow
      exit 1
    }
  } else {
    Err "❌ 'winget' no está disponible y Docker no está instalado."
    Write-Host "Instala Docker Desktop manualmente: https://www.docker.com/products/docker-desktop/" -ForegroundColor Yellow
    exit 1
  }
} else {
  Ok "✅ Docker ya está instalado."
}

# 2) Iniciar Docker Desktop si no está corriendo
$dockerExe = Join-Path $Env:ProgramFiles "Docker\Docker\Docker Desktop.exe"
if (Test-Path $dockerExe) {
  $running = Get-Process -Name "Docker Desktop" -ErrorAction SilentlyContinue
  if (-not $running) {
    Info "▶️ Iniciando Docker Desktop..."
    Start-Process -FilePath $dockerExe | Out-Null
  }
}

# 3) Esperar a que el daemon de Docker esté listo
Info "⏳ Esperando a que Docker inicie..."
$deadline = (Get-Date).AddMinutes(5)
$ready = $false
do {
  Start-Sleep -Seconds 3
  try { & docker info *> $null; if ($LASTEXITCODE -eq 0) { $ready = $true } } catch { }
} until ($ready -or (Get-Date) -gt $deadline)

if (-not $ready) {
  Err "❌ Docker no se inicializó a tiempo. Abre Docker Desktop y reintenta."
  exit 1
}
Ok "✅ Docker está listo."

# 4) Preparar carpeta del proyecto
Info "📁 Creando carpeta de proyecto: $ProjectDir"
New-Item -ItemType Directory -Path $ProjectDir -Force | Out-Null
Set-Location $ProjectDir

# 5) Desplegar solo Open WebUI (sin contenedor de Ollama)
Info "🐳 Descargando imagen de Open WebUI..."
docker pull $Image | Out-Null

# Eliminar contenedor previo si existe
$exists = (& docker ps -a --format "{{.Names}}") | Where-Object { $_ -eq $ContainerName }
if ($exists) {
  Info "🧹 Eliminando contenedor existente '$ContainerName'..."
  docker rm -f $ContainerName | Out-Null
}

Info "🌐 Iniciando Open WebUI (sin Ollama)..."
docker run -d `
  --name $ContainerName `
  --restart always `
  -p 3000:8080 `
  -v open-webui:/app/backend/data `
  $Image | Out-Null

Ok "✅ Open WebUI está en marcha."
Write-Host "🔗 Abre: http://localhost:3000" -ForegroundColor Cyan
Write-Host "⚙️ Configura la conexión a tu proveedor (OpenAI, Azure OpenAI, etc.) desde Settings > Connections dentro de la WebUI."
