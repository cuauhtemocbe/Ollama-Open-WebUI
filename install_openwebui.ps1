<#
  Despliegue de Open WebUI en Windows (sin Ollama)
  Guarda como: instalar_openwebui_sin_ollama.ps1
  Ejecución:
    - Abre PowerShell (idealmente como Administrador si necesitas instalar Docker).
    - Ejecuta: .\instalar_openwebui_sin_ollama.ps1
#>

[CmdletBinding()]
param(
  [string]$ProjectDir = "$HOME\openwebui",
  [string]$ContainerName = "open-webui",
  [string]$ImageRepo = "ghcr.io/open-webui/open-webui",
  [string]$ImageTag = "main",
  [ValidateSet('volume','bind')] [string]$PersistMode = "volume",
  [int]$HostPort = 3000,
  [switch]$Cleanup # elimina volumen/dir previos además del contenedor
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Info($m){ Write-Host $m -ForegroundColor Cyan }
function Ok($m){ Write-Host $m -ForegroundColor Green }
function Warn($m){ Write-Host $m -ForegroundColor Yellow }
function Err($m){ Write-Host $m -ForegroundColor Red }

function Test-Admin {
  $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
  $p = New-Object System.Security.Principal.WindowsPrincipal($id)
  return $p.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

# 1) Verificar/instalar Docker Desktop (no instala Ollama)
Info "🔍 Verificando Docker..."
$dockerCmd = Get-Command docker -ErrorAction SilentlyContinue

if (-not $dockerCmd) {
  if (-not (Test-Admin)) {
    Err "❌ Docker Desktop no está instalado y la instalación automática requiere PowerShell como Administrador."
    Write-Host "Abre PowerShell como Administrador o instala manualmente: https://www.docker.com/products/docker-desktop/" -ForegroundColor Yellow
    exit 1
  }
  if (Get-Command winget -ErrorAction SilentlyContinue) {
    Info "🧱 Instalando Docker Desktop con winget..."
    try {
      winget install -e --id Docker.DockerDesktop --accept-source-agreements --accept-package-agreements --source winget
      Ok "✅ Docker Desktop instalado. Puede requerir reiniciar o cerrar sesión."
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
$dockerExeCandidates = @(
  (Join-Path $Env:ProgramFiles "Docker\Docker\Docker Desktop.exe"),
  (Join-Path ${Env:ProgramFiles(x86)} "Docker\Docker\Docker Desktop.exe")
) | Where-Object { $_ -and (Test-Path $_) }

$backendRunning = Get-Process -Name "com.docker.backend" -ErrorAction SilentlyContinue
if (-not $backendRunning -and $dockerExeCandidates.Count -gt 0) {
  Info "▶️ Iniciando Docker Desktop..."
  Start-Process -FilePath $dockerExeCandidates[0] | Out-Null
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

# 4) Preparar carpeta del proyecto (si corresponde)
if ($PersistMode -eq 'bind') {
  Info "📁 Preparando carpeta del proyecto: $ProjectDir"
  New-Item -ItemType Directory -Path $ProjectDir -Force | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $ProjectDir "data") -Force | Out-Null
}

# 5) Validar puerto
function Test-PortFree([int]$port){
  $inUse = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
  return -not $inUse
}
if (-not (Test-PortFree $HostPort)) {
  Err "❌ El puerto $HostPort ya está en uso. Pasa otro valor con -HostPort."
  exit 1
}

# 6) Descargar imagen (siempre la última) y recrear contenedor
$Image = "$ImageRepo`:$ImageTag"
Info "🐳 Descargando imagen $Image..."
docker pull --quiet $Image | Out-Null

# Eliminar contenedor previo si existe
$exists = (& docker ps -a --format "{{.Names}}") | Where-Object { $_ -eq $ContainerName }
if ($exists) {
  Info "🧹 Eliminando contenedor existente '$ContainerName'..."
  docker rm -f $ContainerName | Out-Null
}

# Limpieza de volumen/carpeta si lo pides
if ($Cleanup) {
  if ($PersistMode -eq 'volume') {
    $vol = "open-webui"
    if ((docker volume ls -q | Where-Object { $_ -eq $vol })) {
      Info "🗑️ Eliminando volumen '$vol'..."
      docker volume rm $vol | Out-Null
    }
  } else {
    $dataDir = Join-Path $ProjectDir "data"
    if (Test-Path $dataDir) {
      Info "🗑️ Limpiando carpeta de datos '$dataDir'..."
      Remove-Item -Recurse -Force $dataDir
      New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
    }
  }
}

# 7) Ejecutar contenedor
Info "🌐 Iniciando Open WebUI (sin Ollama)..."

# Construir flags de persistencia
$persistFlag = if ($PersistMode -eq 'volume') {
  "-v open-webui:/app/backend/data"
} else {
  # Docker en Windows acepta rutas estilo C:\path
  $bindPath = (Join-Path $ProjectDir "data")
  "-v `"$bindPath`":/app/backend/data"
}

# Run
$runCmd = @(
  "run","-d",
  "--name",$ContainerName,
  "--restart","always",
  "--pull=always",
  "-p","$HostPort`:8080"
) + $persistFlag.Split(' ') + @($Image)

# Ejecutar y validar
docker @runCmd | Out-Null

# 8) Comprobación rápida
Start-Sleep -Seconds 2
$running = (& docker ps --filter "name=$ContainerName" --filter "status=running" -q)
if (-not $running) {
  Err "❌ El contenedor no está en ejecución. Revisa 'docker logs $ContainerName'."
  exit 1
}

Ok "✅ Open WebUI está en marcha."
Write-Host ("🔗 Abre: http://localhost:{0}" -f $HostPort) -ForegroundColor Cyan
Write-Host "⚙️ Configura tu proveedor (OpenAI, Azure OpenAI, etc.) en Settings > Connections dentro de la WebUI." -ForegroundColor Yellow
