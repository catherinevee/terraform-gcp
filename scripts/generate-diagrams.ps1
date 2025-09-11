# Generate GCP Architecture Diagrams
# This script generates visual diagrams of the GCP infrastructure

Write-Host "🎨 Generating GCP Architecture Diagrams..." -ForegroundColor Cyan

# Check if Python is available
try {
    $pythonVersion = python --version 2>&1
    Write-Host "✅ Python found: $pythonVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Python is not installed or not in PATH" -ForegroundColor Red
    exit 1
}

# Check if diagrams library is installed
try {
    python -c "import diagrams" 2>$null
    Write-Host "✅ Diagrams library is available" -ForegroundColor Green
} catch {
    Write-Host "📦 Installing diagrams library..." -ForegroundColor Yellow
    python -m pip install diagrams
}

# Generate diagrams
Write-Host "🔄 Generating comprehensive architecture diagram..." -ForegroundColor Yellow
python generate_architecture_diagram.py

Write-Host "✅ Diagrams generated successfully!" -ForegroundColor Green
Write-Host "📁 Files created:" -ForegroundColor Cyan
Write-Host "   - gcp_architecture_diagram.png" -ForegroundColor White
Write-Host "   - gcp_simplified_diagram.png" -ForegroundColor White
Write-Host ""
Write-Host "💡 You can now view these diagrams in your documentation!" -ForegroundColor Magenta
