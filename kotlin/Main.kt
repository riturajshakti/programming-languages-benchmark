import java.io.File
import java.io.FileInputStream
import java.io.PrintWriter
import java.io.BufferedWriter
import java.io.FileWriter

const val CSV_PATH = "../users-big.csv"

data class User(
    val id: String,
    val name: String,
    val email: String,
    val country: String,
    val age: Int,
    val profession: String,
    val salary: Double
)

class CountryStats {
    var count = 0
    var totalSalary = 0.0
    var totalAge = 0L
}

class ProfessionStats {
    var count = 0
    var totalSalary = 0.0
}

fun formatSize(bytes: Long): String {
    val b = bytes.toDouble()
    return when {
        b >= 1_073_741_824 -> "%.2f GB".format(b / 1_073_741_824)
        b >= 1_048_576 -> "%.2f MB".format(b / 1_048_576)
        b >= 1024 -> "%.2f KB".format(b / 1024)
        else -> "$bytes B"
    }
}

fun printProgress(bytesRead: Long, totalBytes: Long, rows: Long, startNs: Long) {
    val now = System.nanoTime()
    val elapsed = (now - startNs) / 1e9
    val rowsPerSec = if (elapsed > 0) (rows / elapsed).toLong() else 0L
    val mbPerSec = if (elapsed > 0) bytesRead / 1_048_576.0 / elapsed else 0.0
    val percent = if (totalBytes > 0) bytesRead.toDouble() / totalBytes * 100 else 0.0

    val barWidth = 30
    var filled = if (totalBytes > 0) (barWidth.toDouble() * bytesRead / totalBytes).toInt() else 0
    if (filled > barWidth) filled = barWidth

    val bar = "\u2588".repeat(filled) + "\u2591".repeat(barWidth - filled)
    print("\r[$bar] ${"%.2f".format(percent)}% | $rows rows | $rowsPerSec rows/sec | ${"%.2f".format(mbPerSec)} MB/s    ")
    System.out.flush()
}

fun main() {
    val csvPath = CSV_PATH

    println("==================================================")
    println("Cross-Language Benchmark")
    println("Language : Kotlin")
    println("==================================================")
    println()
    println("Input File : $csvPath")
    println()

    val file = File(csvPath)
    if (!file.exists()) {
        System.err.println("Error:\nUnable to open $csvPath")
        System.exit(1)
    }
    val csvSizeBytes = file.length()

    // Start timing
    val startNs = System.nanoTime()

    var rowsProcessed = 0L
    var invalidRows = 0L
    var bytesRead = 0L

    var totalSalary = 0.0
    var minSalary = Double.MAX_VALUE
    var maxSalary = -Double.MAX_VALUE
    var totalAge = 0L

    val countries = HashMap<String, CountryStats>()
    val professions = HashMap<String, ProfessionStats>()

    // Streaming read with 8MB buffer
    val fis = FileInputStream(file)
    val buf = ByteArray(8 * 1024 * 1024)
    val leftover = StringBuilder()
    var headerSkipped = false
    var lastProgressNs = startNs

    try {
        while (true) {
            val n = fis.read(buf)
            if (n <= 0) {
                // Process remaining leftover
                if (leftover.isNotEmpty() && headerSkipped) {
                    var line = leftover.toString()
                    while (line.endsWith("\r") || line.endsWith("\n")) {
                        line = line.dropLast(1)
                    }
                    if (line.isNotEmpty()) {
                        val fields = splitLine(line)
                        if (fields != null) {
                            val result = processFields(fields, totalSalary, minSalary, maxSalary, totalAge, countries, professions)
                            if (result != null) {
                                totalSalary = result[0]
                                minSalary = result[1]
                                maxSalary = result[2]
                                totalAge = result[3].toLong()
                            } else {
                                invalidRows++
                            }
                        } else {
                            invalidRows++
                        }
                        rowsProcessed++
                    }
                }
                break
            }

            bytesRead += n
            val chunk = String(buf, 0, n, Charsets.UTF_8)

            val data: String
            if (leftover.isNotEmpty()) {
                leftover.append(chunk)
                data = leftover.toString()
                leftover.clear()
            } else {
                data = chunk
            }

            var lineStart = 0
            for (i in data.indices) {
                if (data[i] == '\n') {
                    var lineEnd = i
                    if (lineEnd > lineStart && data[lineEnd - 1] == '\r') {
                        lineEnd--
                    }
                    val line = data.substring(lineStart, lineEnd)
                    lineStart = i + 1

                    if (!headerSkipped) {
                        headerSkipped = true
                        continue
                    }
                    if (line.isEmpty()) continue

                    val fields = splitLine(line)
                    if (fields == null) {
                        invalidRows++
                        rowsProcessed++
                        continue
                    }

                    val id = fields[0]
                    val email = fields[2]
                    val country = fields[3]
                    val ageStr = fields[4]
                    val profession = fields[5]
                    val salaryStr = fields[6]

                    if (id.isEmpty() || !email.contains('@')) {
                        invalidRows++
                        rowsProcessed++
                        continue
                    }

                    val age = ageStr.toIntOrNull()
                    if (age == null) {
                        invalidRows++
                        rowsProcessed++
                        continue
                    }

                    val salary = salaryStr.toDoubleOrNull()
                    if (salary == null) {
                        invalidRows++
                        rowsProcessed++
                        continue
                    }

                    // Create user object
                    val user = User(id, fields[1], email, country, age, profession, salary)
                    user.hashCode()

                    // Statistics
                    totalSalary += salary
                    if (salary < minSalary) minSalary = salary
                    if (salary > maxSalary) maxSalary = salary
                    totalAge += age

                    // Country grouping
                    val cs = countries.getOrPut(country) { CountryStats() }
                    cs.count++
                    cs.totalSalary += salary
                    cs.totalAge += age

                    // Profession grouping
                    val ps = professions.getOrPut(profession) { ProfessionStats() }
                    ps.count++
                    ps.totalSalary += salary

                    rowsProcessed++
                }
            }

            // Save leftover
            if (lineStart < data.length) {
                leftover.append(data, lineStart, data.length)
            }

            // Progress every 50ms
            val now = System.nanoTime()
            if (now - lastProgressNs >= 50_000_000L) {
                printProgress(bytesRead, csvSizeBytes, rowsProcessed, startNs)
                lastProgressNs = now
            }
        }
    } finally {
        fis.close()
    }

    // Final progress
    printProgress(csvSizeBytes, csvSizeBytes, rowsProcessed, startNs)
    println("\n")

    val validRows = rowsProcessed - invalidRows
    val avgSalary = if (validRows > 0) totalSalary / validRows else 0.0
    val avgAge = if (validRows > 0) totalAge.toDouble() / validRows else 0.0
    if (minSalary == Double.MAX_VALUE) minSalary = 0.0
    if (maxSalary == -Double.MAX_VALUE) maxSalary = 0.0

    // Find highest/lowest paid profession
    var highestProf = ""
    var highestAvg = -Double.MAX_VALUE
    var lowestProf = ""
    var lowestAvg = Double.MAX_VALUE

    for ((name, ps) in professions) {
        val avg = ps.totalSalary / ps.count
        if (avg > highestAvg) { highestAvg = avg; highestProf = name }
        if (avg < lowestAvg) { lowestAvg = avg; lowestProf = name }
    }

    // Write JSON
    val outputPath = "result.json"
    PrintWriter(BufferedWriter(FileWriter(outputPath))).use { pw ->
        pw.println("{")
        pw.println("  \"summary\": {")
        pw.println("    \"total_records\": $rowsProcessed,")
        pw.println("    \"valid_records\": $validRows,")
        pw.println("    \"invalid_records\": $invalidRows,")
        pw.println("    \"average_salary\": ${"%.2f".format(avgSalary)},")
        pw.println("    \"min_salary\": ${"%.2f".format(minSalary)},")
        pw.println("    \"max_salary\": ${"%.2f".format(maxSalary)},")
        pw.println("    \"average_age\": ${"%.2f".format(avgAge)},")
        pw.println("    \"highest_paid_profession\": \"$highestProf\",")
        pw.println("    \"lowest_paid_profession\": \"$lowestProf\"")
        pw.println("  },")

        pw.println("  \"countries\": {")
        val countryList = countries.entries.toList()
        for ((ci, entry) in countryList.withIndex()) {
            val cs = entry.value
            val ca = cs.totalSalary / cs.count
            val aa = cs.totalAge.toDouble() / cs.count
            pw.println("    \"${entry.key}\": {")
            pw.println("      \"total_users\": ${cs.count},")
            pw.println("      \"average_salary\": ${"%.2f".format(ca)},")
            pw.println("      \"average_age\": ${"%.2f".format(aa)}")
            pw.println(if (ci < countryList.size - 1) "    }," else "    }")
        }
        pw.println("  },")

        pw.println("  \"professions\": {")
        val profList = professions.entries.toList()
        for ((pi, entry) in profList.withIndex()) {
            val ps = entry.value
            val pa = ps.totalSalary / ps.count
            pw.println("    \"${entry.key}\": {")
            pw.println("      \"count\": ${ps.count},")
            pw.println("      \"average_salary\": ${"%.2f".format(pa)}")
            pw.println(if (pi < profList.size - 1) "    }," else "    }")
        }
        pw.println("  }")
        pw.println("}")
    }

    val jsonSizeBytes = File(outputPath).length()

    val endNs = System.nanoTime()
    val elapsed = (endNs - startNs) / 1e9
    val rowsPerSec = if (elapsed > 0) (rowsProcessed / elapsed).toLong() else 0L

    // Peak memory
    val rt = Runtime.getRuntime()
    val peakMemory = rt.totalMemory() - rt.freeMemory()

    println("==================================================")
    println("Benchmark Complete")
    println("==================================================")
    println()
    println("Language           : Kotlin")
    println()
    println("Rows Processed     : $rowsProcessed")
    println("Invalid Rows       : $invalidRows")
    println()
    println("CSV Size           : ${formatSize(csvSizeBytes)}")
    println("JSON Size          : ${formatSize(jsonSizeBytes)}")
    println()
    println("Execution Time     : ${"%.3f".format(elapsed)} seconds")
    println()
    println("Rows / Second      : $rowsPerSec")
    println()
    println("Peak Memory        : ${formatSize(peakMemory)}")
    println()
    println("Output File        : $outputPath")
    println()
    println("==================================================")
}

fun splitLine(line: String): Array<String>? {
    val fields = Array(7) { "" }
    var start = 0
    for (f in 0..5) {
        val comma = line.indexOf(',', start)
        if (comma == -1) return null
        fields[f] = line.substring(start, comma)
        start = comma + 1
    }
    fields[6] = line.substring(start)
    return fields
}

fun processFields(
    fields: Array<String>,
    totalSalary: Double, minSalary: Double, maxSalary: Double, totalAge: Long,
    countries: HashMap<String, CountryStats>,
    professions: HashMap<String, ProfessionStats>
): DoubleArray? {
    val id = fields[0]
    val email = fields[2]
    if (id.isEmpty() || !email.contains('@')) return null

    val age = fields[4].toIntOrNull() ?: return null
    val salary = fields[6].toDoubleOrNull() ?: return null

    var ts = totalSalary + salary
    var mins = if (salary < minSalary) salary else minSalary
    var maxs = if (salary > maxSalary) salary else maxSalary
    var ta = (totalAge + age).toDouble()

    val cs = countries.getOrPut(fields[3]) { CountryStats() }
    cs.count++; cs.totalSalary += salary; cs.totalAge += age

    val ps = professions.getOrPut(fields[5]) { ProfessionStats() }
    ps.count++; ps.totalSalary += salary

    return doubleArrayOf(ts, mins, maxs, ta)
}
