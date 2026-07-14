import std.stdio;
import std.conv;
import std.string;
import std.file;
import std.datetime;
import core.sys.posix.sys.resource;
import core.stdc.stdio : fopen, fwrite, fclose, ftell, FILE;

enum CSV_PATH = "../users-big.csv";

struct User {
    string id, name, email, country, profession;
    int age;
    double salary;
}

struct CountryStats {
    int count;
    double totalSalary;
    long totalAge;
}

struct ProfessionStats {
    int count;
    double totalSalary;
}

string formatSize(ulong bytes) {
    double b = cast(double) bytes;
    if (b >= 1_073_741_824) return format("%.2f GB", b / 1_073_741_824);
    if (b >= 1_048_576) return format("%.2f MB", b / 1_048_576);
    if (b >= 1024) return format("%.2f KB", b / 1024);
    return format("%d B", bytes);
}

void printProgress(ulong bytesRead, ulong totalBytes, ulong rows, MonoTime startTime) {
    auto now = MonoTime.currTime;
    double elapsed = (now - startTime).total!"nsecs" / 1e9;
    ulong rowsPerSec = elapsed > 0 ? cast(ulong)(rows / elapsed) : 0;
    double mbPerSec = elapsed > 0 ? bytesRead / 1_048_576.0 / elapsed : 0;
    double percent = totalBytes > 0 ? cast(double) bytesRead / totalBytes * 100 : 0;

    enum barWidth = 30;
    int filled = totalBytes > 0 ? cast(int)(cast(double) barWidth * bytesRead / totalBytes) : 0;
    if (filled > barWidth) filled = barWidth;

    char[barWidth * 3] bar;
    int pos = 0;
    foreach (i; 0 .. barWidth) {
        if (i < filled) {
            bar[pos] = 0xe2; bar[pos + 1] = 0x96; bar[pos + 2] = 0x88;
        } else {
            bar[pos] = 0xe2; bar[pos + 1] = 0x96; bar[pos + 2] = 0x91;
        }
        pos += 3;
    }

    writef("\r[%s] %.2f%% | %d rows | %d rows/sec | %.2f MB/s    ",
        cast(string) bar[0 .. pos], percent, rows, rowsPerSec, mbPerSec);
    stdout.flush();
}

void processLine(
    string line,
    ref ulong rowsProcessed,
    ref ulong invalidRows,
    ref double totalSalary,
    ref double minSalary,
    ref double maxSalary,
    ref long totalAge,
    ref CountryStats[string] countries,
    ref ProfessionStats[string] professions
) {
    // Manual split into 7 fields
    string[7] fields;
    size_t start = 0;
    foreach (f; 0 .. 6) {
        auto idx = line[start .. $].indexOf(',');
        if (idx < 0) {
            invalidRows++;
            rowsProcessed++;
            return;
        }
        fields[f] = line[start .. start + idx];
        start = start + idx + 1;
    }
    fields[6] = line[start .. $];

    string id = fields[0];
    string email = fields[2];
    string country = fields[3];
    string ageStr = fields[4];
    string profession = fields[5];
    string salaryStr = fields[6].stripRight("\r");

    // Validation
    if (id.length == 0 || email.indexOf('@') < 0) {
        invalidRows++;
        rowsProcessed++;
        return;
    }

    int age;
    try {
        age = to!int(ageStr);
    } catch (Exception) {
        invalidRows++;
        rowsProcessed++;
        return;
    }

    double salary;
    try {
        salary = to!double(salaryStr);
    } catch (Exception) {
        invalidRows++;
        rowsProcessed++;
        return;
    }

    // Create user struct
    auto user = User(id, fields[1], email, country, profession, age, salary);
    cast(void) user;

    // Statistics
    totalSalary += salary;
    if (salary < minSalary) minSalary = salary;
    if (salary > maxSalary) maxSalary = salary;
    totalAge += age;

    // Country grouping
    if (auto cs = country in countries) {
        cs.count++;
        cs.totalSalary += salary;
        cs.totalAge += age;
    } else {
        countries[country] = CountryStats(1, salary, age);
    }

    // Profession grouping
    if (auto ps = profession in professions) {
        ps.count++;
        ps.totalSalary += salary;
    } else {
        professions[profession] = ProfessionStats(1, salary);
    }

    rowsProcessed++;
}

void main() {
    enum csvPath = CSV_PATH;

    writeln("==================================================");
    writeln("Cross-Language Benchmark");
    writeln("Language : D");
    writeln("==================================================");
    writeln();
    writefln("Input File : %s", csvPath);
    writeln();

    // Open file
    auto fp = fopen(csvPath.ptr, "r");
    if (fp is null) {
        stderr.writefln("Error:\nUnable to open %s", csvPath);
        import core.stdc.stdlib : exit;
        exit(1);
    }

    ulong csvSizeBytes = std.file.getSize(csvPath);

    // Start timing
    auto startTime = MonoTime.currTime;

    ulong rowsProcessed = 0;
    ulong invalidRows = 0;
    ulong bytesRead = 0;

    double totalSalary = 0;
    double minSalary = double.max;
    double maxSalary = -double.max;
    long totalAge = 0;

    CountryStats[string] countries;
    ProfessionStats[string] professions;

    // Streaming read with 8MB buffer
    enum BUF_SIZE = 8 * 1024 * 1024;
    auto buf = new ubyte[](BUF_SIZE);
    char[4096] leftoverBuf;
    int leftoverLen = 0;
    bool headerSkipped = false;
    auto lastProgressTime = startTime;

    import core.stdc.stdio : fread;

    while (true) {
        auto n = fread(buf.ptr, 1, BUF_SIZE, fp);
        if (n == 0) {
            // Process remaining leftover
            if (leftoverLen > 0 && headerSkipped) {
                string lo = cast(string) leftoverBuf[0 .. leftoverLen];
                lo = lo.stripRight("\r\n");
                if (lo.length > 0) {
                    processLine(lo, rowsProcessed, invalidRows, totalSalary,
                        minSalary, maxSalary, totalAge, countries, professions);
                }
            }
            break;
        }

        bytesRead += n;
        auto chunk = cast(string) buf[0 .. n];

        string data;
        if (leftoverLen > 0) {
            // Combine leftover + chunk
            auto combined = new char[](leftoverLen + n);
            combined[0 .. leftoverLen] = leftoverBuf[0 .. leftoverLen];
            combined[leftoverLen .. leftoverLen + n] = cast(char[])(buf[0 .. n]);
            data = cast(string) combined;
            leftoverLen = 0;
        } else {
            data = chunk;
        }

        size_t lineStart = 0;
        foreach (i; 0 .. data.length) {
            if (data[i] == '\n') {
                auto segment = data[lineStart .. i];
                string line = segment.stripRight("\r");

                if (!headerSkipped) {
                    headerSkipped = true;
                } else if (line.length > 0) {
                    processLine(line, rowsProcessed, invalidRows, totalSalary,
                        minSalary, maxSalary, totalAge, countries, professions);
                }

                lineStart = i + 1;
            }
        }

        // Save leftover
        if (lineStart < data.length) {
            auto remaining = data.length - lineStart;
            auto copyLen = remaining < leftoverBuf.length ? remaining : leftoverBuf.length;
            leftoverBuf[0 .. copyLen] = cast(char[])(data[lineStart .. lineStart + copyLen]);
            leftoverLen = cast(int) copyLen;
        } else {
            leftoverLen = 0;
        }

        // Progress every 50ms
        auto now = MonoTime.currTime;
        if ((now - lastProgressTime).total!"msecs" >= 50) {
            printProgress(bytesRead, csvSizeBytes, rowsProcessed, startTime);
            lastProgressTime = now;
        }
    }

    fclose(fp);

    // Final progress
    printProgress(csvSizeBytes, csvSizeBytes, rowsProcessed, startTime);
    writeln("\n");

    ulong validRows = rowsProcessed - invalidRows;
    double avgSalary = validRows > 0 ? totalSalary / validRows : 0;
    double avgAge = validRows > 0 ? cast(double) totalAge / validRows : 0;
    if (minSalary == double.max) minSalary = 0;
    if (maxSalary == -double.max) maxSalary = 0;

    // Find highest/lowest paid profession
    string highestProf, lowestProf;
    double highestAvg = -double.max, lowestAvg = double.max;

    foreach (name, ref ps; professions) {
        double avg = ps.totalSalary / ps.count;
        if (avg > highestAvg) { highestAvg = avg; highestProf = name; }
        if (avg < lowestAvg) { lowestAvg = avg; lowestProf = name; }
    }

    // Write JSON
    enum outputPath = "result.json";
    auto outFile = File(outputPath, "w");

    outFile.writeln("{");
    outFile.writeln("  \"summary\": {");
    outFile.writefln("    \"total_records\": %d,", rowsProcessed);
    outFile.writefln("    \"valid_records\": %d,", validRows);
    outFile.writefln("    \"invalid_records\": %d,", invalidRows);
    outFile.writefln("    \"average_salary\": %.2f,", avgSalary);
    outFile.writefln("    \"min_salary\": %.2f,", minSalary);
    outFile.writefln("    \"max_salary\": %.2f,", maxSalary);
    outFile.writefln("    \"average_age\": %.2f,", avgAge);
    outFile.writefln("    \"highest_paid_profession\": \"%s\",", highestProf);
    outFile.writefln("    \"lowest_paid_profession\": \"%s\"", lowestProf);
    outFile.writeln("  },");

    outFile.writeln("  \"countries\": {");
    int ci = 0;
    auto countryTotal = cast(int) countries.length;
    foreach (name, ref cs; countries) {
        ci++;
        double ca = cs.totalSalary / cs.count;
        double aa = cast(double) cs.totalAge / cs.count;
        outFile.writefln("    \"%s\": {", name);
        outFile.writefln("      \"total_users\": %d,", cs.count);
        outFile.writefln("      \"average_salary\": %.2f,", ca);
        outFile.writefln("      \"average_age\": %.2f", aa);
        outFile.writeln(ci < countryTotal ? "    }," : "    }");
    }
    outFile.writeln("  },");

    outFile.writeln("  \"professions\": {");
    int pi = 0;
    auto profTotal = cast(int) professions.length;
    foreach (name, ref ps; professions) {
        pi++;
        double pa = ps.totalSalary / ps.count;
        outFile.writefln("    \"%s\": {", name);
        outFile.writefln("      \"count\": %d,", ps.count);
        outFile.writefln("      \"average_salary\": %.2f", pa);
        outFile.writeln(pi < profTotal ? "    }," : "    }");
    }
    outFile.writeln("  }");
    outFile.writeln("}");
    outFile.close();

    ulong jsonSizeBytes = std.file.getSize(outputPath);

    auto endTime = MonoTime.currTime;
    double elapsed = (endTime - startTime).total!"nsecs" / 1e9;
    ulong rowsPerSec = elapsed > 0 ? cast(ulong)(rowsProcessed / elapsed) : 0;

    // Peak memory via getrusage (macOS: ru_maxrss is first element of ru_opaque)
    rusage usage;
    getrusage(RUSAGE_SELF, &usage);
    ulong peakRss = cast(ulong) usage.ru_opaque[0];

    writeln("==================================================");
    writeln("Benchmark Complete");
    writeln("==================================================");
    writeln();
    writeln("Language           : D");
    writeln();
    writefln("Rows Processed     : %d", rowsProcessed);
    writefln("Invalid Rows       : %d", invalidRows);
    writeln();
    writefln("CSV Size           : %s", formatSize(csvSizeBytes));
    writefln("JSON Size          : %s", formatSize(jsonSizeBytes));
    writeln();
    writefln("Execution Time     : %.3f seconds", elapsed);
    writeln();
    writefln("Rows / Second      : %d", rowsPerSec);
    writeln();
    writefln("Peak Memory        : %s", formatSize(peakRss));
    writeln();
    writefln("Output File        : %s", outputPath);
    writeln();
    writeln("==================================================");
}
