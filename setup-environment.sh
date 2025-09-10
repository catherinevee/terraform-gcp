#!/bin/bash
# Environment Setup Script for Terraform-GCP Implementation
# Run this script to configure your environment variables

echo "🚀 Setting up Terraform-GCP Environment Configuration"
echo "=================================================="

# Check if running on Windows
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
    echo "Windows detected. Please set these environment variables manually:"
    echo ""
    echo "set PROJECT_ID=your-project-id"
    echo "set ENVIRONMENT=dev"
    echo "set REGION=us-central1"
    echo "set ZONE=us-central1-a"
    echo ""
    echo "Or use PowerShell:"
    echo "\$env:PROJECT_ID='your-project-id'"
    echo "\$env:ENVIRONMENT='dev'"
    echo "\$env:REGION='us-central1'"
    echo "\$env:ZONE='us-central1-a'"
else
    # Unix/Linux/MacOS
    echo "Please update the following environment variables:"
    echo ""
    echo "export PROJECT_ID=\"your-project-id\""
    echo "export ENVIRONMENT=\"dev\""
    echo "export REGION=\"us-central1\""
    echo "export ZONE=\"us-central1-a\""
    echo ""
    echo "You can add these to your ~/.bashrc or ~/.zshrc file"
fi

echo ""
echo "📋 Next Steps:"
echo "1. Update PROJECT_ID with your actual GCP project ID"
echo "2. Set the environment variables above"
echo "3. Run: ./scripts/automation/phase-deployment.sh -p \$PROJECT_ID -e \$ENVIRONMENT 0"
echo ""
echo "🔧 Prerequisites Check:"
echo "- GCP CLI authenticated: $(gcloud auth list --filter=status:ACTIVE --format='value(account)' | head -1)"
echo "- Current project: $(gcloud config get-value project)"
echo "- Terraform installed: $(command -v terraform >/dev/null 2>&1 && echo 'Yes' || echo 'No')"
echo "- jq installed: $(command -v jq >/dev/null 2>&1 && echo 'Yes' || echo 'No')"
echo ""
echo "✅ Environment setup complete!"
