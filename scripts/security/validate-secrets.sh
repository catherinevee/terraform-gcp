#!/bin/bash

# Security Validation Script for Terraform GCP Infrastructure
# This script validates that no hardcoded secrets or placeholder values exist in the codebase

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check for hardcoded secrets
check_hardcoded_secrets() {
    print_status "🔍 Scanning for hardcoded secrets..."
    
    local errors=0
    
    # Check for hardcoded passwords
    if grep -r "password.*=" infrastructure/ | grep -v "password.*=.*var\." | grep -v "password.*=.*data\." | grep -v "password.*=.*null"; then
        print_error "Found hardcoded passwords!"
        grep -r "password.*=" infrastructure/ | grep -v "password.*=.*var\." | grep -v "password.*=.*data\." | grep -v "password.*=.*null"
        errors=$((errors + 1))
    fi
    
    # Check for hardcoded API keys
    if grep -r "api.*key.*=" infrastructure/ | grep -v "api.*key.*=.*var\." | grep -v "api.*key.*=.*data\." | grep -v "api.*key.*=.*null"; then
        print_error "Found hardcoded API keys!"
        grep -r "api.*key.*=" infrastructure/ | grep -v "api.*key.*=.*var\." | grep -v "api.*key.*=.*data\." | grep -v "api.*key.*=.*null"
        errors=$((errors + 1))
    fi
    
    # Check for hardcoded secrets
    if grep -r "secret.*=" infrastructure/ | grep -v "secret.*=.*var\." | grep -v "secret.*=.*data\." | grep -v "secret.*=.*null"; then
        print_error "Found hardcoded secrets!"
        grep -r "secret.*=" infrastructure/ | grep -v "secret.*=.*var\." | grep -v "secret.*=.*data\." | grep -v "secret.*=.*null"
        errors=$((errors + 1))
    fi
    
    if [ $errors -eq 0 ]; then
        print_success "No hardcoded secrets found!"
    fi
    
    return $errors
}

# Function to check for placeholder values
check_placeholder_values() {
    print_status "🔍 Scanning for placeholder values..."
    
    local errors=0
    
    # Check for placeholder values
    if grep -r "your-.*-here" infrastructure/; then
        print_error "Found placeholder values!"
        errors=$((errors + 1))
    fi
    
    # Check for TODO comments with secrets
    if grep -r "TODO.*password\|TODO.*secret\|TODO.*key" infrastructure/; then
        print_warning "Found TODO comments that may contain secret references!"
        errors=$((errors + 1))
    fi
    
    if [ $errors -eq 0 ]; then
        print_success "No placeholder values found!"
    fi
    
    return $errors
}

# Function to check for magic numbers
check_magic_numbers() {
    print_status "🔍 Scanning for magic numbers..."
    
    local errors=0
    
    # Check for hardcoded numbers that should be variables
    if grep -r "= [0-9]\+[^a-zA-Z]" infrastructure/ | grep -v "required_version" | grep -v "port.*=.*80" | grep -v "port.*=.*443" | grep -v "port.*=.*22"; then
        print_warning "Found potential magic numbers that should be variables:"
        grep -r "= [0-9]\+[^a-zA-Z]" infrastructure/ | grep -v "required_version" | grep -v "port.*=.*80" | grep -v "port.*=.*443" | grep -v "port.*=.*22"
        errors=$((errors + 1))
    fi
    
    if [ $errors -eq 0 ]; then
        print_success "No problematic magic numbers found!"
    fi
    
    return $errors
}

# Function to validate Terraform syntax
validate_terraform_syntax() {
    print_status "🔍 Validating Terraform syntax..."
    
    local errors=0
    
    # Find all .tf files and validate them
    for tf_file in $(find infrastructure/ -name "*.tf" -type f); do
        if ! terraform fmt -check "$tf_file" >/dev/null 2>&1; then
            print_error "Terraform formatting issue in $tf_file"
            errors=$((errors + 1))
        fi
    done
    
    if [ $errors -eq 0 ]; then
        print_success "All Terraform files are properly formatted!"
    fi
    
    return $errors
}

# Function to check for sensitive data in outputs
check_sensitive_outputs() {
    print_status "🔍 Checking for sensitive data in outputs..."
    
    local errors=0
    
    # Check for outputs that might expose sensitive data
    if grep -r "output.*password\|output.*secret\|output.*key" infrastructure/; then
        print_warning "Found outputs that may expose sensitive data!"
        errors=$((errors + 1))
    fi
    
    if [ $errors -eq 0 ]; then
        print_success "No sensitive data found in outputs!"
    fi
    
    return $errors
}

# Main validation function
main() {
    print_status "🚀 Starting security validation for Terraform GCP infrastructure..."
    
    local total_errors=0
    
    # Run all validation checks
    check_hardcoded_secrets
    total_errors=$((total_errors + $?))
    
    check_placeholder_values
    total_errors=$((total_errors + $?))
    
    check_magic_numbers
    total_errors=$((total_errors + $?))
    
    validate_terraform_syntax
    total_errors=$((total_errors + $?))
    
    check_sensitive_outputs
    total_errors=$((total_errors + $?))
    
    # Summary
    echo ""
    if [ $total_errors -eq 0 ]; then
        print_success "🎉 All security validations passed! Infrastructure is secure."
        exit 0
    else
        print_error "❌ Found $total_errors security issues. Please fix them before deployment."
        exit 1
    fi
}

# Enhanced security scanning functions
check_dependency_vulnerabilities() {
    print_status "🔍 Checking for dependency vulnerabilities..."
    
    if command -v trivy &> /dev/null; then
        trivy fs --severity HIGH,CRITICAL infrastructure/
    else
        print_warning "Trivy not installed - skipping dependency check"
    fi
}

check_terraform_security() {
    print_status "🔍 Running Terraform security scan..."
    
    if command -v tfsec &> /dev/null; then
        tfsec infrastructure/ --format json > tfsec-results.json
        local issues=$(jq '.results | length' tfsec-results.json)
        if [ "$issues" -gt 0 ]; then
            print_error "Found $issues Terraform security issues"
            return 1
        fi
    else
        print_warning "tfsec not installed - skipping Terraform security scan"
    fi
}

check_terraform_formatting() {
    print_status "🔍 Checking Terraform formatting..."
    
    local formatting_issues=0
    
    # Check for terraform fmt
    if command -v terraform &> /dev/null; then
        for file in $(find infrastructure/ -name "*.tf"); do
            if ! terraform fmt -check "$file" > /dev/null 2>&1; then
                print_warning "Terraform formatting issue in $file"
                formatting_issues=$((formatting_issues + 1))
            fi
        done
    else
        print_warning "Terraform not installed - skipping formatting check"
    fi
    
    if [ $formatting_issues -eq 0 ]; then
        print_success "All Terraform files are properly formatted"
    else
        print_error "Found $formatting_issues Terraform formatting issues"
        return 1
    fi
}

check_terraform_validation() {
    print_status "🔍 Running Terraform validation..."
    
    local validation_errors=0
    
    # Check each environment
    for env_dir in infrastructure/environments/*/; do
        for region_dir in "$env_dir"*/; do
            if [ -f "$region_dir/main.tf" ]; then
                print_status "Validating $region_dir"
                if ! terraform -chdir="$region_dir" init -backend=false > /dev/null 2>&1; then
                    print_error "Terraform init failed in $region_dir"
                    validation_errors=$((validation_errors + 1))
                elif ! terraform -chdir="$region_dir" validate > /dev/null 2>&1; then
                    print_error "Terraform validation failed in $region_dir"
                    validation_errors=$((validation_errors + 1))
                fi
            fi
        done
    done
    
    if [ $validation_errors -eq 0 ]; then
        print_success "All Terraform configurations are valid"
    else
        print_error "Found $validation_errors Terraform validation errors"
        return 1
    fi
}

# Run main function
main "$@"
