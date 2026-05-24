# Atomic Radius — Dev Environment Starter
# Double-click or run: powershell -ExecutionPolicy Bypass -File dev\start.ps1

$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent

Write-Host "`n=== Atomic Radius Dev Startup ===" -ForegroundColor Green

# ── 1. Start Docker Desktop if not running ─────────────────────────────────
$dockerRunning = Get-Process 'Docker Desktop' -ErrorAction SilentlyContinue
if (-not $dockerRunning) {
    Write-Host "Starting Docker Desktop..." -ForegroundColor Yellow
    Start-Process "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe"
} else {
    Write-Host "Docker Desktop already running." -ForegroundColor Cyan
}

# Wait for the Docker engine pipe to become available (up to 90s)
Write-Host "Waiting for Docker engine..." -ForegroundColor Yellow
$timeout = 90
$elapsed = 0
while ($elapsed -lt $timeout) {
    $ready = docker info 2>$null
    if ($LASTEXITCODE -eq 0) { break }
    Start-Sleep -Seconds 3
    $elapsed += 3
    Write-Host "  ...still waiting ($elapsed s)" -ForegroundColor DarkGray
}
if ($elapsed -ge $timeout) {
    Write-Host "Docker did not start in time. Open Docker Desktop manually and re-run." -ForegroundColor Red
    pause; exit 1
}
Write-Host "Docker engine ready." -ForegroundColor Green

# ── 2. Bring up core Docker Compose services ───────────────────────────────
# Only starts the services needed for local dev.
# Skips heavy/optional services: clamav, livekit, cloudflared, clickhouse,
#   metrics, media, admin, marketing, docs (saves disk + startup time).
Write-Host "`nStarting core Docker Compose services..." -ForegroundColor Yellow
Set-Location $repo
$coreServices = @(
    'caddy', 'api', 'worker', 'gateway',
    'postgres', 'cassandra', 'redis',
    'minio', 'minio-setup', 'meilisearch',
    'cassandra-migrate'
)
docker compose -f dev\compose.yaml --env-file dev\.env up -d @coreServices
if ($LASTEXITCODE -ne 0) {
    Write-Host "docker compose failed." -ForegroundColor Red
    pause; exit 1
}
Write-Host "Core containers started." -ForegroundColor Green

# ── 3. Start frontend dev server in a new terminal window ──────────────────
Write-Host "`nStarting frontend dev server on http://localhost:3000 ..." -ForegroundColor Yellow
$frontendPath = Join-Path $repo 'fluxer_app'
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$frontendPath'; pnpm dev"

# ── 4. Open browser after a short delay ────────────────────────────────────
Write-Host "Waiting 15s for dev server to compile, then opening browser..." -ForegroundColor Yellow
Start-Sleep -Seconds 15
Start-Process "http://localhost:8088"

Write-Host "`nDone! App should be open at http://localhost:8088" -ForegroundColor Green
