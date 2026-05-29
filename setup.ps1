# Lytx Version Checker — one-shot GitHub setup (Windows / PowerShell)
# Usage: powershell -ExecutionPolicy Bypass -File setup.ps1
$ErrorActionPreference = "Stop"

Write-Host "🔧 Lytx Version Checker — GitHub setup" -ForegroundColor Cyan

# 1) GitHub CLI
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
  Write-Host "📦 Installing GitHub CLI..." -ForegroundColor Yellow
  if (Get-Command winget -ErrorAction SilentlyContinue) {
    winget install --id GitHub.cli -e --source winget --accept-source-agreements --accept-package-agreements
  } elseif (Get-Command choco -ErrorAction SilentlyContinue) {
    choco install gh -y
  } elseif (Get-Command scoop -ErrorAction SilentlyContinue) {
    scoop install gh
  } else {
    Write-Host "❌ No package manager (winget/choco/scoop) found." -ForegroundColor Red
    Write-Host "   Install winget from the Microsoft Store, or download gh from https://cli.github.com" -ForegroundColor Red
    exit 1
  }
  # Refresh PATH so gh is usable in this session
  $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
              [System.Environment]::GetEnvironmentVariable("Path","User")
} else {
  Write-Host "✅ gh already installed ($((gh --version | Select-Object -First 1)))" -ForegroundColor Green
}

# 2) Auth — only if not already logged in
gh auth status 2>$null
if ($LASTEXITCODE -ne 0) {
  Write-Host "🔐 Logging in to GitHub..." -ForegroundColor Yellow
  Write-Host "   Pick: GitHub.com → HTTPS → Yes → Login with a web browser"
  Write-Host "   ⚠️  On the success page, click 'Configure SSO → Authorize' for lytx-services" -ForegroundColor Yellow
  gh auth login
} else {
  Write-Host "✅ Already authenticated with GitHub" -ForegroundColor Green
}

# 3) Copy token to clipboard
try {
  gh auth token | clip
  Write-Host ""
  Write-Host "🎉 Done! Token copied to clipboard." -ForegroundColor Green
  Write-Host "👉 Open the Version Checker → GitHub Access → paste & Save."
} catch {
  Write-Host "❌ Could not copy token. Run manually: gh auth token | clip" -ForegroundColor Red
  exit 1
}
