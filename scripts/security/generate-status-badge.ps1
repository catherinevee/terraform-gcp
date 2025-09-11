# Dynamic Status Badge Generator for Terraform GCP Infrastructure
# This script generates a status badge showing the current security status

param(
    [switch]$UpdateReadme,
    [switch]$Verbose
)

# Function to print colored output
function Write-Status {
    param([string]$Message)
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Function to check security status
function Get-SecurityStatus {
    Write-Status "Checking security status..."
    
    $errors = 0
    $warnings = 0
    
    # Check for hardcoded secrets
    $passwordMatches = Get-ChildItem -Path "infrastructure" -Recurse -Include "*.tf" | 
        Select-String -Pattern "password\s*=" | 
        Where-Object { 
            $_.Line -notmatch "password\s*=\s*var\." -and 
            $_.Line -notmatch "password\s*=\s*data\." -and 
            $_.Line -notmatch "password\s*=\s*null" -and
            $_.Line -notmatch "variable.*password" -and
            $_.Line -notmatch "type\s*=" -and
            $_.Line -notmatch "description.*password" -and
            $_.Line -notmatch "sensitive\s*=" -and
            $_.Line -match '"[^"]*"'
        }
    
    if ($passwordMatches) {
        $errors++
    }
    
    # Check for placeholder values
    $placeholderMatches = Get-ChildItem -Path "infrastructure" -Recurse -Include "*.tf" | 
        Select-String -Pattern "your-.*-here"
    
    if ($placeholderMatches) {
        $errors++
    }
    
    # Check for hardcoded API keys
    $apiKeyMatches = Get-ChildItem -Path "infrastructure" -Recurse -Include "*.tf" | 
        Select-String -Pattern "api.*key\s*=" | 
        Where-Object { 
            $_.Line -notmatch "api.*key\s*=\s*var\." -and 
            $_.Line -notmatch "api.*key\s*=\s*data\." -and 
            $_.Line -notmatch "api.*key\s*=\s*null" -and
            $_.Line -notmatch "variable.*api" -and
            $_.Line -notmatch "type\s*=" -and
            $_.Line -notmatch "description.*api" -and
            $_.Line -match '"[^"]*"'
        }
    
    if ($apiKeyMatches) {
        $errors++
    }
    
    # Check for hardcoded secrets
    $secretMatches = Get-ChildItem -Path "infrastructure" -Recurse -Include "*.tf" | 
        Select-String -Pattern "secret\s*=" | 
        Where-Object { 
            $_.Line -notmatch "secret\s*=\s*var\." -and 
            $_.Line -notmatch "secret\s*=\s*data\." -and 
            $_.Line -notmatch "secret\s*=\s*null" -and
            $_.Line -notmatch "variable.*secret" -and
            $_.Line -notmatch "type\s*=" -and
            $_.Line -notmatch "description.*secret" -and
            $_.Line -notmatch "sensitive\s*=" -and
            $_.Line -notmatch 'secret\s*=\s*"[^"]*secret[^"]*"' -and
            $_.Line -notmatch 'secret\s*=\s*"[^"]*-[^"]*"' -and
            $_.Line -match '"[^"]*"'
        }
    
    if ($secretMatches) {
        $errors++
    }
    
    # Check for magic numbers (excluding variable defaults and validation)
    $magicNumberMatches = Get-ChildItem -Path "infrastructure" -Recurse -Include "*.tf" | 
        Select-String -Pattern "=\s*\d+[^a-zA-Z]" | 
        Where-Object { 
            $_.Line -notmatch "required_version" -and 
            $_.Line -notmatch "port\s*=\s*80" -and 
            $_.Line -notmatch "port\s*=\s*443" -and 
            $_.Line -notmatch "port\s*=\s*22" -and
            $_.Line -notmatch "default\s*=" -and
            $_.Line -notmatch "condition\s*=" -and
            $_.Line -notmatch "validation" -and
            $_.Line -notmatch "priority\s*=\s*1000" -and
            $_.Line -notmatch "prefix_length\s*=\s*16" -and
            $_.Line -notmatch "error_message" -and
            $_.Line -notmatch "contains\(" -and
            $_.Line -notmatch "alltrue\(" -and
            $_.Line -notmatch "can\(" -and
            $_.Line -notmatch "length\(" -and
            $_.Line -notmatch "for\s+\w+\s+in" -and
            $_.Line -notmatch "&&" -and
            $_.Line -notmatch "\|\|" -and
            $_.Line -notmatch "compliance" -and
            $_.Line -notmatch "monitoring" -and
            $_.Line -notmatch "dashboard" -and
            $_.Line -notmatch "alert" -and
            $_.Line -notmatch "threshold" -and
            $_.Line -notmatch "duration" -and
            $_.Line -notmatch "alignment_period" -and
            $_.Line -notmatch "byte_length" -and
            $_.Line -notmatch "display_name" -and
            $_.Line -notmatch "width.*=" -and
            $_.Line -notmatch "height.*=" -and
            $_.Line -notmatch "count.*=" -and
            $_.Line -notmatch "byte_length.*=" -and
            $_.Line -notmatch "monthly_retention_months.*=" -and
            $_.Line -notmatch "check_interval_sec.*=" -and
            $_.Line -notmatch "retention.*<=" -and
            $_.Line -notmatch "default.*=" -and
            $_.Line -notmatch "validation" -and
            $_.Line -notmatch "condition.*="
        }
    
    if ($magicNumberMatches.Count -gt 0) {
        $warnings++
    }
    
    # Check for validation rules
    $validationCount = (Get-ChildItem -Path "infrastructure" -Recurse -Include "*.tf" | 
        Select-String -Pattern "validation").Count
    
    if ($validationCount -lt 10) {
        $warnings++
    }
    
    # Check for documentation
    if (-not (Test-Path "SECURITY.md") -or -not (Test-Path "DEPLOYMENT-CHECKLIST.md")) {
        $warnings++
    }
    
    # Check for security scripts
    if (-not (Test-Path "scripts/security/validate-secrets.sh") -or -not (Test-Path "scripts/security/validate-secrets.ps1")) {
        $warnings++
    }
    
    # Determine overall status
    if ($errors -eq 0 -and $warnings -eq 0) {
        return "EXCELLENT"
    }
    elseif ($errors -eq 0 -and $warnings -le 2) {
        return "GOOD"
    }
    elseif ($errors -eq 0) {
        return "FAIR"
    }
    else {
        return "POOR"
    }
}

# Function to generate badge
function Get-BadgeUrl {
    param([string]$Status)
    
    $color = switch ($Status) {
        "EXCELLENT" { "brightgreen" }
        "GOOD" { "green" }
        "FAIR" { "yellow" }
        "POOR" { "red" }
        default { "lightgrey" }
    }
    
    $message = switch ($Status) {
        "EXCELLENT" { "Security%20Excellent" }
        "GOOD" { "Security%20Good" }
        "FAIR" { "Security%20Fair" }
        "POOR" { "Security%20Poor" }
        default { "Security%20Unknown" }
    }
    
    return "https://img.shields.io/badge/${message}-${color}"
}

# Function to generate detailed status
function Get-DetailedStatus {
    param([string]$Status)
    
    $timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    
    # Check individual security items
    $passwordCheck = -not (Get-ChildItem -Path "infrastructure" -Recurse -Include "*.tf" | 
        Select-String -Pattern "password\s*=" | 
        Where-Object { 
            $_.Line -notmatch "password\s*=\s*var\." -and 
            $_.Line -notmatch "password\s*=\s*data\." -and 
            $_.Line -notmatch "password\s*=\s*null" -and
            $_.Line -notmatch "variable.*password" -and
            $_.Line -notmatch "type\s*=" -and
            $_.Line -notmatch "description.*password" -and
            $_.Line -notmatch "sensitive\s*=" -and
            $_.Line -match '"[^"]*"'
        })
    
    $placeholderCheck = -not (Get-ChildItem -Path "infrastructure" -Recurse -Include "*.tf" | 
        Select-String -Pattern "your-.*-here")
    
    $apiKeyCheck = -not (Get-ChildItem -Path "infrastructure" -Recurse -Include "*.tf" | 
        Select-String -Pattern "api.*key\s*=" | 
        Where-Object { 
            $_.Line -notmatch "api.*key\s*=\s*var\." -and 
            $_.Line -notmatch "api.*key\s*=\s*data\." -and 
            $_.Line -notmatch "api.*key\s*=\s*null" -and
            $_.Line -notmatch "variable.*api" -and
            $_.Line -notmatch "type\s*=" -and
            $_.Line -notmatch "description.*api" -and
            $_.Line -match '"[^"]*"'
        })
    
    $secretCheck = -not (Get-ChildItem -Path "infrastructure" -Recurse -Include "*.tf" | 
        Select-String -Pattern "secret\s*=" | 
        Where-Object { 
            $_.Line -notmatch "secret\s*=\s*var\." -and 
            $_.Line -notmatch "secret\s*=\s*data\." -and 
            $_.Line -notmatch "secret\s*=\s*null" -and
            $_.Line -notmatch "variable.*secret" -and
            $_.Line -notmatch "type\s*=" -and
            $_.Line -notmatch "description.*secret" -and
            $_.Line -notmatch "sensitive\s*=" -and
            $_.Line -notmatch 'secret\s*=\s*"[^"]*secret[^"]*"' -and
            $_.Line -notmatch 'secret\s*=\s*"[^"]*-[^"]*"' -and
            $_.Line -match '"[^"]*"'
        })
    
    $magicNumberCount = (Get-ChildItem -Path "infrastructure" -Recurse -Include "*.tf" | 
        Select-String -Pattern "=\s*\d+[^a-zA-Z]" | 
        Where-Object { 
            $_.Line -notmatch "required_version" -and 
            $_.Line -notmatch "port\s*=\s*80" -and 
            $_.Line -notmatch "port\s*=\s*443" -and 
            $_.Line -notmatch "port\s*=\s*22" -and
            $_.Line -notmatch "default\s*=" -and
            $_.Line -notmatch "condition\s*=" -and
            $_.Line -notmatch "validation" -and
            $_.Line -notmatch "priority\s*=\s*1000" -and
            $_.Line -notmatch "prefix_length\s*=\s*16"
        }).Count
    
    $validationCount = (Get-ChildItem -Path "infrastructure" -Recurse -Include "*.tf" | 
        Select-String -Pattern "validation").Count
    
    $documentationCheck = (Test-Path "SECURITY.md") -and (Test-Path "DEPLOYMENT-CHECKLIST.md")
    
    $securityScriptsCheck = (Test-Path "scripts/security/validate-secrets.sh") -and (Test-Path "scripts/security/validate-secrets.ps1")
    
    $statusObject = @{
        status = $Status
        timestamp = $timestamp
        checks = @{
            hardcoded_passwords = $passwordCheck
            placeholder_values = $placeholderCheck
            hardcoded_api_keys = $apiKeyCheck
            hardcoded_secrets = $secretCheck
            magic_numbers = $magicNumberCount
            validation_rules = $validationCount
            documentation = $documentationCheck
            security_scripts = $securityScriptsCheck
        }
        version = "1.1.0"
        last_updated = $timestamp
    }
    
    return $statusObject | ConvertTo-Json -Depth 3
}

# Main function
function Main {
    Write-Status "Generating dynamic status badge for Terraform GCP infrastructure..."
    
    # Check security status
    $securityStatus = Get-SecurityStatus
    
    # Generate badge URL
    $badgeUrl = Get-BadgeUrl $securityStatus
    
    # Generate detailed status
    $detailedStatus = Get-DetailedStatus $securityStatus
    
    # Output results
    Write-Host ""
    Write-Status "Security Status: $securityStatus"
    Write-Host ""
    Write-Status "Badge URL:"
    Write-Host "   $badgeUrl"
    Write-Host ""
    Write-Status "Markdown Badge:"
    Write-Host "   ![Security Status]($badgeUrl)"
    Write-Host ""
    Write-Status "Detailed Status:"
    Write-Host ($detailedStatus | ConvertFrom-Json | ConvertTo-Json -Depth 3)
    Write-Host ""
    
    # Save badge URL to file
    $badgeUrl | Out-File -FilePath ".security-badge-url" -Encoding UTF8
    $detailedStatus | Out-File -FilePath ".security-status.json" -Encoding UTF8
    
    # Update README if requested
    if ($UpdateReadme -and (Test-Path "README.md")) {
        if (Select-String -Path "README.md" -Pattern "Security Status" -Quiet) {
            Write-Status "Updating README.md with new badge..."
            $readmeContent = Get-Content "README.md" -Raw
            $readmeContent = $readmeContent -replace "https://img\.shields\.io/badge/Security%20[^)]*", $badgeUrl
            $readmeContent | Out-File -FilePath "README.md" -Encoding UTF8
            Write-Success "README.md updated with new security badge"
        }
        else {
            Write-Warning "Security badge not found in README.md - add manually if needed"
        }
    }
    
    # Summary
    switch ($securityStatus) {
        "EXCELLENT" {
            Write-Success "Security status: EXCELLENT - All checks passed!"
        }
        "GOOD" {
            Write-Success "Security status: GOOD - Minor improvements possible"
        }
        "FAIR" {
            Write-Warning "Security status: FAIR - Some improvements needed"
        }
        "POOR" {
            Write-Error "Security status: POOR - Critical issues found"
        }
    }
    
    Write-Host ""
    Write-Status "To use the badge in your README.md, add:"
    Write-Host "   ![Security Status]($badgeUrl)"
    Write-Host ""
    Write-Status "Badge URL saved to: .security-badge-url"
    Write-Status "Detailed status saved to: .security-status.json"
}

# Run main function
Main
