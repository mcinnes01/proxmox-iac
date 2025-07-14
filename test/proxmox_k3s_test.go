package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
)

func TestProxmoxK3s(t *testing.T) {
	options := &terraform.Options{
		// The path to the Terraform code that will be tested.
		TerraformDir: "../path/to/your/proxmox_k3s",

		// Variables to pass to our Terraform code using -var options
		Vars: map[string]interface{}{
			// Add your variables here
		},

		// Variables to pass to our Terraform code using -var-file options
		VarFiles: []string{"../path/to/your/variables.tfvars"},

		// Variables to pass to our Terraform code using -var options
		EnvVars: []string{
			// Add your environment variables here
		},

		// Retryable errors that will be ignored during testing
		RetryableTerraformErrors: map[string]string{
			// Add any retryable errors here
		},
	}

	// Clean up resources with "terraform destroy" at the end of the test
	defer terraform.Destroy(t, options)

	// This will run "terraform init" and "terraform apply". Fail the test if there are any errors.
	terraform.InitAndApply(t, options)

	// Validate your code works as expected
	// Add your assertions here
}