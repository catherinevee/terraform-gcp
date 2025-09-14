# PowerShell version of deployment status checker
param(
    [string]$ProjectId = "acme-ecommerce-platform-dev"
)

# Initialize counters
$TotalChecks = 0
$PassedChecks = 0

function Check-Resource {
    param(
        [string]$ResourceType,
        [string]$ResourceName,
        [scriptblock]$Command
    )
    
    $script:TotalChecks++
    
    try {
        $result = & $Command 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ $ResourceType`: $ResourceName - EXISTS" -ForegroundColor Green
            $script:PassedChecks++
            return $true
        } else {
            Write-Host "❌ $ResourceType`: $ResourceName - MISSING" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "❌ $ResourceType`: $ResourceName - MISSING" -ForegroundColor Red
        return $false
    }
}

Write-Host "🔍 Checking deployment status for project: $ProjectId" -ForegroundColor Cyan
Write-Host "📊 Checking critical infrastructure components..." -ForegroundColor Cyan

# VPC and Networking
Check-Resource "VPC" "default" { gcloud compute networks describe default --project=$ProjectId }

# Load Balancer
Check-Resource "Load Balancer" "cataziza-platform-dev-lb-forwarding-rule" { gcloud compute forwarding-rules list --global --filter="name:cataziza-platform-dev-lb-forwarding-rule" --project=$ProjectId }

# Service Accounts
Check-Resource "Service Account" "cataziza-terraform-sa" { gcloud iam service-accounts describe "cataziza-terraform-sa@$ProjectId.iam.gserviceaccount.com" --project=$ProjectId }

# KMS Keyring
Check-Resource "KMS Keyring" "cataziza-platform-dev-keyring" { gcloud kms keyrings describe cataziza-platform-dev-keyring --location=europe-west1 --project=$ProjectId }

# Terraform State Bucket
Check-Resource "State Bucket" "acme-ecommerce-platform-dev-terraform-state" { gcloud storage buckets describe gs://acme-ecommerce-platform-dev-terraform-state --project=$ProjectId }

# Secret Manager
Check-Resource "Secret Manager" "cataziza-orders-database-password" { gcloud secrets describe cataziza-orders-database-password --project=$ProjectId }

# Storage Buckets
Check-Resource "Storage Bucket" "cataziza-security-logs-dev" { gcloud storage buckets describe gs://cataziza-security-logs-dev-6b33317a --project=$ProjectId }

# Calculate status
$Percentage = [math]::Round(($PassedChecks * 100 / $TotalChecks), 0)

if ($Percentage -ge 80) {
    $Status = "LIVE"
} elseif ($Percentage -ge 50) {
    $Status = "PARTIAL"
} else {
    $Status = "NOTDEPLOYED"
}

Write-Host ""
Write-Host "📈 Status Summary:" -ForegroundColor Cyan
Write-Host "   Total Checks: $TotalChecks"
Write-Host "   Passed: $PassedChecks"
Write-Host "   Percentage: $Percentage%"
Write-Host "   Status: $Status" -ForegroundColor $(if ($Status -eq "LIVE") { "Green" } elseif ($Status -eq "PARTIAL") { "Yellow" } else { "Red" })

# Output status to file
$StatusData = @{
    status = $Status
    percentage = $Percentage
    total_checks = $TotalChecks
    passed_checks = $PassedChecks
    timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    last_checked = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss UTC")
} | ConvertTo-Json

$StatusData | Out-File -FilePath "deployment-status.json" -Encoding UTF8
$Status | Out-File -FilePath "status.txt" -Encoding UTF8

Write-Host "Status check completed - $Status ($Percentage percent)" -ForegroundColor Cyan