const (
	terraformVersion = "latest"
)

func TestTerraformInstallation(t *testing.T) {
	cmd := exec.Command("terraform", "version")
	output, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("Failed to run terraform: %v", err)
	}
	if !strings.Contains(string(output), terraformVersion) {
		t.Errorf("Expected Terraform version %s, got %s", terraformVersion, output)
	}
}

func TestGPGKeyIssueResolved(t *testing.T) {
	cmd := exec.Command("gpg", "--list-keys")
	output, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("GPG key issue not resolved: %v", err)
	}
	if len(output) == 0 {
		t.Error("No GPG keys found, issue may still exist")
	}
}

func TestTalosIntegration(t *testing.T) {
	cmd := exec.Command("talosctl", "version")
	output, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("Failed to run talosctl: %v", err)
	}
	if len(output) == 0 {
		t.Error("Talos integration failed, no output received")
	}
}

func TestFluxIntegration(t *testing.T) {
	cmd := exec.Command("flux", "version")
	output, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("Failed to run flux: %v", err)
	}
	if len(output) == 0 {
		t.Error("Flux integration failed, no output received")
	}
}