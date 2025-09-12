# Terratest Quick Start Guide

## Overview

This guide provides a quick start for implementing Terratest in the terraform-gcp project. Follow these steps to get started with infrastructure testing.

## Prerequisites

- Go 1.21 or later
- Terraform 1.9.0 or later
- Google Cloud SDK
- GCP project with appropriate permissions

## Quick Setup

### 1. Initialize Test Structure

```bash
# Create test directory structure
mkdir -p tests/{unit,integration,e2e,fixtures,testhelpers}
mkdir -p tests/unit/{compute,database,networking,security,storage,monitoring,data}
mkdir -p tests/integration/{dev,staging,prod}

# Initialize Go module
cd tests
go mod init github.com/catherinevee/terraform-gcp/tests
```

### 2. Install Dependencies

```bash
# Install Terratest and dependencies
go get github.com/gruntwork-io/terratest@v0.46.0
go get github.com/stretchr/testify@v1.8.4
go get github.com/GoogleCloudPlatform/cloud-sql-proxy@v1.33.0
go mod tidy
```

### 3. Create Basic Test

```go
// tests/unit/networking/vpc_test.go
package networking

import (
    "testing"
    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/gruntwork-io/terratest/modules/gcp"
    "github.com/stretchr/testify/assert"
)

func TestVPCModule(t *testing.T) {
    terraformOptions := &terraform.Options{
        TerraformDir: "../../../infrastructure/modules/networking/vpc",
        Vars: map[string]interface{}{
            "project_id": "your-test-project",
            "region":     "europe-west1",
            "name":       "test-vpc",
        },
    }
    
    defer terraform.Destroy(t, terraformOptions)
    terraform.InitAndApply(t, terraformOptions)
    
    // Test VPC creation
    vpcName := terraform.Output(t, terraformOptions, "vpc_name")
    assert.NotEmpty(t, vpcName)
}
```

### 4. Run Tests

```bash
# Run unit tests
go test -v ./unit/... -timeout 30m

# Run integration tests
go test -v ./integration/... -timeout 60m

# Run all tests
go test -v ./... -timeout 120m
```

## Test Categories

### Unit Tests
- **Purpose**: Test individual modules in isolation
- **Location**: `tests/unit/`
- **Duration**: 5-10 minutes
- **Frequency**: Every PR

### Integration Tests
- **Purpose**: Test complete environment deployments
- **Location**: `tests/integration/`
- **Duration**: 15-30 minutes
- **Frequency**: Every PR

### End-to-End Tests
- **Purpose**: Test complete multi-region deployment
- **Location**: `tests/e2e/`
- **Duration**: 45-90 minutes
- **Frequency**: Main branch only

## Test Helpers

### GCP Helpers
```go
// tests/testhelpers/gcp.go
func GetTestConfig(t *testing.T) *TestConfig
func CleanupTestResources(t *testing.T, projectID string, resources []string)
func CreateTestProject(t *testing.T) string
```

### Terraform Helpers
```go
// tests/testhelpers/terraform.go
func DeployModule(t *testing.T, modulePath string, vars map[string]interface{}) *terraform.Options
func ValidateOutputs(t *testing.T, options *terraform.Options, expected map[string]string)
func DestroyModule(t *testing.T, options *terraform.Options)
```

### Fixture Helpers
```go
// tests/testhelpers/fixtures.go
func LoadTestEnvironment(env string) *TestEnvironment
func CreateTestResources(t *testing.T, config *TestConfig) *TestEnvironment
func GetTestData(t *testing.T, dataType string) interface{}
```

## CI/CD Integration

### GitHub Actions Workflow
```yaml
# .github/workflows/terratest.yml
name: Terratest
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v4
        with:
          go-version: '1.21'
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: '1.9.0'
      - name: Run Unit Tests
        run: |
          cd tests
          go test -v ./unit/... -timeout 30m
```

## Best Practices

### Test Organization
- Group tests by module and functionality
- Use descriptive test names
- Keep tests focused and atomic
- Implement proper cleanup

### Resource Management
- Use unique resource names
- Implement comprehensive cleanup
- Monitor test costs
- Use test-specific projects

### Performance
- Run tests in parallel when possible
- Use test caching for repeated runs
- Optimize test execution time
- Monitor resource usage

### Security
- Use least-privilege service accounts
- Implement secure test data handling
- Validate security policies in tests
- Monitor test access patterns

## Common Patterns

### Module Testing
```go
func TestModule(t *testing.T) {
    // Setup
    terraformOptions := &terraform.Options{
        TerraformDir: "../../../infrastructure/modules/module-name",
        Vars: map[string]interface{}{
            "project_id": "test-project",
            "region":     "europe-west1",
        },
    }
    
    // Deploy
    defer terraform.Destroy(t, terraformOptions)
    terraform.InitAndApply(t, terraformOptions)
    
    // Validate
    output := terraform.Output(t, terraformOptions, "output_name")
    assert.NotEmpty(t, output)
}
```

### Integration Testing
```go
func TestIntegration(t *testing.T) {
    // Deploy global resources
    globalOptions := deployGlobalResources(t)
    defer terraform.Destroy(t, globalOptions)
    
    // Deploy regional resources
    regionalOptions := deployRegionalResources(t)
    defer terraform.Destroy(t, regionalOptions)
    
    // Test integration
    testCrossRegionConnectivity(t)
    testLoadBalancerConfiguration(t)
}
```

### End-to-End Testing
```go
func TestE2E(t *testing.T) {
    // Deploy complete infrastructure
    deployCompleteInfrastructure(t)
    
    // Test application flow
    testApplicationConnectivity(t)
    testDataFlow(t)
    testMonitoringAndAlerting(t)
    
    // Test disaster recovery
    testDisasterRecovery(t)
}
```

## Troubleshooting

### Common Issues
- **Test Flakiness**: Implement retry mechanisms and test isolation
- **Resource Cleanup**: Ensure comprehensive cleanup procedures
- **Cost Overruns**: Monitor test execution costs and optimize
- **Performance Issues**: Implement test optimization and caching

### Debugging
- Use verbose logging: `go test -v`
- Check test logs and outputs
- Validate resource creation in GCP console
- Monitor test execution metrics

### Support
- Review test documentation
- Check test examples and patterns
- Monitor test execution logs
- Validate test configuration

## Next Steps

1. **Start with Unit Tests**: Begin with simple module tests
2. **Add Integration Tests**: Test complete environment deployments
3. **Implement E2E Tests**: Test full stack functionality
4. **Optimize Performance**: Improve test execution time and efficiency
5. **Monitor and Maintain**: Continuously monitor and improve test quality

This quick start guide provides the foundation for implementing comprehensive infrastructure testing with Terratest in the terraform-gcp project.
