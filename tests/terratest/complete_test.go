package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestExampleComplete(t *testing.T) {
	t.Log("Starting Sample Module test")

	centralDir := "../../examples/central"
	memberDir := "../../examples/member-provisio"

	centralBackend := loadBackendConfig(t, "terratest/terraform-aws-acf-configservice-central.tfstate")
	memberBackend := loadBackendConfig(t, "terratest/terraform-aws-acf-configservice-member.tfstate")

	// ---- CENTRAL ----
	// Step 1: Create the CICD provisioner IAM roles in core-security, core-logging and org-mgmt.
	terraformCentralPrep := &terraform.Options{
		TerraformBinary: getHclBinary(),
		TerraformDir:    centralDir,
		NoColor:         false,
		Lock:            true,
		BackendConfig:   centralBackend,
		Reconfigure:     true,
		Targets: []string{
			"module.create_provisioner_aggregation",
			"module.create_provisioner_delivery",
			"module.create_provisioner_delegation",
		},
	}
	defer terraform.Destroy(t, terraformCentralPrep)
	terraform.InitAndApply(t, terraformCentralPrep)

	// Step 2: Apply the full central example, assuming the provisioner roles created above.
	terraformCentral := &terraform.Options{
		TerraformBinary: getHclBinary(),
		TerraformDir:    centralDir,
		NoColor:         false,
		Lock:            true,
		BackendConfig:   centralBackend,
		Reconfigure:     true,
	}
	defer terraform.Destroy(t, terraformCentral)
	terraform.InitAndApply(t, terraformCentral)

	// ---- MEMBER ----
	// Step 1: Create the member CICD provisioner IAM role in the workload account.
	terraformMemberPrep := &terraform.Options{
		TerraformBinary: getHclBinary(),
		TerraformDir:    memberDir,
		NoColor:         false,
		Lock:            true,
		BackendConfig:   memberBackend,
		Reconfigure:     true,
		Targets: []string{
			"module.create_provisioner",
		},
	}
	defer terraform.Destroy(t, terraformMemberPrep)
	terraform.InitAndApply(t, terraformMemberPrep)

	// Step 2: Apply the rendered package against the workload account.
	terraformMember := &terraform.Options{
		TerraformBinary: getHclBinary(),
		TerraformDir:    memberDir,
		NoColor:         false,
		Lock:            true,
		BackendConfig:   memberBackend,
		Reconfigure:     true,
	}
	defer terraform.Destroy(t, terraformMember)
	terraform.InitAndApply(t, terraformMember)

	// Retrieve the 'test_success' output from the member apply (warnings stripped)
	testSuccessOutput := outputClean(t, terraformMember, "test_success")
	t.Logf("testSuccessOutput: %s", testSuccessOutput)

	// Assert that 'test_success' equals "true"
	assert.Equal(t, "true", testSuccessOutput, "The test_success output is not true")
}
