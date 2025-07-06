#!/bin/bash

# Proxmox K3s Infrastructure Validation Script
# Validates the Terraform configuration using bpg/proxmox provider

set -e

echo "🔍 Validating Proxmox K3s Infrastructure Configuration..."
echo "========================================================"

# Check if we're in the right directory
if [ ! -f "terraform.tfvars" ]; then
    echo "❌ Error: terraform.tfvars not found. Please run from terraform/ directory."
    exit 1
fi

# Check if terraform.tfvars is configured
if grep -q "your-proxmox-server" terraform.tfvars 2>/dev/null; then
    echo "⚠️  Warning: terraform.tfvars still contains placeholder values."
    echo "   Please update with your actual Proxmox configuration."
fi

# Initialize Terraform
echo "🔧 Initializing Terraform..."
terraform init

# Validate configuration
echo "✅ Validating Terraform configuration..."
terraform validate

# Format check
echo "🎨 Checking Terraform formatting..."
terraform fmt -check

# Plan with dry-run
echo "📋 Running Terraform plan..."
terraform plan -var-file=terraform.tfvars -out=tfplan

echo ""
echo "✅ Configuration validation complete!"
echo "🚀 Ready to deploy with: terraform apply tfplan"
echo ""
echo "📊 Resources planned:"
terraform show -json tfplan | jq -r '.planned_values.root_module.resources[] | .type' | sort | uniq -c
