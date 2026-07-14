const fs = require("fs");
const { createReadStream } = require("fs");

const CSV_PATH = "../users-big.csv";

function formatSize(bytes) {
  const b = Number(bytes);
  if (b >= 1_073_741_824) return (b / 1_073_741_824).toFixed(2) + " GB";
  if (b >= 1_048_576) return (b / 1_048_576).toFixed(2) + " MB";
  if (b >= 1024) return (b / 1024).toFixed(2) + " KB";
  return bytes + " B";
}

function printProgress(bytesRead, totalBytes, rows, startNs) {
  const now = process.hrtime.bigint();
  const elapsedNs = Number(now - startNs);
  const elapsed = elapsedNs / 1e9;
  const rowsPerSec = elapsed > 0 ? Math.floor(rows / elapsed) : 0;
  const mbPerSec = elapsed > 0 ? bytesRead / 1_048_576 / elapsed : 0;
  const percent = totalBytes > 0 ? (bytesRead / totalBytes) * 100 : 0;

  const barWidth = 30;
  let filled = totalBytes > 0 ? Math.floor((barWidth * bytesRead) / totalBytes) : 0;
  if (filled > barWidth) filled = barWidth;

  const bar = "\u2588".repeat(filled) + "\u2591".repeat(barWidth - filled);
  process.stdout.write(
    `\r[${bar}] ${percent.toFixed(2)}% | ${rows} rows | ${rowsPerSec} rows/sec | ${mbPerSec.toFixed(2)} MB/s    `
  );
}

function main() {
  const csvPath = CSV_PATH;

  console.log("==================================================");
  console.log("Cross-Language Benchmark");
  console.log("Language : Node.js");
  console.log("==================================================");
  console.log();
  console.log(`Input File : ${csvPath}`);
  console.log();

  // Check file exists
  let stat;
  try {
    stat = fs.statSync(csvPath);
  } catch {
    process.stderr.write(`Error:\nUnable to open ${csvPath}\n`);
    process.exit(1);
  }
  const csvSizeBytes = stat.size;

  // Start timing
  const startNs = process.hrtime.bigint();

  // Processing state
  let rowsProcessed = 0;
  let invalidRows = 0;
  let bytesRead = 0;

  let totalSalary = 0;
  let minSalary = Number.MAX_VALUE;
  let maxSalary = -Number.MAX_VALUE;
  let totalAge = 0;

  const countries = new Map();
  const professions = new Map();

  // Streaming read
  let headerSkipped = false;
  let leftover = "";
  let lastProgressNs = startNs;

  const fd = fs.openSync(csvPath, "r");
  const buf = Buffer.alloc(8 * 1024 * 1024);

  while (true) {
    const n = fs.readSync(fd, buf, 0, buf.length, null);
    if (n === 0) {
      // Process remaining leftover
      if (leftover.length > 0 && headerSkipped) {
        const line = leftover.replace(/\r?\n$/, "");
        if (line.length > 0) {
          processLine(line);
        }
      }
      break;
    }

    bytesRead += n;
    const chunk = buf.toString("utf8", 0, n);
    const data = leftover + chunk;
    leftover = "";

    let lineStart = 0;
    for (let i = 0; i < data.length; i++) {
      if (data.charCodeAt(i) === 10) {
        // \n
        let lineEnd = i;
        if (lineEnd > lineStart && data.charCodeAt(lineEnd - 1) === 13) {
          lineEnd--;
        }
        const line = data.substring(lineStart, lineEnd);
        lineStart = i + 1;

        if (!headerSkipped) {
          headerSkipped = true;
          continue;
        }
        if (line.length === 0) continue;

        processLine(line);
      }
    }

    if (lineStart < data.length) {
      leftover = data.substring(lineStart);
    }

    // Progress every 50ms
    const now = process.hrtime.bigint();
    if (Number(now - lastProgressNs) >= 50_000_000) {
      printProgress(bytesRead, csvSizeBytes, rowsProcessed, startNs);
      lastProgressNs = now;
    }
  }

  fs.closeSync(fd);

  function processLine(line) {
    const firstComma = line.indexOf(",");
    if (firstComma === -1) {
      invalidRows++;
      rowsProcessed++;
      return;
    }
    const secondComma = line.indexOf(",", firstComma + 1);
    if (secondComma === -1) {
      invalidRows++;
      rowsProcessed++;
      return;
    }
    const thirdComma = line.indexOf(",", secondComma + 1);
    if (thirdComma === -1) {
      invalidRows++;
      rowsProcessed++;
      return;
    }
    const fourthComma = line.indexOf(",", thirdComma + 1);
    if (fourthComma === -1) {
      invalidRows++;
      rowsProcessed++;
      return;
    }
    const fifthComma = line.indexOf(",", fourthComma + 1);
    if (fifthComma === -1) {
      invalidRows++;
      rowsProcessed++;
      return;
    }
    const sixthComma = line.indexOf(",", fifthComma + 1);
    if (sixthComma === -1) {
      invalidRows++;
      rowsProcessed++;
      return;
    }

    const id = line.substring(0, firstComma);
    const name = line.substring(firstComma + 1, secondComma);
    const email = line.substring(secondComma + 1, thirdComma);
    const country = line.substring(thirdComma + 1, fourthComma);
    const ageStr = line.substring(fourthComma + 1, fifthComma);
    const profession = line.substring(fifthComma + 1, sixthComma);
    const salaryStr = line.substring(sixthComma + 1);

    // Validation
    if (id.length === 0 || !email.includes("@")) {
      invalidRows++;
      rowsProcessed++;
      return;
    }

    const age = parseInt(ageStr, 10);
    if (isNaN(age)) {
      invalidRows++;
      rowsProcessed++;
      return;
    }

    const salary = parseFloat(salaryStr);
    if (isNaN(salary)) {
      invalidRows++;
      rowsProcessed++;
      return;
    }

    // Create user object
    const user = { id, name, email, country, age, profession, salary };
    void user;

    // Statistics
    totalSalary += salary;
    if (salary < minSalary) minSalary = salary;
    if (salary > maxSalary) maxSalary = salary;
    totalAge += age;

    // Country grouping
    let cs = countries.get(country);
    if (cs) {
      cs.count++;
      cs.totalSalary += salary;
      cs.totalAge += age;
    } else {
      countries.set(country, { count: 1, totalSalary: salary, totalAge: age });
    }

    // Profession grouping
    let ps = professions.get(profession);
    if (ps) {
      ps.count++;
      ps.totalSalary += salary;
    } else {
      professions.set(profession, { count: 1, totalSalary: salary });
    }

    rowsProcessed++;
  }

  // Final progress
  printProgress(csvSizeBytes, csvSizeBytes, rowsProcessed, startNs);
  process.stdout.write("\n\n");

  const validRows = rowsProcessed - invalidRows;
  const avgSalary = validRows > 0 ? totalSalary / validRows : 0;
  const avgAge = validRows > 0 ? totalAge / validRows : 0;
  if (minSalary === Number.MAX_VALUE) minSalary = 0;
  if (maxSalary === -Number.MAX_VALUE) maxSalary = 0;

  // Find highest/lowest paid profession
  let highestProf = "";
  let highestAvg = -Infinity;
  let lowestProf = "";
  let lowestAvg = Infinity;

  for (const [name, ps] of professions) {
    const avg = ps.totalSalary / ps.count;
    if (avg > highestAvg) {
      highestAvg = avg;
      highestProf = name;
    }
    if (avg < lowestAvg) {
      lowestAvg = avg;
      lowestProf = name;
    }
  }

  // Build JSON
  const output = {
    summary: {
      total_records: rowsProcessed,
      valid_records: validRows,
      invalid_records: invalidRows,
      average_salary: Math.round(avgSalary * 100) / 100,
      min_salary: minSalary,
      max_salary: maxSalary,
      average_age: Math.round(avgAge * 100) / 100,
      highest_paid_profession: highestProf,
      lowest_paid_profession: lowestProf,
    },
    countries: {},
    professions: {},
  };

  for (const [name, cs] of countries) {
    output.countries[name] = {
      total_users: cs.count,
      average_salary: Math.round((cs.totalSalary / cs.count) * 100) / 100,
      average_age: Math.round((cs.totalAge / cs.count) * 100) / 100,
    };
  }

  for (const [name, ps] of professions) {
    output.professions[name] = {
      count: ps.count,
      average_salary: Math.round((ps.totalSalary / ps.count) * 100) / 100,
    };
  }

  const jsonStr = JSON.stringify(output, null, 2) + "\n";

  // Write JSON
  const outputPath = "result.json";
  fs.writeFileSync(outputPath, jsonStr);

  const endNs = process.hrtime.bigint();
  const elapsedNs = Number(endNs - startNs);
  const elapsed = elapsedNs / 1e9;
  const jsonSizeBytes = Buffer.byteLength(jsonStr);
  const rowsPerSec = elapsed > 0 ? Math.floor(rowsProcessed / elapsed) : 0;

  // Peak memory
  const peakRss = process.memoryUsage().rss;

  console.log("==================================================");
  console.log("Benchmark Complete");
  console.log("==================================================");
  console.log();
  console.log("Language           : Node.js");
  console.log();
  console.log(`Rows Processed     : ${rowsProcessed}`);
  console.log(`Invalid Rows       : ${invalidRows}`);
  console.log();
  console.log(`CSV Size           : ${formatSize(csvSizeBytes)}`);
  console.log(`JSON Size          : ${formatSize(jsonSizeBytes)}`);
  console.log();
  console.log(`Execution Time     : ${elapsed.toFixed(3)} seconds`);
  console.log();
  console.log(`Rows / Second      : ${rowsPerSec}`);
  console.log();
  console.log(`Peak Memory        : ${formatSize(peakRss)}`);
  console.log();
  console.log(`Output File        : ${outputPath}`);
  console.log();
  console.log("==================================================");
}

main();
