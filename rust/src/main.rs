use std::collections::HashMap;
use std::fs::{self, File};
use std::io::{self, Read, Write, BufWriter};
use std::time::Instant;

const CSV_PATH: &str = "../users-big.csv";

struct User {
    id: String,
    name: String,
    email: String,
    country: String,
    age: i32,
    profession: String,
    salary: f64,
}

struct CountryStats {
    count: u64,
    total_salary: f64,
    total_age: i64,
}

struct ProfessionStats {
    count: u64,
    total_salary: f64,
}

fn format_size(bytes: u64) -> String {
    let b = bytes as f64;
    if b >= 1_073_741_824.0 {
        format!("{:.2} GB", b / 1_073_741_824.0)
    } else if b >= 1_048_576.0 {
        format!("{:.2} MB", b / 1_048_576.0)
    } else if b >= 1024.0 {
        format!("{:.2} KB", b / 1024.0)
    } else {
        format!("{} B", bytes)
    }
}

fn print_progress(bytes_read: u64, total_bytes: u64, rows: u64, start: &Instant) {
    let elapsed = start.elapsed().as_secs_f64();
    let rows_per_sec = if elapsed > 0.0 { (rows as f64 / elapsed) as u64 } else { 0 };
    let mb_per_sec = if elapsed > 0.0 { bytes_read as f64 / 1_048_576.0 / elapsed } else { 0.0 };
    let percent = if total_bytes > 0 { bytes_read as f64 / total_bytes as f64 * 100.0 } else { 0.0 };

    let bar_width = 30;
    let filled = if total_bytes > 0 {
        (bar_width as f64 * bytes_read as f64 / total_bytes as f64) as usize
    } else { 0 };
    let filled = filled.min(bar_width);

    let bar: String = "\u{2588}".repeat(filled) + &"\u{2591}".repeat(bar_width - filled);

    print!("\r[{}] {:.2}% | {} rows | {} rows/sec | {:.2} MB/s    ",
           bar, percent, rows, rows_per_sec, mb_per_sec);
    io::stdout().flush().unwrap_or(());
}

fn process_line(
    line: &str,
    rows_processed: &mut u64,
    invalid_rows: &mut u64,
    total_salary: &mut f64,
    min_salary: &mut f64,
    max_salary: &mut f64,
    total_age: &mut i64,
    countries: &mut HashMap<String, CountryStats>,
    professions: &mut HashMap<String, ProfessionStats>,
) {
    let fields: Vec<&str> = line.splitn(8, ',').collect();
    if fields.len() < 7 {
        *invalid_rows += 1;
        *rows_processed += 1;
        return;
    }

    let id = fields[0];
    let name = fields[1];
    let email = fields[2];
    let country = fields[3];
    let age_str = fields[4];
    let profession = fields[5];
    let salary_str = fields[6].trim_end_matches('\r');

    // Validation
    if id.is_empty() || !email.contains('@') {
        *invalid_rows += 1;
        *rows_processed += 1;
        return;
    }

    let age = match age_str.parse::<i32>() {
        Ok(v) => v,
        Err(_) => { *invalid_rows += 1; *rows_processed += 1; return; }
    };

    let salary = match salary_str.parse::<f64>() {
        Ok(v) => v,
        Err(_) => { *invalid_rows += 1; *rows_processed += 1; return; }
    };

    // Create user struct
    let _user = User {
        id: id.to_string(),
        name: name.to_string(),
        email: email.to_string(),
        country: country.to_string(),
        age,
        profession: profession.to_string(),
        salary,
    };

    // Statistics
    *total_salary += salary;
    if salary < *min_salary { *min_salary = salary; }
    if salary > *max_salary { *max_salary = salary; }
    *total_age += age as i64;

    // Country grouping
    let cs = countries.entry(country.to_string()).or_insert(CountryStats {
        count: 0, total_salary: 0.0, total_age: 0,
    });
    cs.count += 1;
    cs.total_salary += salary;
    cs.total_age += age as i64;

    // Profession grouping
    let ps = professions.entry(profession.to_string()).or_insert(ProfessionStats {
        count: 0, total_salary: 0.0,
    });
    ps.count += 1;
    ps.total_salary += salary;

    *rows_processed += 1;
}

fn main() {
    let csv_path = CSV_PATH;

    // Print header
    println!("==================================================");
    println!("Cross-Language Benchmark");
    println!("Language : Rust");
    println!("==================================================");
    println!();
    println!("Input File : {}", csv_path);
    println!();

    // Open file
    let mut file = match File::open(csv_path) {
        Ok(f) => f,
        Err(_) => {
            eprintln!("Error:\nUnable to open {}", csv_path);
            std::process::exit(1);
        }
    };

    // Get file size
    let metadata = match fs::metadata(csv_path) {
        Ok(m) => m,
        Err(_) => {
            eprintln!("Error:\nUnable to stat {}", csv_path);
            std::process::exit(1);
        }
    };
    let csv_size_bytes = metadata.len();

    // Start timing
    let start = Instant::now();

    // Processing state
    let mut rows_processed: u64 = 0;
    let mut invalid_rows: u64 = 0;
    let mut bytes_read: u64 = 0;

    let mut total_salary: f64 = 0.0;
    let mut min_salary: f64 = f64::MAX;
    let mut max_salary: f64 = f64::MIN;
    let mut total_age: i64 = 0;

    let mut countries: HashMap<String, CountryStats> = HashMap::new();
    let mut professions: HashMap<String, ProfessionStats> = HashMap::new();

    // Streaming read with 8MB buffer
    let mut buf = vec![0u8; 8 * 1024 * 1024];
    let mut leftover = Vec::with_capacity(4096);
    let mut header_skipped = false;
    let mut last_progress = Instant::now();

    loop {
        let n = match file.read(&mut buf) {
            Ok(0) => {
                // Process remaining leftover
                if !leftover.is_empty() {
                    if let Ok(line) = std::str::from_utf8(&leftover) {
                        let line = line.trim_end_matches(&['\r', '\n'][..]);
                        if !line.is_empty() && header_skipped {
                            process_line(line, &mut rows_processed, &mut invalid_rows,
                                &mut total_salary, &mut min_salary, &mut max_salary,
                                &mut total_age, &mut countries, &mut professions);
                        }
                    }
                }
                break;
            }
            Ok(n) => n,
            Err(e) => {
                eprintln!("Error:\nFailed to read {}: {}", csv_path, e);
                std::process::exit(1);
            }
        };

        bytes_read += n as u64;
        let chunk = &buf[..n];

        let mut line_start = 0;
        for i in 0..n {
            if chunk[i] == b'\n' {
                let segment = &chunk[line_start..i];

                let line_bytes = if !leftover.is_empty() {
                    leftover.extend_from_slice(segment);
                    let result = leftover.clone();
                    leftover.clear();
                    result
                } else {
                    segment.to_vec()
                };

                if let Ok(line) = std::str::from_utf8(&line_bytes) {
                    let line = line.trim_end_matches('\r');
                    if !header_skipped {
                        header_skipped = true;
                    } else if !line.is_empty() {
                        process_line(line, &mut rows_processed, &mut invalid_rows,
                            &mut total_salary, &mut min_salary, &mut max_salary,
                            &mut total_age, &mut countries, &mut professions);
                    }
                }

                line_start = i + 1;
            }
        }

        // Save leftover
        if line_start < n {
            leftover.extend_from_slice(&chunk[line_start..]);
        }

        // Progress every 50ms
        if last_progress.elapsed().as_millis() >= 50 {
            print_progress(bytes_read, csv_size_bytes, rows_processed, &start);
            last_progress = Instant::now();
        }
    }

    // Final progress
    print_progress(csv_size_bytes, csv_size_bytes, rows_processed, &start);
    println!("\n");

    let valid_rows = rows_processed - invalid_rows;
    let avg_salary = if valid_rows > 0 { total_salary / valid_rows as f64 } else { 0.0 };
    let avg_age = if valid_rows > 0 { total_age as f64 / valid_rows as f64 } else { 0.0 };
    if min_salary == f64::MAX { min_salary = 0.0; }
    if max_salary == f64::MIN { max_salary = 0.0; }

    // Find highest/lowest paid profession
    let mut highest_prof = "";
    let mut highest_avg = f64::MIN;
    let mut lowest_prof = "";
    let mut lowest_avg = f64::MAX;

    for (name, ps) in &professions {
        let avg = ps.total_salary / ps.count as f64;
        if avg > highest_avg { highest_avg = avg; highest_prof = name; }
        if avg < lowest_avg { lowest_avg = avg; lowest_prof = name; }
    }

    // Write JSON
    let output_path = "result.json";
    let out_file = match File::create(output_path) {
        Ok(f) => f,
        Err(e) => {
            eprintln!("Error:\nFailed to write {}: {}", output_path, e);
            std::process::exit(1);
        }
    };
    let mut w = BufWriter::new(out_file);

    writeln!(w, "{{").unwrap();
    writeln!(w, "  \"summary\": {{").unwrap();
    writeln!(w, "    \"total_records\": {},", rows_processed).unwrap();
    writeln!(w, "    \"valid_records\": {},", valid_rows).unwrap();
    writeln!(w, "    \"invalid_records\": {},", invalid_rows).unwrap();
    writeln!(w, "    \"average_salary\": {:.2},", avg_salary).unwrap();
    writeln!(w, "    \"min_salary\": {:.2},", min_salary).unwrap();
    writeln!(w, "    \"max_salary\": {:.2},", max_salary).unwrap();
    writeln!(w, "    \"average_age\": {:.2},", avg_age).unwrap();
    writeln!(w, "    \"highest_paid_profession\": \"{}\",", highest_prof).unwrap();
    writeln!(w, "    \"lowest_paid_profession\": \"{}\"", lowest_prof).unwrap();
    writeln!(w, "  }},").unwrap();

    writeln!(w, "  \"countries\": {{").unwrap();
    let country_total = countries.len();
    let mut ci = 0;
    for (name, cs) in &countries {
        ci += 1;
        let ca = cs.total_salary / cs.count as f64;
        let aa = cs.total_age as f64 / cs.count as f64;
        writeln!(w, "    \"{}\": {{", name).unwrap();
        writeln!(w, "      \"total_users\": {},", cs.count).unwrap();
        writeln!(w, "      \"average_salary\": {:.2},", ca).unwrap();
        writeln!(w, "      \"average_age\": {:.2}", aa).unwrap();
        writeln!(w, "    }}{}", if ci < country_total { "," } else { "" }).unwrap();
    }
    writeln!(w, "  }},").unwrap();

    writeln!(w, "  \"professions\": {{").unwrap();
    let prof_total = professions.len();
    let mut pi = 0;
    for (name, ps) in &professions {
        pi += 1;
        let pa = ps.total_salary / ps.count as f64;
        writeln!(w, "    \"{}\": {{", name).unwrap();
        writeln!(w, "      \"count\": {},", ps.count).unwrap();
        writeln!(w, "      \"average_salary\": {:.2}", pa).unwrap();
        writeln!(w, "    }}{}", if pi < prof_total { "," } else { "" }).unwrap();
    }
    writeln!(w, "  }}").unwrap();
    writeln!(w, "}}").unwrap();

    drop(w);

    let json_size_bytes = fs::metadata(output_path).map(|m| m.len()).unwrap_or(0);

    let elapsed = start.elapsed().as_secs_f64();
    let rows_per_sec = if elapsed > 0.0 { (rows_processed as f64 / elapsed) as u64 } else { 0 };

    // Peak memory via getrusage
    let peak_rss = unsafe {
        let mut usage: libc::rusage = std::mem::zeroed();
        libc::getrusage(libc::RUSAGE_SELF, &mut usage);
        usage.ru_maxrss as u64
    };

    println!("==================================================");
    println!("Benchmark Complete");
    println!("==================================================");
    println!();
    println!("Language           : Rust");
    println!();
    println!("Rows Processed     : {}", rows_processed);
    println!("Invalid Rows       : {}", invalid_rows);
    println!();
    println!("CSV Size           : {}", format_size(csv_size_bytes));
    println!("JSON Size          : {}", format_size(json_size_bytes));
    println!();
    println!("Execution Time     : {:.3} seconds", elapsed);
    println!();
    println!("Rows / Second      : {}", rows_per_sec);
    println!();
    println!("Peak Memory        : {}", format_size(peak_rss));
    println!();
    println!("Output File        : {}", output_path);
    println!();
    println!("==================================================");
}
