package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
)

func TestTerraform(t *testing.T) {
	options := &terraform.Options{
		TerraformDir: "../path/to/your/terraform/configuration",
	}

	defer terraform.Destroy(t, options)

	initAndApply := terraform.InitAndApply(t, options)

	if initAndApply {
		t.Log("Terraform applied successfully!")
	} else {
		t.Fatal("Terraform apply failed!")
	}
}