<?php

const CSV_PATH = '../users-big.csv';

class User {
    public function __construct(
        public string $id,
        public string $name,
        public string $email,
        public string $country,
        public int $age,
        public string $profession,
        public float $salary,
    ) {}
}

function formatSize(int $bytes): string {
    $b = (float)$bytes;
    if ($b >= 1073741824) return sprintf("%.2f GB", $b / 1073741824);
    if ($b >= 1048576) return sprintf("%.2f MB", $b / 1048576);
    if ($b >= 1024) return sprintf("%.2f KB", $b / 1024);
    return "$bytes B";
}

function printProgress(int $bytesRead, int $totalBytes, int $rows, float $startTime): void {
    $now = hrtime(true);
    $elapsed = ($now - $startTime) / 1e9;
    $rowsPerSec = $elapsed > 0 ? (int)($rows / $elapsed) : 0;
    $mbPerSec = $elapsed > 0 ? $bytesRead / 1048576 / $elapsed : 0;
    $percent = $totalBytes > 0 ? $bytesRead / $totalBytes * 100 : 0;

    $barWidth = 30;
    $filled = $totalBytes > 0 ? (int)($barWidth * $bytesRead / $totalBytes) : 0;
    if ($filled > $barWidth) $filled = $barWidth;

    $bar = str_repeat("\xe2\x96\x88", $filled) . str_repeat("\xe2\x96\x91", $barWidth - $filled);
    fprintf(STDOUT, "\r[%s] %.2f%% | %d rows | %d rows/sec | %.2f MB/s    ",
        $bar, $percent, $rows, $rowsPerSec, $mbPerSec);
}

function processLine(
    string $line,
    int &$rowsProcessed,
    int &$invalidRows,
    float &$totalSalary,
    float &$minSalary,
    float &$maxSalary,
    int &$totalAge,
    array &$countries,
    array &$professions,
): void {
    // Manual split into 7 fields
    $c1 = strpos($line, ',');
    if ($c1 === false) { $invalidRows++; $rowsProcessed++; return; }
    $c2 = strpos($line, ',', $c1 + 1);
    if ($c2 === false) { $invalidRows++; $rowsProcessed++; return; }
    $c3 = strpos($line, ',', $c2 + 1);
    if ($c3 === false) { $invalidRows++; $rowsProcessed++; return; }
    $c4 = strpos($line, ',', $c3 + 1);
    if ($c4 === false) { $invalidRows++; $rowsProcessed++; return; }
    $c5 = strpos($line, ',', $c4 + 1);
    if ($c5 === false) { $invalidRows++; $rowsProcessed++; return; }
    $c6 = strpos($line, ',', $c5 + 1);
    if ($c6 === false) { $invalidRows++; $rowsProcessed++; return; }

    $id = substr($line, 0, $c1);
    $name = substr($line, $c1 + 1, $c2 - $c1 - 1);
    $email = substr($line, $c2 + 1, $c3 - $c2 - 1);
    $country = substr($line, $c3 + 1, $c4 - $c3 - 1);
    $ageStr = substr($line, $c4 + 1, $c5 - $c4 - 1);
    $profession = substr($line, $c5 + 1, $c6 - $c5 - 1);
    $salaryStr = rtrim(substr($line, $c6 + 1), "\r");

    // Validation
    if ($id === '' || strpos($email, '@') === false) {
        $invalidRows++;
        $rowsProcessed++;
        return;
    }

    if (!is_numeric($ageStr)) {
        $invalidRows++;
        $rowsProcessed++;
        return;
    }
    $age = (int)$ageStr;

    if (!is_numeric($salaryStr)) {
        $invalidRows++;
        $rowsProcessed++;
        return;
    }
    $salary = (float)$salaryStr;

    // Create user object
    $user = new User($id, $name, $email, $country, $age, $profession, $salary);
    unset($user);

    // Statistics
    $totalSalary += $salary;
    if ($salary < $minSalary) $minSalary = $salary;
    if ($salary > $maxSalary) $maxSalary = $salary;
    $totalAge += $age;

    // Country grouping
    if (!isset($countries[$country])) {
        $countries[$country] = ['count' => 0, 'total_salary' => 0.0, 'total_age' => 0];
    }
    $countries[$country]['count']++;
    $countries[$country]['total_salary'] += $salary;
    $countries[$country]['total_age'] += $age;

    // Profession grouping
    if (!isset($professions[$profession])) {
        $professions[$profession] = ['count' => 0, 'total_salary' => 0.0];
    }
    $professions[$profession]['count']++;
    $professions[$profession]['total_salary'] += $salary;

    $rowsProcessed++;
}

// Main
$csvPath = CSV_PATH;

echo "==================================================\n";
echo "Cross-Language Benchmark\n";
echo "Language : PHP\n";
echo "==================================================\n\n";
echo "Input File : $csvPath\n\n";

// Open file
$fp = fopen($csvPath, 'rb');
if (!$fp) {
    fwrite(STDERR, "Error:\nUnable to open $csvPath\n");
    exit(1);
}

// Get file size
$csvSizeBytes = filesize($csvPath);

// Start timing
$startTime = hrtime(true);

$rowsProcessed = 0;
$invalidRows = 0;
$bytesRead = 0;

$totalSalary = 0.0;
$minSalary = PHP_FLOAT_MAX;
$maxSalary = -PHP_FLOAT_MAX;
$totalAge = 0;

$countries = [];
$professions = [];

// Streaming read with 8MB buffer
$BUF_SIZE = 8 * 1024 * 1024;
$headerSkipped = false;
$leftover = '';
$lastProgressTime = $startTime;

while (true) {
    $chunk = fread($fp, $BUF_SIZE);
    if ($chunk === false || $chunk === '') {
        // Process remaining leftover
        if ($leftover !== '' && $headerSkipped) {
            $line = rtrim($leftover, "\r\n");
            if ($line !== '') {
                processLine($line, $rowsProcessed, $invalidRows, $totalSalary,
                    $minSalary, $maxSalary, $totalAge, $countries, $professions);
            }
        }
        break;
    }

    $bytesRead += strlen($chunk);

    if ($leftover !== '') {
        $data = $leftover . $chunk;
        $leftover = '';
    } else {
        $data = $chunk;
    }

    $dataLen = strlen($data);
    $lineStart = 0;

    for ($i = 0; $i < $dataLen; $i++) {
        if ($data[$i] === "\n") {
            $lineEnd = $i;
            if ($lineEnd > $lineStart && $data[$lineEnd - 1] === "\r") {
                $lineEnd--;
            }
            $line = substr($data, $lineStart, $lineEnd - $lineStart);
            $lineStart = $i + 1;

            if (!$headerSkipped) {
                $headerSkipped = true;
                continue;
            }
            if ($line === '') continue;

            processLine($line, $rowsProcessed, $invalidRows, $totalSalary,
                $minSalary, $maxSalary, $totalAge, $countries, $professions);
        }
    }

    // Save leftover
    if ($lineStart < $dataLen) {
        $leftover = substr($data, $lineStart);
    } else {
        $leftover = '';
    }

    // Progress every 50ms
    $now = hrtime(true);
    if (($now - $lastProgressTime) >= 50000000) {
        printProgress($bytesRead, $csvSizeBytes, $rowsProcessed, $startTime);
        $lastProgressTime = $now;
    }
}

fclose($fp);

// Final progress
printProgress($csvSizeBytes, $csvSizeBytes, $rowsProcessed, $startTime);
echo "\n\n";

$validRows = $rowsProcessed - $invalidRows;
$avgSalary = $validRows > 0 ? $totalSalary / $validRows : 0;
$avgAge = $validRows > 0 ? $totalAge / $validRows : 0;
if ($minSalary === PHP_FLOAT_MAX) $minSalary = 0;
if ($maxSalary === -PHP_FLOAT_MAX) $maxSalary = 0;

// Find highest/lowest paid profession
$highestProf = '';
$highestAvg = -PHP_FLOAT_MAX;
$lowestProf = '';
$lowestAvg = PHP_FLOAT_MAX;

foreach ($professions as $name => $ps) {
    $avg = $ps['total_salary'] / $ps['count'];
    if ($avg > $highestAvg) { $highestAvg = $avg; $highestProf = $name; }
    if ($avg < $lowestAvg) { $lowestAvg = $avg; $lowestProf = $name; }
}

// Write JSON
$outputPath = 'result.json';
$out = fopen($outputPath, 'w');

fwrite($out, "{\n");
fwrite($out, "  \"summary\": {\n");
fprintf($out, "    \"total_records\": %d,\n", $rowsProcessed);
fprintf($out, "    \"valid_records\": %d,\n", $validRows);
fprintf($out, "    \"invalid_records\": %d,\n", $invalidRows);
fprintf($out, "    \"average_salary\": %.2f,\n", $avgSalary);
fprintf($out, "    \"min_salary\": %.2f,\n", $minSalary);
fprintf($out, "    \"max_salary\": %.2f,\n", $maxSalary);
fprintf($out, "    \"average_age\": %.2f,\n", $avgAge);
fprintf($out, "    \"highest_paid_profession\": \"%s\",\n", $highestProf);
fprintf($out, "    \"lowest_paid_profession\": \"%s\"\n", $lowestProf);
fwrite($out, "  },\n");

fwrite($out, "  \"countries\": {\n");
$ci = 0;
$countryTotal = count($countries);
foreach ($countries as $name => $cs) {
    $ci++;
    $ca = $cs['total_salary'] / $cs['count'];
    $aa = $cs['total_age'] / $cs['count'];
    fprintf($out, "    \"%s\": {\n", $name);
    fprintf($out, "      \"total_users\": %d,\n", $cs['count']);
    fprintf($out, "      \"average_salary\": %.2f,\n", $ca);
    fprintf($out, "      \"average_age\": %.2f\n", $aa);
    fwrite($out, $ci < $countryTotal ? "    },\n" : "    }\n");
}
fwrite($out, "  },\n");

fwrite($out, "  \"professions\": {\n");
$pi = 0;
$profTotal = count($professions);
foreach ($professions as $name => $ps) {
    $pi++;
    $pa = $ps['total_salary'] / $ps['count'];
    fprintf($out, "    \"%s\": {\n", $name);
    fprintf($out, "      \"count\": %d,\n", $ps['count']);
    fprintf($out, "      \"average_salary\": %.2f\n", $pa);
    fwrite($out, $pi < $profTotal ? "    },\n" : "    }\n");
}
fwrite($out, "  }\n");
fwrite($out, "}\n");

$jsonSizeBytes = ftell($out);
fclose($out);

$endTime = hrtime(true);
$elapsed = ($endTime - $startTime) / 1e9;
$rowsPerSec = $elapsed > 0 ? (int)($rowsProcessed / $elapsed) : 0;

// Peak memory
$peakMemory = memory_get_peak_usage(true);

echo "==================================================\n";
echo "Benchmark Complete\n";
echo "==================================================\n\n";
echo "Language           : PHP\n\n";
echo "Rows Processed     : $rowsProcessed\n";
echo "Invalid Rows       : $invalidRows\n\n";
echo "CSV Size           : " . formatSize($csvSizeBytes) . "\n";
echo "JSON Size          : " . formatSize($jsonSizeBytes) . "\n\n";
printf("Execution Time     : %.3f seconds\n\n", $elapsed);
echo "Rows / Second      : $rowsPerSec\n\n";
echo "Peak Memory        : " . formatSize($peakMemory) . "\n\n";
echo "Output File        : $outputPath\n\n";
echo "==================================================\n";
