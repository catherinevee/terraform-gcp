#!/usr/bin/env node

/**
 * Dynamic Badge Generator for Terraform GCP Infrastructure
 * Generates multiple dynamic badges including health, deployment, and version info
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Badge configuration
const BADGE_CONFIG = {
    health: {
        healthy: { color: '#28a745', text: 'HEALTHY', label: 'Infrastructure' },
        degraded: { color: '#ffc107', text: 'DEGRADED', label: 'Infrastructure', textColor: '#000000' },
        unhealthy: { color: '#dc3545', text: 'UNHEALTHY', label: 'Infrastructure' },
        unknown: { color: '#6c757d', text: 'UNKNOWN', label: 'Infrastructure' }
    },
    deployment: {
        live: { color: '#28a745', text: 'LIVE', label: 'Deployment' },
        partial: { color: '#ffc107', text: 'PARTIAL', label: 'Deployment', textColor: '#000000' },
        unalive: { color: '#dc3545', text: 'UNALIVE', label: 'Deployment' },
        unknown: { color: '#6c757d', text: 'UNKNOWN', label: 'Deployment' }
    }
};

/**
 * Generate SVG badge
 */
function generateBadge(config) {
    const { color, text, label, textColor = '#ffffff' } = config;
    
    // Calculate text width (approximate)
    const textWidth = text.length * 6 + 10;
    const labelWidth = label.length * 6 + 10;
    const totalWidth = labelWidth + textWidth;
    
    return `<svg xmlns="http://www.w3.org/2000/svg" width="${totalWidth}" height="20">
    <linearGradient id="b" x2="0" y2="100%">
        <stop offset="0" stop-color="#bbb" stop-opacity=".1"/>
        <stop offset="1" stop-opacity=".1"/>
    </linearGradient>
    <mask id="a">
        <rect width="${totalWidth}" height="20" rx="3" fill="#fff"/>
    </mask>
    <g mask="url(#a)">
        <path fill="#555" d="M0 0h${labelWidth}v20H0z"/>
        <path fill="${color}" d="M${labelWidth} 0h${textWidth}v20H${labelWidth}z"/>
    </g>
    <g fill="#fff" text-anchor="middle" font-family="DejaVu Sans,Verdana,Geneva,sans-serif" font-size="11">
        <text x="${labelWidth / 2}" y="14">${label}</text>
        <text x="${labelWidth + textWidth / 2}" y="14">${text}</text>
    </g>
</svg>`;
}

/**
 * Check infrastructure health
 */
function checkInfrastructureHealth() {
    try {
        // Check if terraform configurations are valid
        const result = execSync('terraform validate -json', { 
            encoding: 'utf8',
            cwd: 'infrastructure/environments/dev/global'
        });
        
        const validation = JSON.parse(result);
        if (validation.valid && validation.error_count === 0) {
            return 'healthy';
        } else if (validation.error_count > 0) {
            return 'unhealthy';
        } else {
            return 'degraded';
        }
    } catch (error) {
        console.error('Health check failed:', error.message);
        return 'unknown';
    }
}

/**
 * Get Terraform version
 */
function getTerraformVersion() {
    try {
        const result = execSync('terraform version -json', { encoding: 'utf8' });
        const versionInfo = JSON.parse(result);
        return versionInfo.terraform_version || 'unknown';
    } catch (error) {
        console.error('Failed to get Terraform version:', error.message);
        return 'unknown';
    }
}

/**
 * Get GCP provider version
 */
function getGCPProviderVersion() {
    try {
        const result = execSync('terraform version -json', { encoding: 'utf8' });
        const versionInfo = JSON.parse(result);
        const providers = versionInfo.provider_selections || {};
        const gcpProvider = Object.keys(providers).find(key => key.includes('hashicorp/google'));
        return gcpProvider ? providers[gcpProvider] : 'unknown';
    } catch (error) {
        console.error('Failed to get GCP provider version:', error.message);
        return 'unknown';
    }
}

/**
 * Check deployment status
 */
function checkDeploymentStatus() {
    try {
        // Check if there are any running deployments
        const result = execSync('gh api repos/catherinevee/terraform-gcp/deployments --jq ".[0].state"', { 
            encoding: 'utf8',
            cwd: process.cwd()
        });
        
        const status = result.trim();
        if (status === 'active') return 'live';
        if (status === 'pending') return 'partial';
        if (status === 'inactive') return 'unalive';
        return 'unknown';
    } catch (error) {
        console.error('Deployment check failed:', error.message);
        return 'unknown';
    }
}

/**
 * Generate version badge
 */
function generateVersionBadge(version, label) {
    const color = version === 'unknown' ? '#6c757d' : '#17a2b8';
    return generateBadge({ color, text: version, label });
}

/**
 * Generate all dynamic badges
 */
function generateAllDynamicBadges() {
    const outputDir = 'docs/status';
    
    // Create output directory if it doesn't exist
    if (!fs.existsSync(outputDir)) {
        fs.mkdirSync(outputDir, { recursive: true });
    }
    
    console.log(' Generating dynamic badges...');
    
    // Generate infrastructure health badge
    const healthStatus = checkInfrastructureHealth();
    const healthConfig = BADGE_CONFIG.health[healthStatus] || BADGE_CONFIG.health.unknown;
    const healthSvg = generateBadge(healthConfig);
    fs.writeFileSync(path.join(outputDir, 'health.svg'), healthSvg);
    console.log(` Generated health badge: ${healthStatus.toUpperCase()}`);
    
    // Generate deployment status badge
    const deploymentStatus = checkDeploymentStatus();
    const deploymentConfig = BADGE_CONFIG.deployment[deploymentStatus] || BADGE_CONFIG.deployment.unknown;
    const deploymentSvg = generateBadge(deploymentConfig);
    fs.writeFileSync(path.join(outputDir, 'deployment.svg'), deploymentSvg);
    console.log(` Generated deployment badge: ${deploymentStatus.toUpperCase()}`);
    
    // Generate Terraform version badge
    const terraformVersion = getTerraformVersion();
    const terraformSvg = generateVersionBadge(terraformVersion, 'Terraform');
    fs.writeFileSync(path.join(outputDir, 'terraform-version.svg'), terraformSvg);
    console.log(` Generated Terraform version badge: ${terraformVersion}`);
    
    // Generate GCP provider version badge
    const gcpVersion = getGCPProviderVersion();
    const gcpSvg = generateVersionBadge(gcpVersion, 'GCP');
    fs.writeFileSync(path.join(outputDir, 'gcp-version.svg'), gcpSvg);
    console.log(` Generated GCP version badge: ${gcpVersion}`);
    
    console.log('\n All dynamic badges generated successfully!');
    console.log('\nBadge URLs:');
    console.log('  - Health: https://catherinevee.github.io/terraform-gcp/status/health.svg');
    console.log('  - Deployment: https://catherinevee.github.io/terraform-gcp/status/deployment.svg');
    console.log('  - Terraform: https://catherinevee.github.io/terraform-gcp/status/terraform-version.svg');
    console.log('  - GCP: https://catherinevee.github.io/terraform-gcp/status/gcp-version.svg');
}

// Run if called directly
if (require.main === module) {
    generateAllDynamicBadges();
}

module.exports = { generateBadge, generateAllDynamicBadges };
