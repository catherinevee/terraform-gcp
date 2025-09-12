package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"time"
)

// TestReport represents a comprehensive test report
type TestReport struct {
	Timestamp   time.Time    `json:"timestamp"`
	Environment string       `json:"environment"`
	Tests       []TestResult `json:"tests"`
	Summary     TestSummary  `json:"summary"`
	Metadata    TestMetadata `json:"metadata"`
}

// TestResult represents a test result
type TestResult struct {
	Key       string        `json:"key"`
	Status    string        `json:"status"`
	Duration  time.Duration `json:"duration"`
	Tests     int           `json:"tests"`
	Passed    int           `json:"passed"`
	Failed    int           `json:"failed"`
	Skipped   int           `json:"skipped"`
	Timestamp time.Time     `json:"timestamp"`
	Error     string        `json:"error,omitempty"`
}

// TestSummary represents test summary statistics
type TestSummary struct {
	Total       int           `json:"total"`
	Passed      int           `json:"passed"`
	Failed      int           `json:"failed"`
	Skipped     int           `json:"skipped"`
	Duration    time.Duration `json:"duration"`
	SuccessRate float64       `json:"success_rate"`
}

// TestMetadata represents test metadata
type TestMetadata struct {
	GoVersion        string `json:"go_version"`
	TerraformVersion string `json:"terraform_version"`
	GCPProjectID     string `json:"gcp_project_id"`
	GCPRegion        string `json:"gcp_region"`
	TestEnvironment  string `json:"test_environment"`
	TestType         string `json:"test_type"`
	TestCategory     string `json:"test_category"`
}

func main() {
	// Create comprehensive test report
	report := &TestReport{
		Timestamp:   time.Now(),
		Environment: getEnv("TEST_ENVIRONMENT", "complete"),
		Tests:       []TestResult{},
		Summary:     TestSummary{},
		Metadata: TestMetadata{
			GoVersion:        "1.21",
			TerraformVersion: "1.9.0",
			GCPProjectID:     getEnv("GCP_PROJECT_ID", "unknown"),
			GCPRegion:        getEnv("GCP_REGION", "europe-west1"),
			TestEnvironment:  getEnv("TEST_ENVIRONMENT", "complete"),
			TestType:         "comprehensive",
			TestCategory:     "all",
		},
	}

	// Load test results from artifacts
	loadTestResults(report, "test-results/")

	// Calculate summary
	calculateSummary(report)

	// Generate report
	err := generateReport(report)
	if err != nil {
		fmt.Printf("Error generating report: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("Comprehensive test report generated successfully\n")
	fmt.Printf("Total tests: %d\n", report.Summary.Total)
	fmt.Printf("Passed: %d\n", report.Summary.Passed)
	fmt.Printf("Failed: %d\n", report.Summary.Failed)
	fmt.Printf("Skipped: %d\n", report.Summary.Skipped)
	fmt.Printf("Success rate: %.2f%%\n", report.Summary.SuccessRate)
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func loadTestResults(report *TestReport, resultsDir string) {
	// Walk through test results directory
	err := filepath.Walk(resultsDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		if !info.IsDir() && filepath.Ext(path) == ".json" {
			// Load test result
			result, err := loadTestResult(path)
			if err != nil {
				fmt.Printf("Warning: Failed to load test result from %s: %v\n", path, err)
				return nil
			}

			report.Tests = append(report.Tests, *result)
		}

		return nil
	})

	if err != nil {
		fmt.Printf("Warning: Error walking test results directory: %v\n", err)
	}
}

func loadTestResult(filepath string) (*TestResult, error) {
	data, err := os.ReadFile(filepath)
	if err != nil {
		return nil, err
	}

	var result TestResult
	err = json.Unmarshal(data, &result)
	if err != nil {
		return nil, err
	}

	return &result, nil
}

func calculateSummary(report *TestReport) {
	for _, test := range report.Tests {
		report.Summary.Total += test.Tests
		report.Summary.Passed += test.Passed
		report.Summary.Failed += test.Failed
		report.Summary.Skipped += test.Skipped
		report.Summary.Duration += test.Duration
	}

	// Calculate success rate
	if report.Summary.Total > 0 {
		report.Summary.SuccessRate = float64(report.Summary.Passed) / float64(report.Summary.Total) * 100
	}
}

func generateReport(report *TestReport) error {
	// Create test-results directory if it doesn't exist
	err := os.MkdirAll("test-results", 0755)
	if err != nil {
		return err
	}

	// Generate JSON report
	jsonFile := "test-results/comprehensive-test-report.json"
	data, err := json.MarshalIndent(report, "", "  ")
	if err != nil {
		return err
	}

	err = os.WriteFile(jsonFile, data, 0644)
	if err != nil {
		return err
	}

	// Generate HTML report
	err = generateHTMLReport(report)
	if err != nil {
		return err
	}

	// Generate summary report
	err = generateSummaryReport(report)
	if err != nil {
		return err
	}

	return nil
}

func generateHTMLReport(report *TestReport) error {
	htmlFile := "test-results/comprehensive-test-report.html"

	html := fmt.Sprintf(`
<!DOCTYPE html>
<html>
<head>
    <title>Comprehensive Test Report - %s</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 20px; border-radius: 5px; }
        .summary { margin: 20px 0; }
        .test-result { margin: 10px 0; padding: 10px; border-left: 4px solid #ccc; }
        .passed { border-left-color: #4CAF50; }
        .failed { border-left-color: #f44336; }
        .skipped { border-left-color: #ff9800; }
        .metadata { background-color: #f9f9f9; padding: 15px; border-radius: 5px; margin: 20px 0; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Comprehensive Test Report - %s</h1>
        <p>Generated: %s</p>
        <p>Environment: %s</p>
    </div>
    
    <div class="summary">
        <h2>Summary</h2>
        <p>Total Tests: %d</p>
        <p>Passed: %d</p>
        <p>Failed: %d</p>
        <p>Skipped: %d</p>
        <p>Success Rate: %.2f%%</p>
        <p>Duration: %v</p>
    </div>
    
    <div class="metadata">
        <h2>Metadata</h2>
        <p>Go Version: %s</p>
        <p>Terraform Version: %s</p>
        <p>GCP Project ID: %s</p>
        <p>GCP Region: %s</p>
        <p>Test Environment: %s</p>
        <p>Test Type: %s</p>
        <p>Test Category: %s</p>
    </div>
    
    <div class="test-results">
        <h2>Test Results</h2>
        %s
    </div>
</body>
</html>
`, report.Environment, report.Environment, report.Timestamp.Format("2006-01-02 15:04:05"),
		report.Environment, report.Summary.Total, report.Summary.Passed, report.Summary.Failed,
		report.Summary.Skipped, report.Summary.SuccessRate, report.Summary.Duration,
		report.Metadata.GoVersion, report.Metadata.TerraformVersion, report.Metadata.GCPProjectID,
		report.Metadata.GCPRegion, report.Metadata.TestEnvironment, report.Metadata.TestType,
		report.Metadata.TestCategory, generateTestResultsHTML(report.Tests))

	return os.WriteFile(htmlFile, []byte(html), 0644)
}

func generateTestResultsHTML(tests []TestResult) string {
	html := ""
	for _, test := range tests {
		statusClass := "skipped"
		if test.Status == "passed" {
			statusClass = "passed"
		} else if test.Status == "failed" {
			statusClass = "failed"
		}

		html += fmt.Sprintf(`
        <div class="test-result %s">
            <h3>%s</h3>
            <p>Status: %s</p>
            <p>Duration: %v</p>
            <p>Tests: %d (Passed: %d, Failed: %d, Skipped: %d)</p>
            %s
        </div>
        `, statusClass, test.Key, test.Status, test.Duration, test.Tests,
			test.Passed, test.Failed, test.Skipped,
			func() string {
				if test.Error != "" {
					return fmt.Sprintf("<p>Error: %s</p>", test.Error)
				}
				return ""
			}())
	}
	return html
}

func generateSummaryReport(report *TestReport) error {
	summaryFile := "test-results/comprehensive-test-summary.txt"

	summary := fmt.Sprintf(`
Comprehensive Test Report Summary
================================

Environment: %s
Generated: %s

Summary:
--------
Total Tests: %d
Passed: %d
Failed: %d
Skipped: %d
Success Rate: %.2f%%
Duration: %v

Metadata:
---------
Go Version: %s
Terraform Version: %s
GCP Project ID: %s
GCP Region: %s
Test Environment: %s
Test Type: %s
Test Category: %s

Test Results:
-------------
`, report.Environment, report.Timestamp.Format("2006-01-02 15:04:05"),
		report.Summary.Total, report.Summary.Passed, report.Summary.Failed,
		report.Summary.Skipped, report.Summary.SuccessRate, report.Summary.Duration,
		report.Metadata.GoVersion, report.Metadata.TerraformVersion, report.Metadata.GCPProjectID,
		report.Metadata.GCPRegion, report.Metadata.TestEnvironment, report.Metadata.TestType,
		report.Metadata.TestCategory)

	for _, test := range report.Tests {
		summary += fmt.Sprintf(`
%s:
  Status: %s
  Duration: %v
  Tests: %d (Passed: %d, Failed: %d, Skipped: %d)
  %s
`, test.Key, test.Status, test.Duration, test.Tests, test.Passed, test.Failed, test.Skipped,
			func() string {
				if test.Error != "" {
					return fmt.Sprintf("Error: %s", test.Error)
				}
				return ""
			}())
	}

	return os.WriteFile(summaryFile, []byte(summary), 0644)
}
