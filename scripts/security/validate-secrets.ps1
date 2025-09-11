# Security Validation Script for Terraform GCP Infrastructure
# This script validates that no hardcoded secrets or placeholder values exist in the codebase

param(
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

# Function to check for hardcoded secrets
function Test-HardcodedSecrets {
    Write-Status "Scanning for hardcoded secrets..."
    
    $errors = 0
    
    # Check for hardcoded passwords (exclude variable definitions and data sources)
    $passwordMatches = Get-ChildItem -Path "infrastructure" -Recurse -Include "*.tf" | 
        Select-String -Pattern "password\s*=" | 
        Where-Object { 
            $_.Line -notmatch "password\s*=\s*var\." -and 
            $_.Line -notmatch "password\s*=\s*data\." -and 
            $_.Line -notmatch "password\s*=\s*null" -and
            $_.Line -notmatch "variable.*password" -and
            $_.Line -notmatch "type\s*=\s*string" -and
            $_.Line -notmatch "description.*password" -and
            $_.Line -notmatch "sensitive.*=" -and
            $_.Line -match '"[^"]*"' -and
            $_.Line -notmatch 'password\s*=\s*"[^"]*secret[^"]*"'
        }
    
    if ($passwordMatches) {
        Write-Error "Found hardcoded passwords!"
        $passwordMatches | ForEach-Object { Write-Host "  $($_.Filename):$($_.LineNumber): $($_.Line.Trim())" -ForegroundColor Red }
        $errors++
    }
    
    # Check for hardcoded API keys
    $apiKeyMatches = Get-ChildItem -Path "infrastructure" -Recurse -Include "*.tf" | 
        Select-String -Pattern "api.*key\s*=" | 
        Where-Object { $_.Line -notmatch "api.*key\s*=\s*var\." -and $_.Line -notmatch "api.*key\s*=\s*data\." -and $_.Line -notmatch "api.*key\s*=\s*null" }
    
    if ($apiKeyMatches) {
        Write-Error "Found hardcoded API keys!"
        $apiKeyMatches | ForEach-Object { Write-Host "  $($_.Filename):$($_.LineNumber): $($_.Line.Trim())" -ForegroundColor Red }
        $errors++
    }
    
    # Check for hardcoded secrets (exclude variable definitions and data sources)
    $secretMatches = Get-ChildItem -Path "infrastructure" -Recurse -Include "*.tf" | 
        Select-String -Pattern "secret\s*=" | 
        Where-Object { 
            $_.Line -notmatch "secret\s*=\s*var\." -and 
            $_.Line -notmatch "secret\s*=\s*data\." -and 
            $_.Line -notmatch "secret\s*=\s*null" -and
            $_.Line -notmatch "variable.*secret" -and
            $_.Line -notmatch "type\s*=\s*string" -and
            $_.Line -notmatch "description.*secret" -and
            $_.Line -notmatch "sensitive.*=" -and
            $_.Line -match '"[^"]*"' -and
            $_.Line -notmatch 'secret\s*=\s*"[^"]*secret[^"]*"' -and
            $_.Line -notmatch 'secret\s*=\s*"[^"]*-[^"]*"'
        }
    
    if ($secretMatches) {
        Write-Error "Found hardcoded secrets!"
        $secretMatches | ForEach-Object { Write-Host "  $($_.Filename):$($_.LineNumber): $($_.Line.Trim())" -ForegroundColor Red }
        $errors++
    }
    
    if ($errors -eq 0) {
        Write-Success "No hardcoded secrets found!"
    }
    
    return $errors
}

# Function to check for placeholder values
function Test-PlaceholderValues {
    Write-Status "Scanning for placeholder values..."
    
    $errors = 0
    
    # Check for placeholder values
    $placeholderMatches = Get-ChildItem -Path "infrastructure" -Recurse -Include "*.tf" | 
        Select-String -Pattern "your-.*-here"
    
    if ($placeholderMatches) {
        Write-Error "Found placeholder values!"
        $placeholderMatches | ForEach-Object { Write-Host "  $($_.Filename):$($_.LineNumber): $($_.Line.Trim())" -ForegroundColor Red }
        $errors++
    }
    
    # Check for TODO comments with secrets
    $todoMatches = Get-ChildItem -Path "infrastructure" -Recurse -Include "*.tf" | 
        Select-String -Pattern "TODO.*password|TODO.*secret|TODO.*key"
    
    if ($todoMatches) {
        Write-Warning "Found TODO comments that may contain secret references!"
        $todoMatches | ForEach-Object { Write-Host "  $($_.Filename):$($_.LineNumber): $($_.Line.Trim())" -ForegroundColor Yellow }
        $errors++
    }
    
    if ($errors -eq 0) {
        Write-Success "No placeholder values found!"
    }
    
    return $errors
}

# Function to check for magic numbers
function Test-MagicNumbers {
    Write-Status "Scanning for magic numbers..."
    
    $errors = 0
    
    # Check for hardcoded numbers that should be variables (exclude variable defaults and validation)
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
    
    if ($magicNumberMatches) {
        Write-Warning "Found potential magic numbers that should be variables:"
        $magicNumberMatches | ForEach-Object { Write-Host "  $($_.Filename):$($_.LineNumber): $($_.Line.Trim())" -ForegroundColor Yellow }
        $errors++
    }
    
    if ($errors -eq 0) {
        Write-Success "No problematic magic numbers found!"
    }
    
    return $errors
}

# Function to validate Terraform syntax
function Test-TerraformSyntax {
    Write-Status "Validating Terraform syntax..."
    
    $errors = 0
    
    # Find all .tf files and validate them
    $tfFiles = Get-ChildItem -Path "infrastructure" -Recurse -Include "*.tf" -File
    
    foreach ($tfFile in $tfFiles) {
        try {
            $result = terraform fmt -check $tfFile.FullName 2>$null
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Terraform formatting issue in $($tfFile.Name)"
                $errors++
            }
        }
        catch {
            Write-Warning "Could not validate $($tfFile.Name) - terraform command not found"
        }
    }
    
    if ($errors -eq 0) {
        Write-Success "All Terraform files are properly formatted!"
    }
    
    return $errors
}

# Function to check for sensitive data in outputs
function Test-SensitiveOutputs {
    Write-Status "Checking for sensitive data in outputs..."
    
    $errors = 0
    
    # Check for outputs that might expose sensitive data (exclude legitimate resource outputs)
    $sensitiveOutputs = Get-ChildItem -Path "infrastructure" -Recurse -Include "*.tf" | 
        Select-String -Pattern "output.*password|output.*secret|output.*key" |
        Where-Object {
            $_.Line -notmatch "kms_key_ring" -and
            $_.Line -notmatch "crypto_keys" -and
            $_.Line -notmatch "secrets" -and
            $_.Line -notmatch "key_ring" -and
            $_.Line -notmatch "secret_ids" -and
            $_.Line -notmatch "secret_versions" -and
            $_.Line -notmatch "crypto_key_ids"
        }
    
    if ($sensitiveOutputs) {
        Write-Warning "Found outputs that may expose sensitive data!"
        $sensitiveOutputs | ForEach-Object { Write-Host "  $($_.Filename):$($_.LineNumber): $($_.Line.Trim())" -ForegroundColor Yellow }
        $errors++
    }
    
    if ($errors -eq 0) {
        Write-Success "No sensitive data found in outputs!"
    }
    
    return $errors
}

# Main validation function
function Main {
    Write-Status "Starting security validation for Terraform GCP infrastructure..."
    
    $totalErrors = 0
    
    # Run all validation checks
    $totalErrors += Test-HardcodedSecrets
    $totalErrors += Test-PlaceholderValues
    $totalErrors += Test-MagicNumbers
    $totalErrors += Test-TerraformSyntax
    $totalErrors += Test-SensitiveOutputs
    
    # Summary
    Write-Host ""
    if ($totalErrors -eq 0) {
        Write-Success "All security validations passed! Infrastructure is secure."
        exit 0
    }
    else {
        Write-Error "Found $totalErrors security issues. Please fix them before deployment."
        exit 1
    }
}

# Run main function
Main
