package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"math"
	"os"
	"strconv"
	"strings"
	"syscall"
	"time"
)

const csvFile = "../users-big.csv"

type User struct {
	ID         string
	Name       string
	Email      string
	Country    string
	Age        int
	Profession string
	Salary     float64
}

type CountryStats struct {
	Count     int     `json:"total_users"`
	TotalSal  float64 `json:"-"`
	TotalAge  int     `json:"-"`
	AvgSalary float64 `json:"average_salary"`
	AvgAge    float64 `json:"average_age"`
}

type ProfessionStats struct {
	Count     int     `json:"count"`
	TotalSal  float64 `json:"-"`
	AvgSalary float64 `json:"average_salary"`
}

type Summary struct {
	TotalRecords    int     `json:"total_records"`
	ValidRecords    int     `json:"valid_records"`
	InvalidRecords  int     `json:"invalid_records"`
	AverageSalary   float64 `json:"average_salary"`
	MinSalary       float64 `json:"min_salary"`
	MaxSalary       float64 `json:"max_salary"`
	AverageAge      float64 `json:"average_age"`
	HighestPaidProf string  `json:"highest_paid_profession"`
	LowestPaidProf  string  `json:"lowest_paid_profession"`
}

type Output struct {
	Summary     Summary                     `json:"summary"`
	Countries   map[string]*CountryStats    `json:"countries"`
	Professions map[string]*ProfessionStats `json:"professions"`
}

func formatSize(bytes uint64) string {
	b := float64(bytes)
	switch {
	case b >= 1_073_741_824:
		return fmt.Sprintf("%.2f GB", b/1_073_741_824)
	case b >= 1_048_576:
		return fmt.Sprintf("%.2f MB", b/1_048_576)
	case b >= 1024:
		return fmt.Sprintf("%.2f KB", b/1024)
	default:
		return fmt.Sprintf("%d B", bytes)
	}
}

func printProgress(bytesRead, totalBytes uint64, rows uint64, startTime time.Time) {
	elapsed := time.Since(startTime).Seconds()
	rowsPerSec := uint64(0)
	mbPerSec := 0.0
	if elapsed > 0 {
		rowsPerSec = uint64(float64(rows) / elapsed)
		mbPerSec = float64(bytesRead) / 1_048_576 / elapsed
	}

	percent := 0.0
	if totalBytes > 0 {
		percent = float64(bytesRead) / float64(totalBytes) * 100
	}

	barWidth := 30
	filled := 0
	if totalBytes > 0 {
		filled = int(float64(barWidth) * float64(bytesRead) / float64(totalBytes))
	}

	bar := strings.Repeat("\u2588", filled) + strings.Repeat("\u2591", barWidth-filled)
	fmt.Fprintf(os.Stdout, "\r[%s] %.2f%% | %d rows | %d rows/sec | %.2f MB/s    ", bar, percent, rows, rowsPerSec, mbPerSec)
}

func main() {
	csvPath := csvFile

	// Print header
	fmt.Println("==================================================")
	fmt.Println("Cross-Language Benchmark")
	fmt.Println("Language : Go")
	fmt.Println("==================================================")
	fmt.Println()
	fmt.Printf("Input File : %s\n\n", csvPath)

	// Open file
	file, err := os.Open(csvPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error:\nUnable to open %s\n", csvPath)
		os.Exit(1)
	}
	defer file.Close()

	// Get file size
	stat, err := file.Stat()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error:\nUnable to stat %s\n", csvPath)
		os.Exit(1)
	}
	csvSizeBytes := uint64(stat.Size())

	// Start timing
	startTime := time.Now()

	// Processing state
	var rowsProcessed uint64
	var invalidRows uint64
	var totalSalary float64
	minSalary := math.MaxFloat64
	maxSalary := -math.MaxFloat64
	var totalAge int

	countries := make(map[string]*CountryStats)
	professions := make(map[string]*ProfessionStats)

	// Stream CSV with buffered reader
	scanner := bufio.NewScanner(file)
	scanner.Buffer(make([]byte, 8*1024*1024), 8*1024*1024)

	headerSkipped := false
	var bytesRead uint64
	lastProgressTime := startTime

	for scanner.Scan() {
		line := scanner.Text()
		bytesRead += uint64(len(line)) + 1 // +1 for newline

		if !headerSkipped {
			headerSkipped = true
			continue
		}

		if len(line) == 0 {
			continue
		}

		// Parse CSV fields
		fields := strings.SplitN(line, ",", 8)
		if len(fields) < 7 {
			invalidRows++
			rowsProcessed++
			continue
		}

		id := fields[0]
		name := fields[1]
		email := fields[2]
		country := fields[3]
		ageStr := fields[4]
		profession := fields[5]
		salaryStr := strings.TrimRight(fields[6], "\r")

		// Validation
		if id == "" || !strings.Contains(email, "@") {
			invalidRows++
			rowsProcessed++
			continue
		}

		age, err := strconv.Atoi(ageStr)
		if err != nil {
			invalidRows++
			rowsProcessed++
			continue
		}

		salary, err := strconv.ParseFloat(salaryStr, 64)
		if err != nil {
			invalidRows++
			rowsProcessed++
			continue
		}

		// Create user struct (required by spec)
		_ = User{
			ID:         id,
			Name:       name,
			Email:      email,
			Country:    country,
			Age:        age,
			Profession: profession,
			Salary:     salary,
		}

		// Accumulate statistics
		totalSalary += salary
		if salary < minSalary {
			minSalary = salary
		}
		if salary > maxSalary {
			maxSalary = salary
		}
		totalAge += age

		// Country grouping
		cs, ok := countries[country]
		if !ok {
			cs = &CountryStats{}
			countries[country] = cs
		}
		cs.Count++
		cs.TotalSal += salary
		cs.TotalAge += age

		// Profession grouping
		ps, ok := professions[profession]
		if !ok {
			ps = &ProfessionStats{}
			professions[profession] = ps
		}
		ps.Count++
		ps.TotalSal += salary

		rowsProcessed++

		// Update progress every 50ms
		now := time.Now()
		if now.Sub(lastProgressTime) >= 50*time.Millisecond {
			printProgress(bytesRead, csvSizeBytes, rowsProcessed, startTime)
			lastProgressTime = now
		}
	}

	if err := scanner.Err(); err != nil {
		fmt.Fprintf(os.Stderr, "Error:\nFailed to read %s: %v\n", csvPath, err)
		os.Exit(1)
	}

	// Final progress
	printProgress(csvSizeBytes, csvSizeBytes, rowsProcessed, startTime)
	fmt.Print("\n\n")

	validRows := rowsProcessed - invalidRows

	avgSalary := 0.0
	avgAge := 0.0
	if validRows > 0 {
		avgSalary = totalSalary / float64(validRows)
		avgAge = float64(totalAge) / float64(validRows)
	}
	if minSalary == math.MaxFloat64 {
		minSalary = 0
	}
	if maxSalary == -math.MaxFloat64 {
		maxSalary = 0
	}

	// Find highest/lowest paid profession
	highestProf := ""
	highestAvg := -math.MaxFloat64
	lowestProf := ""
	lowestAvg := math.MaxFloat64

	for name, ps := range professions {
		avg := ps.TotalSal / float64(ps.Count)
		ps.AvgSalary = math.Round(avg*100) / 100
		if avg > highestAvg {
			highestAvg = avg
			highestProf = name
		}
		if avg < lowestAvg {
			lowestAvg = avg
			lowestProf = name
		}
	}

	// Compute country averages
	for _, cs := range countries {
		cs.AvgSalary = math.Round(cs.TotalSal/float64(cs.Count)*100) / 100
		cs.AvgAge = math.Round(float64(cs.TotalAge)/float64(cs.Count)*100) / 100
	}

	// Build JSON output
	output := Output{
		Summary: Summary{
			TotalRecords:    int(rowsProcessed),
			ValidRecords:    int(validRows),
			InvalidRecords:  int(invalidRows),
			AverageSalary:   math.Round(avgSalary*100) / 100,
			MinSalary:       minSalary,
			MaxSalary:       maxSalary,
			AverageAge:      math.Round(avgAge*100) / 100,
			HighestPaidProf: highestProf,
			LowestPaidProf:  lowestProf,
		},
		Countries:   countries,
		Professions: professions,
	}

	jsonData, err := json.MarshalIndent(output, "", "  ")
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error:\nFailed to serialize JSON: %v\n", err)
		os.Exit(1)
	}

	// Write JSON to disk
	outputPath := "result.json"
	if err := os.WriteFile(outputPath, jsonData, 0644); err != nil {
		fmt.Fprintf(os.Stderr, "Error:\nFailed to write %s: %v\n", outputPath, err)
		os.Exit(1)
	}

	elapsed := time.Since(startTime).Seconds()
	jsonSizeBytes := uint64(len(jsonData))
	rowsPerSec := uint64(0)
	if elapsed > 0 {
		rowsPerSec = uint64(float64(rowsProcessed) / elapsed)
	}

	// Peak memory via getrusage
	var rusage syscall.Rusage
	syscall.Getrusage(syscall.RUSAGE_SELF, &rusage)
	peakMemory := uint64(rusage.Maxrss)

	// Print completion summary
	fmt.Println("==================================================")
	fmt.Println("Benchmark Complete")
	fmt.Println("==================================================")
	fmt.Println()
	fmt.Println("Language           : Go")
	fmt.Println()
	fmt.Printf("Rows Processed     : %d\n", rowsProcessed)
	fmt.Printf("Invalid Rows       : %d\n", invalidRows)
	fmt.Println()
	fmt.Printf("CSV Size           : %s\n", formatSize(csvSizeBytes))
	fmt.Printf("JSON Size          : %s\n", formatSize(jsonSizeBytes))
	fmt.Println()
	fmt.Printf("Execution Time     : %.3f seconds\n", elapsed)
	fmt.Println()
	fmt.Printf("Rows / Second      : %d\n", rowsPerSec)
	fmt.Println()
	fmt.Printf("Peak Memory        : %s\n", formatSize(peakMemory))
	fmt.Println()
	fmt.Printf("Output File        : %s\n", outputPath)
	fmt.Println()
	fmt.Println("==================================================")
}
