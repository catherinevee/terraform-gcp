#!/bin/bash

# Dynamic Status Badge Generator for Terraform GCP Infrastructure
# This script generates a status badge showing the current security status

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

# Function to check security status
check_security_status() {
    local errors=0
    local warnings=0
    
    print_status "🔍 Checking security status..."
    
    # Check for hardcoded secrets
    if find infrastructure/ -name "*.tf" -o -name "*.tfvars" | xargs grep "password.*=" | grep -v "password.*=.*var\." | grep -v "password.*=.*data\." | grep -v "password.*=.*null" | grep -v "variable.*password" | grep -v "type.*=" | grep -v "description.*password" | grep -v "sensitive.*=" | grep -q '"[^"]*"'; then
        errors=$((errors + 1))
    fi
    
    # Check for placeholder values
    if find infrastructure/ -name "*.tf" -o -name "*.tfvars" | xargs grep "your-.*-here" | grep -q .; then
        errors=$((errors + 1))
    fi
    
    # Check for hardcoded API keys
    if find infrastructure/ -name "*.tf" -o -name "*.tfvars" | xargs grep "api.*key.*=" | grep -v "api.*key.*=.*var\." | grep -v "api.*key.*=.*data\." | grep -v "api.*key.*=.*null" | grep -v "variable.*api" | grep -v "type.*=" | grep -v "description.*api" | grep -q '"[^"]*"'; then
        errors=$((errors + 1))
    fi
    
    # Check for hardcoded secrets
    if find infrastructure/ -name "*.tf" -o -name "*.tfvars" | xargs grep "secret.*=" | grep -v "secret.*=.*var\." | grep -v "secret.*=.*data\." | grep -v "secret.*=.*null" | grep -v "variable.*secret" | grep -v "type.*=" | grep -v "description.*secret" | grep -v "sensitive.*=" | grep -v 'secret.*=.*"[^"]*secret[^"]*"' | grep -v 'secret.*=.*"[^"]*-[^"]*"' | grep -q '"[^"]*"'; then
        errors=$((errors + 1))
    fi
    
    # Check for magic numbers (excluding variable defaults and validation)
    local magic_count=$(find infrastructure/ -name "*.tf" -o -name "*.tfvars" | xargs grep "=\s*[0-9]\+[^a-zA-Z]" | grep -v "required_version" | grep -v "port.*=.*80" | grep -v "port.*=.*443" | grep -v "port.*=.*22" | grep -v "default.*=" | grep -v "condition.*=" | grep -v "validation" | grep -v "priority.*=.*1000" | grep -v "prefix_length.*=.*16" | wc -l)
    if [ "$magic_count" -gt 0 ]; then
        warnings=$((warnings + 1))
    fi
    
    # Check for validation rules
    local validation_count=$(find infrastructure/ -name "*.tf" -o -name "*.tfvars" | xargs grep "validation" | wc -l)
    if [ "$validation_count" -lt 10 ]; then
        warnings=$((warnings + 1))
    fi
    
    # Check for documentation
    if [ ! -f "SECURITY.md" ] || [ ! -f "DEPLOYMENT-CHECKLIST.md" ]; then
        warnings=$((warnings + 1))
    fi
    
    # Check for security scripts
    if [ ! -f "scripts/security/validate-secrets.sh" ] || [ ! -f "scripts/security/validate-secrets.ps1" ]; then
        warnings=$((warnings + 1))
    fi
    
    # Determine overall status
    if [ $errors -eq 0 ] && [ $warnings -eq 0 ]; then
        echo "EXCELLENT"
        return 0
    elif [ $errors -eq 0 ] && [ $warnings -le 2 ]; then
        echo "GOOD"
        return 0
    elif [ $errors -eq 0 ]; then
        echo "FAIR"
        return 0
    else
        echo "POOR"
        return 0
    fi
}

# Function to generate badge
generate_badge() {
    local status=$1
    local color
    local message
    
    case $status in
        "EXCELLENT")
            color="brightgreen"
            message="Security%20Excellent"
            ;;
        "GOOD")
            color="green"
            message="Security%20Good"
            ;;
        "FAIR")
            color="yellow"
            message="Security%20Fair"
            ;;
        "POOR")
            color="red"
            message="Security%20Poor"
            ;;
        *)
            color="lightgrey"
            message="Security%20Unknown"
            ;;
    esac
    
    local badge_url="https://img.shields.io/badge/${message}-${color}"
    echo "$badge_url"
}

# Function to generate detailed status
generate_detailed_status() {
    local status=$1
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    cat << EOF
{
  "status": "$status",
  "timestamp": "$timestamp",
  "checks": {
    "hardcoded_secrets": $(find infrastructure/ -name "*.tf" -o -name "*.tfvars" | xargs grep "password.*=" | grep -v "password.*=.*var\." | grep -v "password.*=.*data\." | grep -v "password.*=.*null" | grep -v "variable.*password" | grep -v "type.*=" | grep -v "description.*password" | grep -v "sensitive.*=" | grep -q '"[^"]*"' && echo "false" || echo "true"),
    "placeholder_values": $(find infrastructure/ -name "*.tf" -o -name "*.tfvars" | xargs grep "your-.*-here" | grep -q . && echo "false" || echo "true"),
    "hardcoded_api_keys": $(find infrastructure/ -name "*.tf" -o -name "*.tfvars" | xargs grep "api.*key.*=" | grep -v "api.*key.*=.*var\." | grep -v "api.*key.*=.*data\." | grep -v "api.*key.*=.*null" | grep -v "variable.*api" | grep -v "type.*=" | grep -v "description.*api" | grep -q '"[^"]*"' && echo "false" || echo "true"),
    "hardcoded_secrets": $(find infrastructure/ -name "*.tf" -o -name "*.tfvars" | xargs grep "secret.*=" | grep -v "secret.*=.*var\." | grep -v "secret.*=.*data\." | grep -v "secret.*=.*null" | grep -v "variable.*secret" | grep -v "type.*=" | grep -v "description.*secret" | grep -v "sensitive.*=" | grep -v 'secret.*=.*"[^"]*secret[^"]*"' | grep -v 'secret.*=.*"[^"]*-[^"]*"' | grep -q '"[^"]*"' && echo "false" || echo "true"),
    "magic_numbers": $(find infrastructure/ -name "*.tf" -o -name "*.tfvars" | xargs grep "=\s*[0-9]\+[^a-zA-Z]" | grep -v "required_version" | grep -v "port.*=.*80" | grep -v "port.*=.*443" | grep -v "port.*=.*22" | grep -v "default.*=" | grep -v "condition.*=" | grep -v "validation" | grep -v "priority.*=.*1000" | grep -v "prefix_length.*=.*16" | wc -l),
    "validation_rules": $(find infrastructure/ -name "*.tf" -o -name "*.tfvars" | xargs grep "validation" | wc -l),
    "documentation": $([ -f "SECURITY.md" ] && [ -f "DEPLOYMENT-CHECKLIST.md" ] && echo "true" || echo "false"),
    "security_scripts": $([ -f "scripts/security/validate-secrets.sh" ] && [ -f "scripts/security/validate-secrets.ps1" ] && echo "true" || echo "false")
  },
  "version": "1.1.0",
  "last_updated": "$timestamp"
}
EOF
}

# Main function
main() {
    print_status "🚀 Generating dynamic status badge for Terraform GCP infrastructure..."
    
    # Check security status
    local security_status
    security_status=$(check_security_status 2>/dev/null | tail -1)
    local exit_code=$?
    
    # Generate badge URL
    local badge_url
    badge_url=$(generate_badge "$security_status")
    
    # Generate detailed status
    local detailed_status
    detailed_status=$(generate_detailed_status "$security_status")
    
    # Output results
    echo ""
    print_status "📊 Security Status: $security_status"
    echo ""
    print_status "🏷️  Badge URL:"
    echo "   $badge_url"
    echo ""
    print_status "📋 Markdown Badge:"
    echo "   ![Security Status]($badge_url)"
    echo ""
    print_status "📄 Detailed Status:"
    echo "$detailed_status" | jq '.' 2>/dev/null || echo "$detailed_status"
    echo ""
    
    # Save badge URL to file
    echo "$badge_url" > .security-badge-url
    echo "$detailed_status" > .security-status.json
    
    # Update README if badge exists
    if [ -f "README.md" ]; then
        if grep -q "Security Status" README.md; then
            print_status "📝 Updating README.md with new badge..."
            sed -i.bak "s|https://img.shields.io/badge/Security%20[^)]*|$badge_url|g" README.md
            rm -f README.md.bak
            print_success "README.md updated with new security badge"
        else
            print_warning "Security badge not found in README.md - add manually if needed"
        fi
    fi
    
    # Summary
    case $exit_code in
        0)
            print_success "🎉 Security status: EXCELLENT - All checks passed!"
            ;;
        1)
            print_success "✅ Security status: GOOD - Minor improvements possible"
            ;;
        2)
            print_warning "⚠️  Security status: FAIR - Some improvements needed"
            ;;
        3)
            print_error "❌ Security status: POOR - Critical issues found"
            ;;
    esac
    
    echo ""
    print_status "💡 To use the badge in your README.md, add:"
    echo "   ![Security Status]($badge_url)"
    echo ""
    print_status "📁 Badge URL saved to: .security-badge-url"
    print_status "📁 Detailed status saved to: .security-status.json"
}

# Run main function
main "$@"
