# GitHub Secrets Setup Script
# This script helps you set up GitHub repository secrets for CI/CD

Write-Host "🔐 Setting up GitHub Repository Secrets" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green

# Check if GitHub CLI is installed
if (!(Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host "❌ GitHub CLI (gh) is not installed. Please install it first:" -ForegroundColor Red
    Write-Host "   https://cli.github.com/" -ForegroundColor Yellow
    exit 1
}

# Check if authenticated
$authStatus = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ GitHub CLI not authenticated. Please run:" -ForegroundColor Red
    Write-Host "   gh auth login" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ GitHub CLI is authenticated" -ForegroundColor Green

# Get the service account key content
$keyFile = "terraform-github-actions-key.json"
if (!(Test-Path $keyFile)) {
    Write-Host "❌ Service account key file not found: $keyFile" -ForegroundColor Red
    Write-Host "Please create the service account key first:" -ForegroundColor Yellow
    Write-Host "gcloud iam service-accounts keys create $keyFile --iam-account=terraform-github-actions@terragrunt-471602.iam.gserviceaccount.com" -ForegroundColor Gray
    exit 1
}

Write-Host "📋 Setting up GitHub repository secrets..." -ForegroundColor Yellow

# Set GCP_SA_KEY secret
Write-Host "Setting GCP_SA_KEY secret..." -ForegroundColor Cyan
gh secret set GCP_SA_KEY --repo catherinevee/terraform-gcp --body-file $keyFile

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ GCP_SA_KEY secret set successfully" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to set GCP_SA_KEY secret" -ForegroundColor Red
}

# Set GCP_PROJECT_ID secret
Write-Host "Setting GCP_PROJECT_ID secret..." -ForegroundColor Cyan
gh secret set GCP_PROJECT_ID --repo catherinevee/terraform-gcp --body "terragrunt-471602"

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ GCP_PROJECT_ID secret set successfully" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to set GCP_PROJECT_ID secret" -ForegroundColor Red
}

Write-Host ""
Write-Host "🎉 GitHub secrets setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Next steps:" -ForegroundColor Yellow
Write-Host "1. Go to your GitHub repository: https://github.com/catherinevee/terraform-gcp" -ForegroundColor White
Write-Host "2. Check the Actions tab to see the workflows" -ForegroundColor White
Write-Host "3. Create a pull request to test the Terraform plan workflow" -ForegroundColor White
Write-Host "4. Merge to main to trigger the apply workflow" -ForegroundColor White
Write-Host ""
Write-Host "🔒 Security Note: The service account key file has been uploaded as a secret." -ForegroundColor Yellow
Write-Host "   You can now safely delete the local key file:" -ForegroundColor Yellow
Write-Host "   Remove-Item $keyFile" -ForegroundColor Gray
