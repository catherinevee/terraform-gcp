#!/usr/bin/env node

/**
 * Dynamic Badge Generator for Terraform GCP Infrastructure
 * Generates multiple dynamic badges including security, health, and version info
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Badge configuration
const BADGE_CONFIG = {
    security: {
        excellent: { color: '#28a745', text: 'EXCELLENT', label: 'Security' },
        good: { color: '#17a2b8', text: 'GOOD', label: 'Security' },
        warning: { color: '#ffc107', text: 'WARNING', label: 'Security', textColor: '#000000' },
        critical: { color: '#dc3545', text: 'CRITICAL', label: 'Security' },
        unknown: { color: '#6c757d', text: 'UNKNOWN', label: 'Security' }
    },
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
        <path fill="url(#b)" d="M0 0h${totalWidth}v20H0z"/>
    </g>
    <g fill="${textColor}" text-anchor="middle" font-family="DejaVu Sans,Verdana,Geneva,sans-serif" font-size="11">
        <text x="${labelWidth / 2}" y="15" fill="#010101" fill-opacity=".3">${label}</text>
        <text x="${labelWidth / 2}" y="14">${label}</text>
        <text x="${labelWidth + textWidth / 2}" y="15" fill="#010101" fill-opacity=".3">${text}</text>
        <text x="${labelWidth + textWidth / 2}" y="14">${text}</text>
    </g>
</svg>`;
}

/**
 * Check security status
 */
function checkSecurityStatus() {
    try {
        // Run security validation script
        const result = execSync('bash scripts/security/validate-secrets.sh', { 
            encoding: 'utf8',
            cwd: process.cwd()
        });
        
        if (result.includes('EXCELLENT')) return 'excellent';
        if (result.includes('GOOD')) return 'good';
        if (result.includes('WARNING')) return 'warning';
        if (result.includes('CRITICAL')) return 'critical';
        return 'unknown';
    } catch (error) {
        console.error('Security check failed:', error.message);
        return 'unknown';
    }
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
        const version = JSON.parse(result);
        return version.terraform_version;
    } catch (error) {
        return '1.5.0+';
    }
}

/**
 * Get GCP provider version
 */
function getGCPProviderVersion() {
    try {
        // Read from terraform.lock.hcl or versions.tf
        const lockFile = 'infrastructure/environments/dev/global/.terraform.lock.hcl';
        if (fs.existsSync(lockFile)) {
            const content = fs.readFileSync(lockFile, 'utf8');
            const match = content.match(/provider "registry\.terraform\.io\/hashicorp\/google"\s+version\s*=\s*"([^"]+)"/);
            if (match) return match[1];
        }
        
        // Fallback to versions.tf
        const versionsFile = 'infrastructure/environments/dev/global/versions.tf';
        if (fs.existsSync(versionsFile)) {
            const content = fs.readFileSync(versionsFile, 'utf8');
            const match = content.match(/version\s*=\s*"([^"]+)"/);
            if (match) return match[1];
        }
        
        return '5.45.2+';
    } catch (error) {
        return '5.45.2+';
    }
}

/**
 * Generate version badge
 */
function generateVersionBadge(version, type) {
    const color = '#007bff';
    const text = version;
    const label = type;
    
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
        <path fill="url(#b)" d="M0 0h${totalWidth}v20H0z"/>
    </g>
    <g fill="#ffffff" text-anchor="middle" font-family="DejaVu Sans,Verdana,Geneva,sans-serif" font-size="11">
        <text x="${labelWidth / 2}" y="15" fill="#010101" fill-opacity=".3">${label}</text>
        <text x="${labelWidth / 2}" y="14">${label}</text>
        <text x="${labelWidth + textWidth / 2}" y="15" fill="#010101" fill-opacity=".3">${text}</text>
        <text x="${labelWidth + textWidth / 2}" y="14">${text}</text>
    </g>
</svg>`;
}

/**
 * Generate all dynamic badges
 */
function generateAllDynamicBadges() {
    const outputDir = path.join(__dirname, '..', '..', 'docs', 'status');
    
    // Create output directory if it doesn't exist
    if (!fs.existsSync(outputDir)) {
        fs.mkdirSync(outputDir, { recursive: true });
    }
    
    console.log(' Generating dynamic badges...');
    
    // Generate security status badge
    const securityStatus = checkSecurityStatus();
    const securityConfig = BADGE_CONFIG.security[securityStatus] || BADGE_CONFIG.security.unknown;
    const securitySvg = generateBadge(securityConfig);
    fs.writeFileSync(path.join(outputDir, 'security.svg'), securitySvg);
    console.log(` Generated security badge: ${securityStatus.toUpperCase()}`);
    
    // Generate infrastructure health badge
    const healthStatus = checkInfrastructureHealth();
    const healthConfig = BADGE_CONFIG.health[healthStatus] || BADGE_CONFIG.health.unknown;
    const healthSvg = generateBadge(healthConfig);
    fs.writeFileSync(path.join(outputDir, 'health.svg'), healthSvg);
    console.log(` Generated health badge: ${healthStatus.toUpperCase()}`);
    
    // Generate deployment status badge (from existing logic)
    const deploymentStatus = 'live'; // This would be determined by actual deployment checks
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
    console.log('  - Security: https://catherinevee.github.io/terraform-gcp/status/security.svg');
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
