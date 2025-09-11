# Security Status Badge System

This directory contains tools for generating and serving dynamic security status badges for the Terraform GCP infrastructure project.

## 🏷️ Badge Generation

### Scripts

- **`generate-status-badge.sh`** - Bash script for Linux/Mac
- **`generate-status-badge.ps1`** - PowerShell script for Windows
- **`validate-secrets.sh`** - Security validation script (Bash)
- **`validate-secrets.ps1`** - Security validation script (PowerShell)

### Usage

#### Generate Badge (Linux/Mac)
```bash
./scripts/security/generate-status-badge.sh
```

#### Generate Badge (Windows)
```powershell
.\scripts\security\generate-status-badge.ps1
```

#### Update README Automatically
```powershell
.\scripts\security\generate-status-badge.ps1 -UpdateReadme
```

### Output

The scripts generate:
- **`.security-badge-url`** - Badge URL for shields.io
- **`.security-status.json`** - Detailed status information

## 🌐 Badge Server

### Local Development Server

Start the badge server for local development:

```bash
cd scripts/security
npm install
npm start
```

The server will be available at:
- **Badge**: http://localhost:3000/badge
- **Status API**: http://localhost:3000/status
- **Web Interface**: http://localhost:3000/

### API Endpoints

- **`GET /badge`** - Redirects to shields.io badge
- **`GET /badge/:status`** - Custom status badge
- **`GET /status`** - JSON status data
- **`GET /`** - HTML status page
- **`GET /health`** - Health check

## 🔍 Security Checks

The badge system evaluates the following security criteria:

### Critical Checks
- **Hardcoded Passwords**: No hardcoded passwords in code
- **Placeholder Values**: No "your-*-here" placeholder values
- **Hardcoded API Keys**: No hardcoded API keys
- **Hardcoded Secrets**: No hardcoded secrets

### Quality Checks
- **Magic Numbers**: Count of hardcoded numbers that should be variables
- **Validation Rules**: Number of input validation rules
- **Documentation**: Presence of security documentation
- **Security Scripts**: Availability of validation scripts

## 📊 Status Levels

- **🟢 EXCELLENT**: All checks pass, no issues found
- **🔵 GOOD**: Minor improvements possible, no critical issues
- **🟡 FAIR**: Some improvements needed, no critical issues
- **🔴 POOR**: Critical security issues found

## 🚀 GitHub Actions Integration

The badge system integrates with GitHub Actions via `.github/workflows/security-badge.yml`:

- **Automatic Updates**: Badge updates on code changes
- **PR Comments**: Security status comments on pull requests
- **Scheduled Runs**: Daily status checks
- **Manual Triggers**: On-demand badge generation

## 📝 Usage in Documentation

### Markdown Badge
```markdown
![Security Status](https://img.shields.io/badge/Security%20Good-green)
```

### Dynamic Badge (via server)
```markdown
![Security Status](http://localhost:3000/badge)
```

### Custom Status Badge
```markdown
![Security Status](http://localhost:3000/badge/EXCELLENT)
```

## 🔧 Configuration

### Environment Variables

- **`PORT`** - Server port (default: 3000)
- **`CACHE_DURATION`** - Badge cache duration in milliseconds (default: 5 minutes)

### Customization

To customize the badge system:

1. **Modify Security Checks**: Edit the validation logic in the generation scripts
2. **Add New Checks**: Extend the `check_security_status()` function
3. **Custom Badge Colors**: Update the `getBadgeColor()` function
4. **Status Criteria**: Adjust the status determination logic

## 📚 Examples

### Generate and Display Badge
```bash
# Generate badge
./scripts/security/generate-status-badge.sh

# Display badge URL
cat .security-badge-url

# View detailed status
cat .security-status.json | jq '.'
```

### Start Badge Server
```bash
cd scripts/security
npm install
npm start
```

### Test Badge Endpoints
```bash
# Get badge
curl http://localhost:3000/badge

# Get status data
curl http://localhost:3000/status

# Health check
curl http://localhost:3000/health
```

## 🛠️ Development

### Prerequisites

- **Node.js** 16.0.0 or higher
- **npm** or **yarn**
- **Terraform** 1.5.0 or higher
- **Bash** or **PowerShell**

### Local Development

```bash
# Install dependencies
npm install

# Start development server with auto-reload
npm run dev

# Run security validation
./validate-secrets.sh
```

### Testing

```bash
# Test badge generation
./generate-status-badge.sh

# Test server endpoints
curl http://localhost:3000/status
```

## 📋 Troubleshooting

### Common Issues

1. **Script Permission Denied**
   ```bash
   chmod +x scripts/security/*.sh
   ```

2. **PowerShell Execution Policy**
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser
   ```

3. **Node.js Not Found**
   ```bash
   # Install Node.js from https://nodejs.org/
   # Or use nvm: nvm install 16
   ```

4. **Terraform Not Found**
   ```bash
   # Install Terraform from https://terraform.io/downloads
   ```

### Debug Mode

Enable verbose output:
```bash
# Bash
./generate-status-badge.sh 2>&1 | tee debug.log

# PowerShell
.\generate-status-badge.ps1 -Verbose
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](../../LICENSE) file for details.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test the badge generation
5. Submit a pull request

## 📞 Support

For issues and questions:
- **Documentation**: [SECURITY.md](../../SECURITY.md)
- **Issues**: [GitHub Issues](https://github.com/catherinevee/terraform-gcp/issues)
- **Email**: platform-engineering@cataziza-corp.com

---

**Last Updated**: September 2025  
**Version**: 1.1.0  
**Maintainer**: Platform Engineering Team
