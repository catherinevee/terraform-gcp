package networking

import (
	"testing"

	"github.com/catherinevee/terraform-gcp/tests/testhelpers"
	"github.com/gruntwork-io/terratest/modules/gcp"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestVPCModule(t *testing.T) {
	config := testhelpers.GetTestConfig(t)

	// Validate GCP credentials
	testhelpers.ValidateGCPCredentials(t)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../infrastructure/modules/networking/vpc",
		Vars: map[string]interface{}{
			"project_id": config.ProjectID,
			"region":     config.Region,
			"name":       testhelpers.GetTestResourceName("test-vpc", config.RandomID),
			"cidr":       "10.0.0.0/16",
		},
		NoColor: true,
		Logger:  terraform.DefaultLogger(t),
	}

	// Clean up resources after test
	defer terraform.Destroy(t, terraformOptions)

	// Initialize and apply Terraform
	terraform.InitAndApply(t, terraformOptions)

	// Test VPC creation
	vpcName := terraform.Output(t, terraformOptions, "vpc_name")
	assert.NotEmpty(t, vpcName, "VPC name should not be empty")
	assert.Contains(t, vpcName, "test-vpc-", "VPC name should contain test prefix")

	// Test VPC exists in GCP
	vpc := gcp.GetVPC(t, config.ProjectID, vpcName)
	assert.NotNil(t, vpc, "VPC should exist in GCP")
	assert.Equal(t, "test-vpc-"+config.RandomID, vpc.Name, "VPC name should match expected value")

	// Test VPC properties
	assert.Equal(t, "10.0.0.0/16", vpc.IPv4Range, "VPC CIDR should match expected value")
	assert.Equal(t, "GLOBAL", vpc.RoutingMode, "VPC routing mode should be GLOBAL")
}

func TestVPCModuleValidation(t *testing.T) {
	config := testhelpers.GetTestConfig(t)

	// Test module structure validation
	modulePath := "../../../infrastructure/modules/networking/vpc"
	requiredFiles := []string{"main.tf", "variables.tf", "outputs.tf"}
	testhelpers.ValidateModuleStructure(t, modulePath, requiredFiles)

	// Test Terraform format validation
	testhelpers.ValidateTerraformFormat(t, modulePath)

	// Test Terraform validate
	testhelpers.ValidateTerraformValidate(t, modulePath)
}
