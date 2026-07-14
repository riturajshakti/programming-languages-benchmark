import std/[tables, strutils, strformat, monotimes, times, os, posix]

const CSV_PATH = "../users-big.csv"

type
  User = object
    id, name, email, country, profession: string
    age: int
    salary: float64

  CountryStats = object
    count: int
    totalSalary: float64
    totalAge: int

  ProfessionStats = object
    count: int
    totalSalary: float64

proc formatSize(bytes: int64): string =
  let b = bytes.float64
  if b >= 1_073_741_824: fmt"{b / 1_073_741_824:.2f} GB"
  elif b >= 1_048_576: fmt"{b / 1_048_576:.2f} MB"
  elif b >= 1024: fmt"{b / 1024:.2f} KB"
  else: fmt"{bytes} B"

proc printProgress(bytesRead, totalBytes: int64, rows: int64, startTime: MonoTime) =
  let now = getMonoTime()
  let elapsed = (now - startTime).inNanoseconds.float64 / 1e9
  let rowsPerSec = if elapsed > 0: int64(rows.float64 / elapsed) else: 0'i64
  let mbPerSec = if elapsed > 0: bytesRead.float64 / 1_048_576 / elapsed else: 0.0
  let percent = if totalBytes > 0: bytesRead.float64 / totalBytes.float64 * 100 else: 0.0

  let barWidth = 30
  var filled = if totalBytes > 0: int(barWidth.float64 * bytesRead.float64 / totalBytes.float64) else: 0
  if filled > barWidth: filled = barWidth

  var bar = ""
  for i in 0..<barWidth:
    if i < filled: bar.add("█")
    else: bar.add("░")

  stdout.write("\r" & fmt"[{bar}] {percent:.2f}% | {rows} rows | {rowsPerSec} rows/sec | {mbPerSec:.2f} MB/s    ")
  stdout.flushFile()

proc processLine(line: string,
                 rowsProcessed, invalidRows: var int64,
                 totalSalary, minSalary, maxSalary: var float64,
                 totalAge: var int64,
                 countries: var Table[string, CountryStats],
                 professions: var Table[string, ProfessionStats]) =
  # Manual split into 7 fields
  var fields: array[7, string]
  var start = 0
  for f in 0..5:
    let comma = line.find(',', start)
    if comma < 0:
      invalidRows.inc
      rowsProcessed.inc
      return
    fields[f] = line[start..<comma]
    start = comma + 1
  fields[6] = line[start..^1]

  let id = fields[0]
  let name = fields[1]
  let email = fields[2]
  let country = fields[3]
  let ageStr = fields[4]
  let profession = fields[5]
  let salaryStr = fields[6].strip(trailing = true, chars = {'\r'})

  # Validation
  if id.len == 0 or '@' notin email:
    invalidRows.inc
    rowsProcessed.inc
    return

  var age: int
  try:
    age = parseInt(ageStr)
  except ValueError:
    invalidRows.inc
    rowsProcessed.inc
    return

  var salary: float64
  try:
    salary = parseFloat(salaryStr)
  except ValueError:
    invalidRows.inc
    rowsProcessed.inc
    return

  # Create user object
  let user = User(id: id, name: name, email: email, country: country,
                  age: age, profession: profession, salary: salary)
  discard user

  # Statistics
  totalSalary += salary
  if salary < minSalary: minSalary = salary
  if salary > maxSalary: maxSalary = salary
  totalAge += age

  # Country grouping
  if country in countries:
    countries[country].count.inc
    countries[country].totalSalary += salary
    countries[country].totalAge += age
  else:
    countries[country] = CountryStats(count: 1, totalSalary: salary, totalAge: age)

  # Profession grouping
  if profession in professions:
    professions[profession].count.inc
    professions[profession].totalSalary += salary
  else:
    professions[profession] = ProfessionStats(count: 1, totalSalary: salary)

  rowsProcessed.inc

proc main() =
  let csvPath = CSV_PATH

  echo "=================================================="
  echo "Cross-Language Benchmark"
  echo "Language : Nim"
  echo "=================================================="
  echo ""
  echo fmt"Input File : {csvPath}"
  echo ""

  # Open file
  var fp: File
  if not open(fp, csvPath, fmRead):
    stderr.write(fmt"Error:\nUnable to open {csvPath}\n")
    quit(1)

  let csvSizeBytes = getFileSize(csvPath)

  # Start timing
  let startTime = getMonoTime()

  var rowsProcessed: int64 = 0
  var invalidRows: int64 = 0
  var bytesRead: int64 = 0

  var totalSalary: float64 = 0
  var minSalary: float64 = 1e308
  var maxSalary: float64 = -1e308
  var totalAge: int64 = 0

  var countries = initTable[string, CountryStats]()
  var professions = initTable[string, ProfessionStats]()

  # Streaming read with 8MB buffer
  const BUF_SIZE = 8 * 1024 * 1024
  var buf = newSeq[char](BUF_SIZE)
  var leftover = ""
  var headerSkipped = false
  var lastProgressTime = startTime

  while true:
    let n = fp.readBuffer(addr buf[0], BUF_SIZE)
    if n == 0:
      # Process remaining leftover
      if leftover.len > 0 and headerSkipped:
        let line = leftover.strip(trailing = true, chars = {'\r', '\n'})
        if line.len > 0:
          processLine(line, rowsProcessed, invalidRows, totalSalary,
                      minSalary, maxSalary, totalAge, countries, professions)
      break

    bytesRead += n

    var chunk = newString(n)
    copyMem(addr chunk[0], addr buf[0], n)

    var data: string
    if leftover.len > 0:
      data = leftover & chunk
      leftover = ""
    else:
      data = chunk

    var lineStart = 0
    for i in 0..<data.len:
      if data[i] == '\n':
        var lineEnd = i
        if lineEnd > lineStart and data[lineEnd - 1] == '\r':
          lineEnd.dec
        let line = data[lineStart..<lineEnd]
        lineStart = i + 1

        if not headerSkipped:
          headerSkipped = true
          continue
        if line.len == 0: continue

        processLine(line, rowsProcessed, invalidRows, totalSalary,
                    minSalary, maxSalary, totalAge, countries, professions)

    # Save leftover
    if lineStart < data.len:
      leftover = data[lineStart..^1]
    else:
      leftover = ""

    # Progress every 50ms
    let now = getMonoTime()
    if (now - lastProgressTime).inMilliseconds >= 50:
      printProgress(bytesRead, csvSizeBytes, rowsProcessed, startTime)
      lastProgressTime = now

  fp.close()

  # Final progress
  printProgress(csvSizeBytes, csvSizeBytes, rowsProcessed, startTime)
  stdout.write("\n\n")

  let validRows = rowsProcessed - invalidRows
  let avgSalary = if validRows > 0: totalSalary / validRows.float64 else: 0.0
  let avgAge = if validRows > 0: totalAge.float64 / validRows.float64 else: 0.0
  if minSalary >= 1e308: minSalary = 0
  if maxSalary <= -1e308: maxSalary = 0

  # Find highest/lowest paid profession
  var highestProf = ""
  var highestAvg = -1e308
  var lowestProf = ""
  var lowestAvg = 1e308

  for name, ps in professions:
    let avg = ps.totalSalary / ps.count.float64
    if avg > highestAvg: highestAvg = avg; highestProf = name
    if avg < lowestAvg: lowestAvg = avg; lowestProf = name

  # Write JSON
  let outputPath = "result.json"
  let outFile = open(outputPath, fmWrite)

  proc wf(s: string) = outFile.write(s)
  proc wl(s: string) = outFile.writeLine(s)

  wf("{\n")
  wf("  \"summary\": {\n")
  wl(fmt"    ""total_records"": {rowsProcessed},")
  wl(fmt"    ""valid_records"": {validRows},")
  wl(fmt"    ""invalid_records"": {invalidRows},")
  wl(fmt"    ""average_salary"": {avgSalary:.2f},")
  wl(fmt"    ""min_salary"": {minSalary:.2f},")
  wl(fmt"    ""max_salary"": {maxSalary:.2f},")
  wl(fmt"    ""average_age"": {avgAge:.2f},")
  wl(fmt"    ""highest_paid_profession"": ""{highestProf}"",")
  wl(fmt"    ""lowest_paid_profession"": ""{lowestProf}""")
  wf("  },\n")

  wf("  \"countries\": {\n")
  var ci = 0
  let countryTotal = countries.len
  for name, cs in countries:
    ci.inc
    let ca = cs.totalSalary / cs.count.float64
    let aa = cs.totalAge.float64 / cs.count.float64
    wl(fmt"    ""{name}"": {{")
    wl(fmt"      ""total_users"": {cs.count},")
    wl(fmt"      ""average_salary"": {ca:.2f},")
    wl(fmt"      ""average_age"": {aa:.2f}")
    if ci < countryTotal: wf("    },\n")
    else: wf("    }\n")
  wf("  },\n")

  wf("  \"professions\": {\n")
  var pi = 0
  let profTotal = professions.len
  for name, ps in professions:
    pi.inc
    let pa = ps.totalSalary / ps.count.float64
    wl(fmt"    ""{name}"": {{")
    wl(fmt"      ""count"": {ps.count},")
    wl(fmt"      ""average_salary"": {pa:.2f}")
    if pi < profTotal: wf("    },\n")
    else: wf("    }\n")
  wf("  }\n")
  wf("}\n")
  outFile.close()

  let jsonSizeBytes = getFileSize(outputPath)

  let endTime = getMonoTime()
  let elapsed = (endTime - startTime).inNanoseconds.float64 / 1e9
  let rowsPerSec = if elapsed > 0: int64(rowsProcessed.float64 / elapsed) else: 0'i64

  # Peak memory via getrusage
  var usage: Rusage
  discard getrusage(0.cint, addr usage)
  let peakRss = usage.ru_maxrss

  echo "=================================================="
  echo "Benchmark Complete"
  echo "=================================================="
  echo ""
  echo "Language           : Nim"
  echo ""
  echo fmt"Rows Processed     : {rowsProcessed}"
  echo fmt"Invalid Rows       : {invalidRows}"
  echo ""
  echo fmt"CSV Size           : {formatSize(csvSizeBytes)}"
  echo fmt"JSON Size          : {formatSize(jsonSizeBytes)}"
  echo ""
  echo fmt"Execution Time     : {elapsed:.3f} seconds"
  echo ""
  echo fmt"Rows / Second      : {rowsPerSec}"
  echo ""
  echo fmt"Peak Memory        : {formatSize(peakRss)}"
  echo ""
  echo fmt"Output File        : {outputPath}"
  echo ""
  echo "=================================================="

main()
