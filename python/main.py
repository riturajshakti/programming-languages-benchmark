import os
import sys
import time
import json
import resource

CSV_PATH = "../users-big.csv"

class User:
    __slots__ = ('id', 'name', 'email', 'country', 'age', 'profession', 'salary')
    def __init__(self, id, name, email, country, age, profession, salary):
        self.id = id
        self.name = name
        self.email = email
        self.country = country
        self.age = age
        self.profession = profession
        self.salary = salary

def format_size(bytes_val):
    b = float(bytes_val)
    if b >= 1_073_741_824:
        return f"{b / 1_073_741_824:.2f} GB"
    elif b >= 1_048_576:
        return f"{b / 1_048_576:.2f} MB"
    elif b >= 1024:
        return f"{b / 1024:.2f} KB"
    else:
        return f"{bytes_val} B"

def print_progress(bytes_read, total_bytes, rows, start_time):
    elapsed = time.monotonic() - start_time
    rows_per_sec = int(rows / elapsed) if elapsed > 0 else 0
    mb_per_sec = bytes_read / 1_048_576 / elapsed if elapsed > 0 else 0
    percent = bytes_read / total_bytes * 100 if total_bytes > 0 else 0

    bar_width = 30
    filled = int(bar_width * bytes_read / total_bytes) if total_bytes > 0 else 0
    if filled > bar_width:
        filled = bar_width

    bar = "\u2588" * filled + "\u2591" * (bar_width - filled)
    sys.stdout.write(f"\r[{bar}] {percent:.2f}% | {rows} rows | {rows_per_sec} rows/sec | {mb_per_sec:.2f} MB/s    ")
    sys.stdout.flush()

def main():
    csv_path = CSV_PATH

    print("==================================================")
    print("Cross-Language Benchmark")
    print("Language : Python")
    print("==================================================")
    print()
    print(f"Input File : {csv_path}")
    print()

    # Check file
    if not os.path.exists(csv_path):
        sys.stderr.write(f"Error:\nUnable to open {csv_path}\n")
        sys.exit(1)

    csv_size_bytes = os.path.getsize(csv_path)

    # Start timing
    start_time = time.monotonic()

    # Processing state
    rows_processed = 0
    invalid_rows = 0
    bytes_read = 0

    total_salary = 0.0
    min_salary = float('inf')
    max_salary = float('-inf')
    total_age = 0

    countries = {}
    professions = {}

    # Streaming read with 8MB buffer
    BUF_SIZE = 8 * 1024 * 1024
    header_skipped = False
    leftover = ""
    last_progress_time = start_time

    fd = os.open(csv_path, os.O_RDONLY)
    try:
        while True:
            raw = os.read(fd, BUF_SIZE)
            if not raw:
                # Process remaining leftover
                if leftover and header_skipped:
                    line = leftover.rstrip("\r\n")
                    if line:
                        rows_processed, invalid_rows, total_salary, min_salary, max_salary, total_age = process_line(
                            line, rows_processed, invalid_rows, total_salary, min_salary, max_salary,
                            total_age, countries, professions)
                break

            bytes_read += len(raw)
            chunk = raw.decode("utf-8", errors="replace")

            if leftover:
                data = leftover + chunk
                leftover = ""
            else:
                data = chunk

            line_start = 0
            for i in range(len(data)):
                if data[i] == '\n':
                    line = data[line_start:i]
                    if line.endswith('\r'):
                        line = line[:-1]
                    line_start = i + 1

                    if not header_skipped:
                        header_skipped = True
                        continue
                    if not line:
                        continue

                    rows_processed, invalid_rows, total_salary, min_salary, max_salary, total_age = process_line(
                        line, rows_processed, invalid_rows, total_salary, min_salary, max_salary,
                        total_age, countries, professions)

            if line_start < len(data):
                leftover = data[line_start:]

            # Progress every 50ms
            now = time.monotonic()
            if now - last_progress_time >= 0.05:
                print_progress(bytes_read, csv_size_bytes, rows_processed, start_time)
                last_progress_time = now
    finally:
        os.close(fd)

    # Final progress
    print_progress(csv_size_bytes, csv_size_bytes, rows_processed, start_time)
    sys.stdout.write("\n\n")

    valid_rows = rows_processed - invalid_rows
    avg_salary = total_salary / valid_rows if valid_rows > 0 else 0
    avg_age = total_age / valid_rows if valid_rows > 0 else 0
    if min_salary == float('inf'):
        min_salary = 0
    if max_salary == float('-inf'):
        max_salary = 0

    # Find highest/lowest paid profession
    highest_prof = ""
    highest_avg = float('-inf')
    lowest_prof = ""
    lowest_avg = float('inf')

    for name, ps in professions.items():
        avg = ps["total_salary"] / ps["count"]
        if avg > highest_avg:
            highest_avg = avg
            highest_prof = name
        if avg < lowest_avg:
            lowest_avg = avg
            lowest_prof = name

    # Build JSON
    output = {
        "summary": {
            "total_records": rows_processed,
            "valid_records": valid_rows,
            "invalid_records": invalid_rows,
            "average_salary": round(avg_salary, 2),
            "min_salary": min_salary,
            "max_salary": max_salary,
            "average_age": round(avg_age, 2),
            "highest_paid_profession": highest_prof,
            "lowest_paid_profession": lowest_prof,
        },
        "countries": {},
        "professions": {},
    }

    for name, cs in countries.items():
        output["countries"][name] = {
            "total_users": cs["count"],
            "average_salary": round(cs["total_salary"] / cs["count"], 2),
            "average_age": round(cs["total_age"] / cs["count"], 2),
        }

    for name, ps in professions.items():
        output["professions"][name] = {
            "count": ps["count"],
            "average_salary": round(ps["total_salary"] / ps["count"], 2),
        }

    json_str = json.dumps(output, indent=2) + "\n"

    # Write JSON
    output_path = "result.json"
    with open(output_path, "w") as f:
        f.write(json_str)

    elapsed = time.monotonic() - start_time
    json_size_bytes = len(json_str.encode("utf-8"))
    rows_per_sec = int(rows_processed / elapsed) if elapsed > 0 else 0

    # Peak memory via getrusage (macOS returns bytes)
    usage = resource.getrusage(resource.RUSAGE_SELF)
    peak_rss = int(usage.ru_maxrss)

    print("==================================================")
    print("Benchmark Complete")
    print("==================================================")
    print()
    print("Language           : Python")
    print()
    print(f"Rows Processed     : {rows_processed}")
    print(f"Invalid Rows       : {invalid_rows}")
    print()
    print(f"CSV Size           : {format_size(csv_size_bytes)}")
    print(f"JSON Size          : {format_size(json_size_bytes)}")
    print()
    print(f"Execution Time     : {elapsed:.3f} seconds")
    print()
    print(f"Rows / Second      : {rows_per_sec}")
    print()
    print(f"Peak Memory        : {format_size(peak_rss)}")
    print()
    print(f"Output File        : {output_path}")
    print()
    print("==================================================")

def process_line(line, rows_processed, invalid_rows, total_salary, min_salary, max_salary,
                 total_age, countries, professions):
    # Split into 7 fields
    parts = line.split(",", 7)
    if len(parts) < 7:
        return rows_processed + 1, invalid_rows + 1, total_salary, min_salary, max_salary, total_age

    id_val = parts[0]
    name = parts[1]
    email = parts[2]
    country = parts[3]
    age_str = parts[4]
    profession = parts[5]
    salary_str = parts[6].rstrip("\r")

    # Validation
    if not id_val or "@" not in email:
        return rows_processed + 1, invalid_rows + 1, total_salary, min_salary, max_salary, total_age

    try:
        age = int(age_str)
    except ValueError:
        return rows_processed + 1, invalid_rows + 1, total_salary, min_salary, max_salary, total_age

    try:
        salary = float(salary_str)
    except ValueError:
        return rows_processed + 1, invalid_rows + 1, total_salary, min_salary, max_salary, total_age

    # Create user object
    user = User(id_val, name, email, country, age, profession, salary)
    _ = user

    # Statistics
    total_salary += salary
    if salary < min_salary:
        min_salary = salary
    if salary > max_salary:
        max_salary = salary
    total_age += age

    # Country grouping
    cs = countries.get(country)
    if cs:
        cs["count"] += 1
        cs["total_salary"] += salary
        cs["total_age"] += age
    else:
        countries[country] = {"count": 1, "total_salary": salary, "total_age": age}

    # Profession grouping
    ps = professions.get(profession)
    if ps:
        ps["count"] += 1
        ps["total_salary"] += salary
    else:
        professions[profession] = {"count": 1, "total_salary": salary}

    return rows_processed + 1, invalid_rows, total_salary, min_salary, max_salary, total_age

if __name__ == "__main__":
    main()
