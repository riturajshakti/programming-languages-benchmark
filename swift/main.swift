import Foundation
import Darwin

let CSV_PATH = "../users-big.csv"

struct User {
    let id: String
    let name: String
    let email: String
    let country: String
    let age: Int
    let profession: String
    let salary: Double
}

struct CountryStats {
    var count: Int = 0
    var totalSalary: Double = 0
    var totalAge: Int = 0
}

struct ProfessionStats {
    var count: Int = 0
    var totalSalary: Double = 0
}

func formatSize(_ bytes: UInt64) -> String {
    let b = Double(bytes)
    if b >= 1_073_741_824 {
        return String(format: "%.2f GB", b / 1_073_741_824)
    } else if b >= 1_048_576 {
        return String(format: "%.2f MB", b / 1_048_576)
    } else if b >= 1024 {
        return String(format: "%.2f KB", b / 1024)
    } else {
        return "\(bytes) B"
    }
}

func printProgress(bytesRead: UInt64, totalBytes: UInt64, rows: UInt64, startTime: UInt64) {
    let now = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)
    let elapsedNs = now - startTime
    let elapsed = Double(elapsedNs) / 1_000_000_000
    let rowsPerSec: UInt64 = elapsed > 0 ? UInt64(Double(rows) / elapsed) : 0
    let mbPerSec = elapsed > 0 ? Double(bytesRead) / 1_048_576 / elapsed : 0

    let percent = totalBytes > 0 ? Double(bytesRead) / Double(totalBytes) * 100 : 0

    let barWidth = 30
    var filled = totalBytes > 0 ? Int(Double(barWidth) * Double(bytesRead) / Double(totalBytes)) : 0
    if filled > barWidth { filled = barWidth }

    var bar = ""
    for i in 0..<barWidth {
        bar += i < filled ? "\u{2588}" : "\u{2591}"
    }

    print("\r[\(bar)] \(String(format: "%.2f", percent))% | \(rows) rows | \(rowsPerSec) rows/sec | \(String(format: "%.2f", mbPerSec)) MB/s    ", terminator: "")
    fflush(stdout)
}

func processLine(
    _ line: String,
    _ rowsProcessed: inout UInt64,
    _ invalidRows: inout UInt64,
    _ totalSalary: inout Double,
    _ minSalary: inout Double,
    _ maxSalary: inout Double,
    _ totalAge: inout Int,
    _ countries: inout [String: CountryStats],
    _ professions: inout [String: ProfessionStats]
) {
    let fields = line.split(separator: ",", maxSplits: 7, omittingEmptySubsequences: false).map(String.init)
    guard fields.count >= 7 else {
        invalidRows += 1
        rowsProcessed += 1
        return
    }

    let id = fields[0]
    let name = fields[1]
    let email = fields[2]
    let country = fields[3]
    let ageStr = fields[4]
    let profession = fields[5]
    let salaryStr = fields[6].trimmingCharacters(in: CharacterSet(charactersIn: "\r"))

    // Validation
    guard !id.isEmpty, email.contains("@") else {
        invalidRows += 1
        rowsProcessed += 1
        return
    }

    guard let age = Int(ageStr) else {
        invalidRows += 1
        rowsProcessed += 1
        return
    }

    guard let salary = Double(salaryStr) else {
        invalidRows += 1
        rowsProcessed += 1
        return
    }

    // Create user struct
    let _ = User(id: id, name: name, email: email, country: country,
                 age: age, profession: profession, salary: salary)

    // Statistics
    totalSalary += salary
    if salary < minSalary { minSalary = salary }
    if salary > maxSalary { maxSalary = salary }
    totalAge += age

    // Country grouping
    if countries[country] != nil {
        countries[country]!.count += 1
        countries[country]!.totalSalary += salary
        countries[country]!.totalAge += age
    } else {
        countries[country] = CountryStats(count: 1, totalSalary: salary, totalAge: age)
    }

    // Profession grouping
    if professions[profession] != nil {
        professions[profession]!.count += 1
        professions[profession]!.totalSalary += salary
    } else {
        professions[profession] = ProfessionStats(count: 1, totalSalary: salary)
    }

    rowsProcessed += 1
}

// MARK: - Main

let csvPath = CSV_PATH

print("==================================================")
print("Cross-Language Benchmark")
print("Language : Swift")
print("==================================================")
print()
print("Input File : \(csvPath)")
print()

// Open file
guard let fileHandle = FileHandle(forReadingAtPath: csvPath) else {
    fputs("Error:\nUnable to open \(csvPath)\n", stderr)
    exit(1)
}
defer { fileHandle.closeFile() }

// Get file size
var statBuf = stat()
guard stat(csvPath, &statBuf) == 0 else {
    fputs("Error:\nUnable to stat \(csvPath)\n", stderr)
    exit(1)
}
let csvSizeBytes = UInt64(statBuf.st_size)

// Start timing
let startTime = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)

// Processing state
var rowsProcessed: UInt64 = 0
var invalidRows: UInt64 = 0
var bytesRead: UInt64 = 0

var totalSalary: Double = 0
var minSalary: Double = Double.greatestFiniteMagnitude
var maxSalary: Double = -Double.greatestFiniteMagnitude
var totalAge: Int = 0

var countries: [String: CountryStats] = [:]
var professions: [String: ProfessionStats] = [:]

// Streaming read with 8MB buffer
let bufSize = 8 * 1024 * 1024
let fd = fileHandle.fileDescriptor
var headerSkipped = false
var leftoverData = Data()
var lastProgressTime = startTime

while true {
    let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: bufSize)
    let n = Darwin.read(fd, buf, bufSize)
    if n <= 0 {
        buf.deallocate()
        // Process remaining leftover
        if !leftoverData.isEmpty, headerSkipped {
            if let line = String(data: leftoverData, encoding: .utf8) {
                let trimmed = line.trimmingCharacters(in: CharacterSet(charactersIn: "\r\n"))
                if !trimmed.isEmpty {
                    processLine(trimmed, &rowsProcessed, &invalidRows,
                                &totalSalary, &minSalary, &maxSalary,
                                &totalAge, &countries, &professions)
                }
            }
        }
        break
    }

    bytesRead += UInt64(n)
    let chunk = Data(bytesNoCopy: buf, count: n, deallocator: .custom({ ptr, _ in ptr.deallocate() }))

    // Process lines
    var lineStart = 0
    for i in 0..<n {
        if chunk[i] == UInt8(ascii: "\n") {
            let segment = chunk[lineStart..<i]

            let lineData: Data
            if !leftoverData.isEmpty {
                lineData = leftoverData + segment
                leftoverData = Data()
            } else {
                lineData = segment
            }

            if let line = String(data: lineData, encoding: .utf8) {
                let trimmed = line.trimmingCharacters(in: CharacterSet(charactersIn: "\r"))
                if !headerSkipped {
                    headerSkipped = true
                } else if !trimmed.isEmpty {
                    processLine(trimmed, &rowsProcessed, &invalidRows,
                                &totalSalary, &minSalary, &maxSalary,
                                &totalAge, &countries, &professions)
                }
            }

            lineStart = i + 1
        }
    }

    // Save leftover
    if lineStart < n {
        leftoverData = chunk[lineStart..<n]
    } else {
        leftoverData = Data()
    }

    // Progress every 50ms
    let now = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)
    if now - lastProgressTime >= 50_000_000 {
        printProgress(bytesRead: bytesRead, totalBytes: csvSizeBytes, rows: rowsProcessed, startTime: startTime)
        lastProgressTime = now
    }
}

// Final progress
printProgress(bytesRead: csvSizeBytes, totalBytes: csvSizeBytes, rows: rowsProcessed, startTime: startTime)
print("\n")

let validRows = rowsProcessed - invalidRows
let avgSalary = validRows > 0 ? totalSalary / Double(validRows) : 0
let avgAge = validRows > 0 ? Double(totalAge) / Double(validRows) : 0
if minSalary == Double.greatestFiniteMagnitude { minSalary = 0 }
if maxSalary == -Double.greatestFiniteMagnitude { maxSalary = 0 }

// Find highest/lowest paid profession
var highestProf = ""
var highestAvg = -Double.greatestFiniteMagnitude
var lowestProf = ""
var lowestAvg = Double.greatestFiniteMagnitude

for (name, ps) in professions {
    let avg = ps.totalSalary / Double(ps.count)
    if avg > highestAvg { highestAvg = avg; highestProf = name }
    if avg < lowestAvg { lowestAvg = avg; lowestProf = name }
}

// Write JSON
let outputPath = "result.json"
guard let outFile = fopen(outputPath, "w") else {
    fputs("Error:\nFailed to write \(outputPath)\n", stderr)
    exit(1)
}

func wf(_ s: String) {
    fputs(s, outFile)
}

wf("{\n")
wf("  \"summary\": {\n")
wf("    \"total_records\": \(rowsProcessed),\n")
wf("    \"valid_records\": \(validRows),\n")
wf("    \"invalid_records\": \(invalidRows),\n")
wf("    \"average_salary\": \(String(format: "%.2f", avgSalary)),\n")
wf("    \"min_salary\": \(String(format: "%.2f", minSalary)),\n")
wf("    \"max_salary\": \(String(format: "%.2f", maxSalary)),\n")
wf("    \"average_age\": \(String(format: "%.2f", avgAge)),\n")
wf("    \"highest_paid_profession\": \"\(highestProf)\",\n")
wf("    \"lowest_paid_profession\": \"\(lowestProf)\"\n")
wf("  },\n")

wf("  \"countries\": {\n")
let countryKeys = Array(countries.keys)
for (ci, name) in countryKeys.enumerated() {
    let cs = countries[name]!
    let ca = cs.totalSalary / Double(cs.count)
    let aa = Double(cs.totalAge) / Double(cs.count)
    wf("    \"\(name)\": {\n")
    wf("      \"total_users\": \(cs.count),\n")
    wf("      \"average_salary\": \(String(format: "%.2f", ca)),\n")
    wf("      \"average_age\": \(String(format: "%.2f", aa))\n")
    wf("    }\(ci < countryKeys.count - 1 ? "," : "")\n")
}
wf("  },\n")

wf("  \"professions\": {\n")
let profKeys = Array(professions.keys)
for (pi, name) in profKeys.enumerated() {
    let ps = professions[name]!
    let pa = ps.totalSalary / Double(ps.count)
    wf("    \"\(name)\": {\n")
    wf("      \"count\": \(ps.count),\n")
    wf("      \"average_salary\": \(String(format: "%.2f", pa))\n")
    wf("    }\(pi < profKeys.count - 1 ? "," : "")\n")
}
wf("  }\n")
wf("}\n")

let jsonSize = ftell(outFile)
fclose(outFile)
let jsonSizeBytes = UInt64(jsonSize)

let endTime = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)
let elapsedNs = endTime - startTime
let elapsed = Double(elapsedNs) / 1_000_000_000
let rowsPerSec: UInt64 = elapsed > 0 ? UInt64(Double(rowsProcessed) / elapsed) : 0

// Peak memory via getrusage
var usage = rusage()
getrusage(RUSAGE_SELF, &usage)
let peakRss = UInt64(usage.ru_maxrss)

print("==================================================")
print("Benchmark Complete")
print("==================================================")
print()
print("Language           : Swift")
print()
print("Rows Processed     : \(rowsProcessed)")
print("Invalid Rows       : \(invalidRows)")
print()
print("CSV Size           : \(formatSize(csvSizeBytes))")
print("JSON Size          : \(formatSize(jsonSizeBytes))")
print()
print("Execution Time     : \(String(format: "%.3f", elapsed)) seconds")
print()
print("Rows / Second      : \(rowsPerSec)")
print()
print("Peak Memory        : \(formatSize(peakRss))")
print()
print("Output File        : \(outputPath)")
print()
print("==================================================")
