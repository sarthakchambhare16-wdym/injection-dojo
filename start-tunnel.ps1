# ==============================================================================
# INJECTION DOJO: Cloudflare Tunnel & Ollama Bridge Setup (PowerShell)
# Exposes local Gemma 4 (Ollama) securely to your Vercel deployment
# ==============================================================================

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "🥋 INJECTION DOJO - Cloudflare Tunnel & Ollama Bridge" -ForegroundColor Green
Write-Host "=================================================================" -ForegroundColor Cyan

# 1. CORS Configuration (Critical for Vercel browser access)
Write-Host "`n[1/4] Configuring Ollama CORS (OLLAMA_ORIGINS='*')..." -ForegroundColor Yellow
$env:OLLAMA_ORIGINS = "*"
[System.Environment]::SetEnvironmentVariable("OLLAMA_ORIGINS", "*", "Process")

# 2. Check if Ollama daemon is active on port 11434 (Prevents Cloudflare Error 1033)
Write-Host "[2/4] Verifying local Ollama service on port 11434..." -ForegroundColor Yellow
$ollamaLive = $false
try {
    $resp = Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/version" -Method Get -TimeoutSec 3 -ErrorAction Stop
    Write-Host "   Ollama is active! Version: $($resp.version)" -ForegroundColor Green
    $ollamaLive = $true
} catch {
    Write-Host "   Ollama is not responding on http://127.0.0.1:11434." -ForegroundColor Red
    Write-Host "   Starting Ollama daemon with OLLAMA_ORIGINS='*'..." -ForegroundColor Cyan
    Start-Process -FilePath "ollama" -ArgumentList "serve" -WindowStyle Minimized
    Start-Sleep -Seconds 3
    try {
        $resp = Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/version" -Method Get -TimeoutSec 4 -ErrorAction Stop
        Write-Host "   Ollama successfully started! Version: $($resp.version)" -ForegroundColor Green
        $ollamaLive = $true
    } catch {
        Write-Host "   Warning: Could not auto-start Ollama. Please run 'ollama serve' in another terminal." -ForegroundColor DarkYellow
    }
}

# 3. Locate or Download cloudflared.exe
Write-Host "[3/4] Checking Cloudflare Tunnel (cloudflared)..." -ForegroundColor Yellow
$binDir = Join-Path $PSScriptRoot "bin"
$localCloudflared = Join-Path $binDir "cloudflared.exe"

$cloudflaredCmd = "cloudflared"
$hasGlobal = (Get-Command "cloudflared" -ErrorAction SilentlyContinue)

if (-not $hasGlobal) {
    if (Test-Path $localCloudflared) {
        $cloudflaredCmd = $localCloudflared
        Write-Host "   Using local cloudflared binary: $localCloudflared" -ForegroundColor Green
    } else {
        Write-Host "   cloudflared not found. Downloading standalone cloudflared.exe..." -ForegroundColor Cyan
        if (-not (Test-Path $binDir)) { New-Item -ItemType Directory -Path $binDir -Force | Out-Null }
        $downloadUrl = "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe"
        try {
            Invoke-WebRequest -Uri $downloadUrl -OutFile $localCloudflared -UseBasicParsing
            Write-Host "   cloudflared.exe downloaded successfully to bin\cloudflared.exe!" -ForegroundColor Green
            $cloudflaredCmd = $localCloudflared
        } catch {
            Write-Host "   Could not auto-download cloudflared: $_" -ForegroundColor Red
            Write-Host "   Please download cloudflared from: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/" -ForegroundColor Yellow
            pause
            exit 1
        }
    }
} else {
    Write-Host "   cloudflared is installed globally." -ForegroundColor Green
}

# 4. Launch Cloudflare Tunnel
Write-Host "`n[4/4] Starting Cloudflare Tunnel to http://127.0.0.1:11434..." -ForegroundColor Yellow
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "Look for the public URL in the logs below (e.g. https://xxxx.trycloudflare.com)." -ForegroundColor White
Write-Host "Copy that URL and paste it into the 'Bridge Endpoint' ribbon on your Vercel website!" -ForegroundColor Green
Write-Host "=================================================================`n" -ForegroundColor Cyan

& $cloudflaredCmd tunnel --protocol http2 --url http://127.0.0.1:11434 --http-host-header "localhost:11434"
