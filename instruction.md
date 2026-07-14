# Cross-Language Performance Benchmark

## Purpose

The goal of this benchmark is to compare the **real-world execution performance** of different programming languages by implementing the **exact same application** in each language.

This is **not** intended to determine which language is "best." Instead, it measures how different language runtimes, standard libraries, memory management strategies, compilers, and I/O implementations perform under the same workload.

The benchmark should exercise multiple aspects of a language rather than a single CPU loop.

---

# Project Structure

```
language-comparison/
├── instruction.md
├── users-big.csv
├── users-small.csv
├── zig/
│   └── main.zig
├── go/
│   └── main.go
├── rust/
│   └── main.rs
├── c/
│   └── main.c
├── java/
│   └── Main.java
├── python/
│   └── main.py
├── node/
│   └── main.js
└── <language>/
    └── <entry point>
```

Each language implementation lives in its own subdirectory. The program is **compiled and run from within that subdirectory**.

The CSV input file is located in the **parent directory** (`../users-small.csv`).

The JSON output file (`result.json`) is written to the **current working directory** (the language subdirectory).

To benchmark with a larger file later, simply change the path to `../users-small.csv` in each implementation.

---

# Benchmark Goal

Each implementation must:

1. Read a large CSV file using **streaming/chunked I/O**.
2. Parse every row.
3. Convert each row into a native object/struct/class.
4. Perform validation.
5. Group records.
6. Compute statistics.
7. Serialize the result to JSON.
8. Write the JSON output to disk.
9. Display execution statistics.

Every language must perform the **same work**.

---

# Input

The CSV file path is `../users-small.csv` (relative to the language subdirectory).

Columns:

```
id,name,email,country,age,profession,salary
```

The benchmark should support files from hundreds of MBs up to several GBs.

---

# Processing Requirements

For every row:

## Parse

Read CSV using **streaming/chunked I/O**.

Do **not** load the entire file into memory. Read the file in fixed-size chunks (e.g. 8 MB), handle partial lines across chunk boundaries, and process each line as it is extracted.

This ensures memory usage stays constant regardless of file size.

---

## Create Native Objects

Each row should become something equivalent to:

```
User
{
    id
    name
    email
    country
    age
    profession
    salary
}
```

using the language's normal object representation:

- struct
- class
- record
- object
- map
- etc.

---

## Validate

Perform simple validation.

Reject rows if:

- id is empty
- age is not numeric
- salary is not numeric
- email does not contain "@"

Count invalid rows.

---

## Statistics

Calculate:

- Total records
- Average salary
- Minimum salary
- Maximum salary
- Average age
- Country counts
- Profession counts
- Highest paid profession (by average salary)
- Lowest paid profession (by average salary)

---

## Grouping

Group all users by country.

For each country calculate:

- total users
- average salary
- average age

---

## JSON Output

Produce a JSON file containing:

```json
{
  "summary": {
    "total_records": 50000000,
    "valid_records": 50000000,
    "invalid_records": 0,
    "average_salary": 83600.00,
    "min_salary": 25000.00,
    "max_salary": 200000.00,
    "average_age": 33.40,
    "highest_paid_profession": "Architect",
    "lowest_paid_profession": "Teacher"
  },
  "countries": {
    "USA": {
      "total_users": 5000000,
      "average_salary": 85000.00,
      "average_age": 34.20
    }
  },
  "professions": {
    "Engineer": {
      "count": 5000000,
      "average_salary": 95000.00
    }
  }
}
```

The exact formatting is not important. The structure and field names must match.

---

# Progress Bar

Display a **single-line progress bar** that updates in place using `\r`.

Since streaming does not know the total row count upfront, use **bytes-based progress** (bytes read / total file size).

Format:

```text
[██████████████████░░░░░░░░░░░░░░] 56.48% | 28242110 rows | 14906522 rows/sec | 709.38 MB/s
```

Requirements:

- Use `\r` to overwrite the same line. **Must not** print a new line every update.
- Update at most every **50 milliseconds** to avoid performance impact.
- Show: progress bar, percentage, rows processed, rows/sec, MB/s.

---

# Peak Memory

Every implementation **must** report actual peak memory usage using the OS-provided mechanism.

| Platform     | Method                                        |
|-------------|-----------------------------------------------|
| macOS/Linux | `getrusage(RUSAGE_SELF).ru_maxrss`            |
| Windows     | `GetProcessMemoryInfo` → `PeakWorkingSetSize` |
| Java        | `Runtime.getRuntime().totalMemory()`           |
| Node.js     | `process.memoryUsage().rss`                    |
| Python      | `resource.getrusage(resource.RUSAGE_SELF).ru_maxrss` |

Do **not** print "N/A". Every language has a way to measure this.

On macOS, `ru_maxrss` returns **bytes**. On Linux, it returns **kilobytes**.

---

# Required Console Output

Every implementation must print the same information in the same order so that benchmark results can be compared directly.

## Startup

```text
==================================================
Cross-Language Benchmark
Language : <language name>
==================================================

Input File : ../users-small.csv
```

---

## During Execution

```text
[██████████████████░░░░░░░░░░░░░░] 56.48% | 28242110 rows | 14906522 rows/sec | 709.38 MB/s
```

Single line, updated in place with `\r`.

---

## Completion

When finished, print exactly one benchmark summary:

```text
==================================================
Benchmark Complete
==================================================

Language           : Zig

Rows Processed     : 50000000
Invalid Rows       : 0

CSV Size           : 2.32 GB
JSON Size          : 2.26 KB

Execution Time     : 3.328 seconds

Rows / Second      : 15023848

Peak Memory        : 9.59 MB

Output File        : result.json

==================================================
```

---

# Required Program Exit

The program should:

- Exit with code **0** on success.
- Exit with a **non-zero** exit code on failure.
- Print an error message to **stderr** if processing fails.

Example:

```text
Error:
Unable to open ../users-small.csv
```

---

# Implementation Rules

Every implementation should follow the same rules.

## No external database

Everything should happen in memory.

---

## No networking

No HTTP requests.

No sockets.

---

## No multithreading

Initially implement a **single-threaded** version.

Later benchmarks may compare concurrency separately.

---

## Use release/optimized builds

Examples:

| Language | Build Command                          |
|----------|----------------------------------------|
| Zig      | `zig build-exe main.zig -OReleaseFast` |
| C/C++    | `gcc -O3 main.c -o main`              |
| Rust     | `cargo build --release`                |
| Go       | `go build -o main main.go`             |
| Java     | `javac Main.java && java Main`         |
| Node.js  | `node main.js`                         |
| Python   | `python3 main.py`                      |

---

## Use Standard Libraries

Prefer standard libraries whenever possible.

If CSV or JSON support is not available in the standard library, use the most common and widely accepted package.

Avoid highly optimized niche libraries that exist only to win benchmarks.

---

# What Should Be Measured

Measure the complete execution time including:

- file reading
- parsing
- object creation
- validation
- aggregation
- serialization
- writing output

Do **not** measure only the algorithm itself.

---

# Things NOT To Do

Do not:

- hardcode results
- skip validation
- skip object creation
- cache previous runs
- memory-map the file unless the language normally encourages it
- load the entire file into memory (use streaming/chunked reads)
- remove functionality to improve benchmark scores

Every implementation should produce equivalent output.

---

# Output Files

Input:

```
../users-small.csv
```

Output (written to current working directory):

```
result.json
```

---

# Objective

This benchmark is intended to compare:

- File I/O performance
- CSV parsing speed
- Object allocation
- Memory management
- Garbage collection overhead
- String handling
- Hash map performance
- Aggregation speed
- JSON serialization
- Overall runtime efficiency

rather than measuring only CPU arithmetic.

The benchmark should be implemented as naturally as possible for each language while preserving equivalent functionality across all implementations.

---

# Benchmark Metrics

Each implementation must report:

- Language name
- Total rows processed
- Invalid rows
- Input CSV size (human-readable: B, KB, MB, GB)
- Output JSON size (human-readable)
- Total execution time (seconds, 3 decimal places)
- Processing rate (rows/sec)
- Peak memory usage (human-readable, measured via OS API)
- Output file path

No other information should be printed except errors.

This ensures benchmark outputs are consistent across all languages and can be compared or parsed automatically.

---

# README.md

After the program runs successfully with `users-small.csv`, the AI (not the program itself) should create or update a `README.md` in the language subdirectory with the build/run command and the console output.

Format:

```markdown
# Command

\```sh
<build command>
./<binary>
\```

# Small File Output

\```
<paste full console output from users-small.csv run>
\```

# Large File Output

\```
<paste full console output from users-big.csv run — leave empty until benchmarked>
\```
```

The README serves as a quick reference for how to build/run and what output to expect.
