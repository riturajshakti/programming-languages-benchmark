using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Text;

const string CSV_PATH = "../users-big.csv";

static string FormatSize(long bytes)
{
    double b = bytes;
    if (b >= 1_073_741_824) return $"{b / 1_073_741_824:F2} GB";
    if (b >= 1_048_576) return $"{b / 1_048_576:F2} MB";
    if (b >= 1024) return $"{b / 1024:F2} KB";
    return $"{bytes} B";
}

static void PrintProgress(long bytesRead, long totalBytes, long rows, Stopwatch sw)
{
    double elapsed = sw.Elapsed.TotalSeconds;
    long rowsPerSec = elapsed > 0 ? (long)(rows / elapsed) : 0;
    double mbPerSec = elapsed > 0 ? bytesRead / 1_048_576.0 / elapsed : 0;
    double percent = totalBytes > 0 ? (double)bytesRead / totalBytes * 100 : 0;

    int barWidth = 30;
    int filled = totalBytes > 0 ? (int)((double)barWidth * bytesRead / totalBytes) : 0;
    if (filled > barWidth) filled = barWidth;

    var bar = new string('\u2588', filled) + new string('\u2591', barWidth - filled);
    Console.Write($"\r[{bar}] {percent:F2}% | {rows} rows | {rowsPerSec} rows/sec | {mbPerSec:F2} MB/s    ");
}

static void ProcessLine(string line, ref long rowsProcessed, ref long invalidRows,
    ref double totalSalary, ref double minSalary, ref double maxSalary,
    ref long totalAge, Dictionary<string, CountryStats> countries,
    Dictionary<string, ProfessionStats> professions)
{
    int c1 = line.IndexOf(',');
    if (c1 < 0) { invalidRows++; rowsProcessed++; return; }
    int c2 = line.IndexOf(',', c1 + 1);
    if (c2 < 0) { invalidRows++; rowsProcessed++; return; }
    int c3 = line.IndexOf(',', c2 + 1);
    if (c3 < 0) { invalidRows++; rowsProcessed++; return; }
    int c4 = line.IndexOf(',', c3 + 1);
    if (c4 < 0) { invalidRows++; rowsProcessed++; return; }
    int c5 = line.IndexOf(',', c4 + 1);
    if (c5 < 0) { invalidRows++; rowsProcessed++; return; }
    int c6 = line.IndexOf(',', c5 + 1);
    if (c6 < 0) { invalidRows++; rowsProcessed++; return; }

    string id = line.Substring(0, c1);
    string name = line.Substring(c1 + 1, c2 - c1 - 1);
    string email = line.Substring(c2 + 1, c3 - c2 - 1);
    string country = line.Substring(c3 + 1, c4 - c3 - 1);
    string ageStr = line.Substring(c4 + 1, c5 - c4 - 1);
    string profession = line.Substring(c5 + 1, c6 - c5 - 1);
    string salaryStr = line.Substring(c6 + 1);

    if (id.Length == 0 || !email.Contains('@'))
    { invalidRows++; rowsProcessed++; return; }

    if (!int.TryParse(ageStr, out int age))
    { invalidRows++; rowsProcessed++; return; }

    if (!double.TryParse(salaryStr, out double salary))
    { invalidRows++; rowsProcessed++; return; }

    var user = new User { Id = id, Name = name, Email = email, Country = country,
                          Age = age, Profession = profession, Salary = salary };
    _ = user;

    totalSalary += salary;
    if (salary < minSalary) minSalary = salary;
    if (salary > maxSalary) maxSalary = salary;
    totalAge += age;

    if (!countries.TryGetValue(country, out var cs))
    { cs = new CountryStats(); countries[country] = cs; }
    cs.Count++; cs.TotalSalary += salary; cs.TotalAge += age;

    if (!professions.TryGetValue(profession, out var ps))
    { ps = new ProfessionStats(); professions[profession] = ps; }
    ps.Count++; ps.TotalSalary += salary;

    rowsProcessed++;
}

// Main
Console.WriteLine("==================================================");
Console.WriteLine("Cross-Language Benchmark");
Console.WriteLine("Language : C#");
Console.WriteLine("==================================================");
Console.WriteLine();
Console.WriteLine($"Input File : {CSV_PATH}");
Console.WriteLine();

var fileInfo = new FileInfo(CSV_PATH);
if (!fileInfo.Exists)
{
    Console.Error.WriteLine($"Error:\nUnable to open {CSV_PATH}");
    Environment.Exit(1);
}
long csvSizeBytes = fileInfo.Length;

var sw = Stopwatch.StartNew();

long rowsProcessed = 0;
long invalidRows = 0;
long bytesRead = 0;

double totalSalary = 0;
double minSalary = double.MaxValue;
double maxSalary = double.MinValue;
long totalAge = 0;

var countries = new Dictionary<string, CountryStats>();
var professions = new Dictionary<string, ProfessionStats>();

using var fs = new FileStream(CSV_PATH, FileMode.Open, FileAccess.Read, FileShare.Read, 8 * 1024 * 1024);
byte[] buf = new byte[8 * 1024 * 1024];
var leftover = new StringBuilder();
bool headerSkipped = false;
long lastProgressMs = sw.ElapsedMilliseconds;

while (true)
{
    int n = fs.Read(buf, 0, buf.Length);
    if (n == 0)
    {
        if (leftover.Length > 0 && headerSkipped)
        {
            string line = leftover.ToString().TrimEnd('\r', '\n');
            if (line.Length > 0)
                ProcessLine(line, ref rowsProcessed, ref invalidRows, ref totalSalary,
                    ref minSalary, ref maxSalary, ref totalAge, countries, professions);
        }
        break;
    }

    bytesRead += n;
    string chunk = Encoding.UTF8.GetString(buf, 0, n);

    string data;
    if (leftover.Length > 0)
    {
        leftover.Append(chunk);
        data = leftover.ToString();
        leftover.Clear();
    }
    else
    {
        data = chunk;
    }

    int lineStart = 0;
    for (int i = 0; i < data.Length; i++)
    {
        if (data[i] == '\n')
        {
            int lineEnd = i;
            if (lineEnd > lineStart && data[lineEnd - 1] == '\r')
                lineEnd--;
            string line = data.Substring(lineStart, lineEnd - lineStart);
            lineStart = i + 1;

            if (!headerSkipped) { headerSkipped = true; continue; }
            if (line.Length == 0) continue;

            ProcessLine(line, ref rowsProcessed, ref invalidRows, ref totalSalary,
                ref minSalary, ref maxSalary, ref totalAge, countries, professions);
        }
    }

    if (lineStart < data.Length)
        leftover.Append(data, lineStart, data.Length - lineStart);

    long nowMs = sw.ElapsedMilliseconds;
    if (nowMs - lastProgressMs >= 50)
    {
        PrintProgress(bytesRead, csvSizeBytes, rowsProcessed, sw);
        lastProgressMs = nowMs;
    }
}

PrintProgress(csvSizeBytes, csvSizeBytes, rowsProcessed, sw);
Console.WriteLine("\n");

long validRows = rowsProcessed - invalidRows;
double avgSalary = validRows > 0 ? totalSalary / validRows : 0;
double avgAge = validRows > 0 ? (double)totalAge / validRows : 0;
if (minSalary == double.MaxValue) minSalary = 0;
if (maxSalary == double.MinValue) maxSalary = 0;

string highestProf = "", lowestProf = "";
double highestAvg = double.MinValue, lowestAvg = double.MaxValue;

foreach (var kv in professions)
{
    double avg = kv.Value.TotalSalary / kv.Value.Count;
    if (avg > highestAvg) { highestAvg = avg; highestProf = kv.Key; }
    if (avg < lowestAvg) { lowestAvg = avg; lowestProf = kv.Key; }
}

string outputPath = "result.json";
using (var writer = new StreamWriter(outputPath))
{
    writer.WriteLine("{");
    writer.WriteLine("  \"summary\": {");
    writer.WriteLine($"    \"total_records\": {rowsProcessed},");
    writer.WriteLine($"    \"valid_records\": {validRows},");
    writer.WriteLine($"    \"invalid_records\": {invalidRows},");
    writer.WriteLine($"    \"average_salary\": {avgSalary:F2},");
    writer.WriteLine($"    \"min_salary\": {minSalary:F2},");
    writer.WriteLine($"    \"max_salary\": {maxSalary:F2},");
    writer.WriteLine($"    \"average_age\": {avgAge:F2},");
    writer.WriteLine($"    \"highest_paid_profession\": \"{highestProf}\",");
    writer.WriteLine($"    \"lowest_paid_profession\": \"{lowestProf}\"");
    writer.WriteLine("  },");

    writer.WriteLine("  \"countries\": {");
    int ci = 0, countryTotal = countries.Count;
    foreach (var kv in countries)
    {
        ci++;
        double ca = kv.Value.TotalSalary / kv.Value.Count;
        double aa = (double)kv.Value.TotalAge / kv.Value.Count;
        writer.WriteLine($"    \"{kv.Key}\": {{");
        writer.WriteLine($"      \"total_users\": {kv.Value.Count},");
        writer.WriteLine($"      \"average_salary\": {ca:F2},");
        writer.WriteLine($"      \"average_age\": {aa:F2}");
        writer.WriteLine(ci < countryTotal ? "    }," : "    }");
    }
    writer.WriteLine("  },");

    writer.WriteLine("  \"professions\": {");
    int pi = 0, profTotal = professions.Count;
    foreach (var kv in professions)
    {
        pi++;
        double pa = kv.Value.TotalSalary / kv.Value.Count;
        writer.WriteLine($"    \"{kv.Key}\": {{");
        writer.WriteLine($"      \"count\": {kv.Value.Count},");
        writer.WriteLine($"      \"average_salary\": {pa:F2}");
        writer.WriteLine(pi < profTotal ? "    }," : "    }");
    }
    writer.WriteLine("  }");
    writer.WriteLine("}");
}

sw.Stop();
long jsonSizeBytes = new FileInfo(outputPath).Length;
double elapsed = sw.Elapsed.TotalSeconds;
long rowsPerSec = elapsed > 0 ? (long)(rowsProcessed / elapsed) : 0;

long peakMemory = Process.GetCurrentProcess().WorkingSet64;
if (peakMemory == 0) peakMemory = GC.GetTotalMemory(false);

Console.WriteLine("==================================================");
Console.WriteLine("Benchmark Complete");
Console.WriteLine("==================================================");
Console.WriteLine();
Console.WriteLine("Language           : C#");
Console.WriteLine();
Console.WriteLine($"Rows Processed     : {rowsProcessed}");
Console.WriteLine($"Invalid Rows       : {invalidRows}");
Console.WriteLine();
Console.WriteLine($"CSV Size           : {FormatSize(csvSizeBytes)}");
Console.WriteLine($"JSON Size          : {FormatSize(jsonSizeBytes)}");
Console.WriteLine();
Console.WriteLine($"Execution Time     : {elapsed:F3} seconds");
Console.WriteLine();
Console.WriteLine($"Rows / Second      : {rowsPerSec}");
Console.WriteLine();
Console.WriteLine($"Peak Memory        : {FormatSize(peakMemory)}");
Console.WriteLine();
Console.WriteLine($"Output File        : {outputPath}");
Console.WriteLine();
Console.WriteLine("==================================================");

struct User
{
    public string Id, Name, Email, Country, Profession;
    public int Age;
    public double Salary;
}

class CountryStats
{
    public int Count;
    public double TotalSalary;
    public long TotalAge;
}

class ProfessionStats
{
    public int Count;
    public double TotalSalary;
}
