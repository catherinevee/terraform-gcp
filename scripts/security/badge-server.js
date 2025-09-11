#!/usr/bin/env node

/**
 * Dynamic Security Badge Server
 * Serves a dynamic security status badge for the Terraform GCP infrastructure
 */

const express = require('express');
const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

// Cache for badge data
let badgeCache = null;
let cacheTimestamp = null;
const CACHE_DURATION = 5 * 60 * 1000; // 5 minutes

/**
 * Generate security status badge
 */
function generateBadge() {
    try {
        // Check if we're in the right directory
        if (!fs.existsSync('infrastructure')) {
            throw new Error('infrastructure directory not found');
        }

        // Run the badge generation script
        const scriptPath = path.join(__dirname, 'generate-status-badge.sh');
        if (fs.existsSync(scriptPath)) {
            execSync(`chmod +x "${scriptPath}" && "${scriptPath}"`, { stdio: 'pipe' });
        } else {
            // Fallback: run PowerShell script on Windows
            const psScriptPath = path.join(__dirname, 'generate-status-badge.ps1');
            if (fs.existsSync(psScriptPath)) {
                execSync(`powershell -ExecutionPolicy Bypass -File "${psScriptPath}"`, { stdio: 'pipe' });
            } else {
                throw new Error('Badge generation scripts not found');
            }
        }

        // Read the generated status
        const statusFile = '.security-status.json';
        const badgeFile = '.security-badge-url';
        
        if (fs.existsSync(statusFile) && fs.existsSync(badgeFile)) {
            const statusData = JSON.parse(fs.readFileSync(statusFile, 'utf8'));
            const badgeUrl = fs.readFileSync(badgeFile, 'utf8').trim();
            
            return {
                status: statusData.status,
                badgeUrl: badgeUrl,
                timestamp: statusData.timestamp,
                checks: statusData.checks,
                version: statusData.version
            };
        } else {
            throw new Error('Status files not generated');
        }
    } catch (error) {
        console.error('Error generating badge:', error.message);
        
        // Return fallback status
        return {
            status: 'UNKNOWN',
            badgeUrl: 'https://img.shields.io/badge/Security%20Unknown-lightgrey',
            timestamp: new Date().toISOString(),
            checks: {
                hardcoded_passwords: false,
                placeholder_values: false,
                hardcoded_api_keys: false,
                hardcoded_secrets: false,
                magic_numbers: 0,
                validation_rules: 0,
                documentation: false,
                security_scripts: false
            },
            version: '1.1.0'
        };
    }
}

/**
 * Get badge data (with caching)
 */
function getBadgeData() {
    const now = Date.now();
    
    if (!badgeCache || !cacheTimestamp || (now - cacheTimestamp) > CACHE_DURATION) {
        badgeCache = generateBadge();
        cacheTimestamp = now;
    }
    
    return badgeCache;
}

/**
 * Get badge color based on status
 */
function getBadgeColor(status) {
    switch (status.toLowerCase()) {
        case 'excellent': return 'brightgreen';
        case 'good': return 'green';
        case 'fair': return 'yellow';
        case 'poor': return 'red';
        default: return 'lightgrey';
    }
}

// Routes

/**
 * Serve the main badge image
 */
app.get('/badge', (req, res) => {
    const badgeData = getBadgeData();
    const color = getBadgeColor(badgeData.status);
    const message = `Security%20${badgeData.status}`;
    
    // Redirect to shields.io badge
    const badgeUrl = `https://img.shields.io/badge/${message}-${color}`;
    res.redirect(badgeUrl);
});

/**
 * Serve badge with custom parameters
 */
app.get('/badge/:status', (req, res) => {
    const { status } = req.params;
    const color = getBadgeColor(status);
    const message = `Security%20${status}`;
    
    const badgeUrl = `https://img.shields.io/badge/${message}-${color}`;
    res.redirect(badgeUrl);
});

/**
 * Serve JSON status data
 */
app.get('/status', (req, res) => {
    const badgeData = getBadgeData();
    res.json(badgeData);
});

/**
 * Serve HTML status page
 */
app.get('/', (req, res) => {
    const badgeData = getBadgeData();
    const color = getBadgeColor(badgeData.status);
    const message = `Security%20${badgeData.status}`;
    const badgeUrl = `https://img.shields.io/badge/${message}-${color}`;
    
    const html = `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Security Status - Terraform GCP Infrastructure</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            background: white;
            border-radius: 8px;
            padding: 30px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        .header {
            text-align: center;
            margin-bottom: 30px;
        }
        .badge {
            display: inline-block;
            margin: 10px;
        }
        .status-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin: 20px 0;
        }
        .status-item {
            padding: 15px;
            border-radius: 6px;
            border-left: 4px solid;
        }
        .status-item.pass {
            background-color: #d4edda;
            border-left-color: #28a745;
        }
        .status-item.fail {
            background-color: #f8d7da;
            border-left-color: #dc3545;
        }
        .status-item.warning {
            background-color: #fff3cd;
            border-left-color: #ffc107;
        }
        .timestamp {
            text-align: center;
            color: #6c757d;
            font-size: 0.9em;
            margin-top: 20px;
        }
        .refresh-btn {
            background-color: #007bff;
            color: white;
            border: none;
            padding: 10px 20px;
            border-radius: 4px;
            cursor: pointer;
            margin: 10px;
        }
        .refresh-btn:hover {
            background-color: #0056b3;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔒 Security Status</h1>
            <h2>Terraform GCP Infrastructure</h2>
            <div class="badge">
                <img src="${badgeUrl}" alt="Security Status: ${badgeData.status}" />
            </div>
            <br>
            <button class="refresh-btn" onclick="location.reload()">🔄 Refresh Status</button>
        </div>
        
        <div class="status-grid">
            <div class="status-item ${badgeData.checks.hardcoded_passwords ? 'pass' : 'fail'}">
                <strong>Hardcoded Passwords</strong><br>
                ${badgeData.checks.hardcoded_passwords ? '✅ No hardcoded passwords found' : '❌ Hardcoded passwords detected'}
            </div>
            <div class="status-item ${badgeData.checks.placeholder_values ? 'pass' : 'fail'}">
                <strong>Placeholder Values</strong><br>
                ${badgeData.checks.placeholder_values ? '✅ No placeholder values found' : '❌ Placeholder values detected'}
            </div>
            <div class="status-item ${badgeData.checks.hardcoded_api_keys ? 'pass' : 'fail'}">
                <strong>Hardcoded API Keys</strong><br>
                ${badgeData.checks.hardcoded_api_keys ? '✅ No hardcoded API keys found' : '❌ Hardcoded API keys detected'}
            </div>
            <div class="status-item ${badgeData.checks.hardcoded_secrets ? 'pass' : 'fail'}">
                <strong>Hardcoded Secrets</strong><br>
                ${badgeData.checks.hardcoded_secrets ? '✅ No hardcoded secrets found' : '❌ Hardcoded secrets detected'}
            </div>
            <div class="status-item ${badgeData.checks.magic_numbers === 0 ? 'pass' : 'warning'}">
                <strong>Magic Numbers</strong><br>
                ${badgeData.checks.magic_numbers} magic numbers found
            </div>
            <div class="status-item ${badgeData.checks.validation_rules >= 10 ? 'pass' : 'warning'}">
                <strong>Validation Rules</strong><br>
                ${badgeData.checks.validation_rules} validation rules configured
            </div>
            <div class="status-item ${badgeData.checks.documentation ? 'pass' : 'fail'}">
                <strong>Documentation</strong><br>
                ${badgeData.checks.documentation ? '✅ Security documentation complete' : '❌ Security documentation missing'}
            </div>
            <div class="status-item ${badgeData.checks.security_scripts ? 'pass' : 'fail'}">
                <strong>Security Scripts</strong><br>
                ${badgeData.checks.security_scripts ? '✅ Security validation scripts available' : '❌ Security validation scripts missing'}
            </div>
        </div>
        
        <div class="timestamp">
            Last updated: ${new Date(badgeData.timestamp).toLocaleString()}
        </div>
    </div>
</body>
</html>
    `;
    
    res.send(html);
});

/**
 * Health check endpoint
 */
app.get('/health', (req, res) => {
    res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

// Start server
app.listen(PORT, () => {
    console.log(`🔒 Security Badge Server running on port ${PORT}`);
    console.log(`📊 Badge URL: http://localhost:${PORT}/badge`);
    console.log(`📋 Status API: http://localhost:${PORT}/status`);
    console.log(`🌐 Web Interface: http://localhost:${PORT}/`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('🛑 Shutting down security badge server...');
    process.exit(0);
});

process.on('SIGINT', () => {
    console.log('🛑 Shutting down security badge server...');
    process.exit(0);
});
