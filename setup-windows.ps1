# Windows Setup Script for Terraform-GCP Implementation
# Run this script in PowerShell as Administrator

Write-Host "🚀 Setting up Terraform-GCP Environment on Windows" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Green

# Check if running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "❌ Please run PowerShell as Administrator to install required tools" -ForegroundColor Red
    exit 1
}

# Install Chocolatey if not already installed
if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "📦 Installing Chocolatey..." -ForegroundColor Yellow
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
}

# Install required tools
Write-Host "📦 Installing required tools..." -ForegroundColor Yellow

# Install jq
if (!(Get-Command jq -ErrorAction SilentlyContinue)) {
    Write-Host "Installing jq..." -ForegroundColor Cyan
    choco install jq -y
}

# Install curl (if not already available)
if (!(Get-Command curl -ErrorAction SilentlyContinue)) {
    Write-Host "Installing curl..." -ForegroundColor Cyan
    choco install curl -y
}

# Install kubectl (for GKE management)
if (!(Get-Command kubectl -ErrorAction SilentlyContinue)) {
    Write-Host "Installing kubectl..." -ForegroundColor Cyan
    choco install kubernetes-cli -y
}

# Refresh environment variables
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

Write-Host ""
Write-Host "✅ Prerequisites Check:" -ForegroundColor Green
Write-Host "- GCP CLI authenticated: $((gcloud auth list --filter=status:ACTIVE --format='value(account)' | Select-Object -First 1))" -ForegroundColor Cyan
Write-Host "- Current project: $(gcloud config get-value project)" -ForegroundColor Cyan
Write-Host "- Terraform installed: $(if (Get-Command terraform -ErrorAction SilentlyContinue) { 'Yes' } else { 'No' })" -ForegroundColor Cyan
Write-Host "- jq installed: $(if (Get-Command jq -ErrorAction SilentlyContinue) { 'Yes' } else { 'No' })" -ForegroundColor Cyan
Write-Host "- curl installed: $(if (Get-Command curl -ErrorAction SilentlyContinue) { 'Yes' } else { 'No' })" -ForegroundColor Cyan
Write-Host "- kubectl installed: $(if (Get-Command kubectl -ErrorAction SilentlyContinue) { 'Yes' } else { 'No' })" -ForegroundColor Cyan

Write-Host ""
Write-Host "📋 Next Steps:" -ForegroundColor Yellow
Write-Host "1. Set your environment variables:" -ForegroundColor White
Write-Host "   `$env:PROJECT_ID='your-project-id'" -ForegroundColor Gray
Write-Host "   `$env:ENVIRONMENT='dev'" -ForegroundColor Gray
Write-Host "   `$env:REGION='us-central1'" -ForegroundColor Gray
Write-Host "   `$env:ZONE='us-central1-a'" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Run Phase 0 deployment:" -ForegroundColor White
Write-Host "   .\scripts\automation\phase-deployment.sh -p `$env:PROJECT_ID -e `$env:ENVIRONMENT 0" -ForegroundColor Gray
Write-Host ""
Write-Host "✅ Setup complete!" -ForegroundColor Green
