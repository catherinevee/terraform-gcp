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
Check-Resource "Load Balancer" "acme-ecommerce-platform-lb" { gcloud compute forwarding-rules list --global --filter="name:acme-ecommerce-platform-lb" --project=$ProjectId }

# Service Accounts
Check-Resource "Service Account" "terraform-github-actions" { gcloud iam service-accounts describe "terraform-github-actions@$ProjectId.iam.gserviceaccount.com" --project=$ProjectId }

# KMS Keyring
Check-Resource "KMS Keyring" "cataziza-ecommerce-platform-dev-keyring" { gcloud kms keyrings describe cataziza-ecommerce-platform-dev-keyring --location=europe-west1 --project=$ProjectId }

# Terraform State Bucket
Check-Resource "State Bucket" "acme-ecommerce-platform-dev-terraform-state" { gsutil ls "gs://acme-ecommerce-platform-dev-terraform-state" }

# Compute Instances
Check-Resource "Compute Instance" "acme-web-server" { gcloud compute instances list --filter="name:acme-web-server" --project=$ProjectId }

# Cloud SQL (optional)
Check-Resource "Cloud SQL" "acme-database-dev" { gcloud sql instances describe acme-database-dev --project=$ProjectId }

# Storage Buckets
Check-Resource "Storage Bucket" "acme-customer-data-dev" { gsutil ls "gs://acme-customer-data-dev" }
Check-Resource "Storage Bucket" "acme-application-logs-dev" { gsutil ls "gs://acme-application-logs-dev" }

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

$statusMessage = "Status check completed - $Status ($Percentage percent)"
Write-Host $statusMessage -ForegroundColor Cyan