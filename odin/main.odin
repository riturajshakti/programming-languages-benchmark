package main

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:time"
import "core:mem"

CSV_PATH :: "../users-big.csv"

User :: struct {
	id:         string,
	name:       string,
	email:      string,
	country:    string,
	age:        int,
	profession: string,
	salary:     f64,
}

Country_Stats :: struct {
	count:        u64,
	total_salary: f64,
	total_age:    i64,
}

Profession_Stats :: struct {
	count:        u64,
	total_salary: f64,
}

Rusage :: struct {
	ru_utime:    [2]i64,
	ru_stime:    [2]i64,
	ru_maxrss:   i64,
	ru_ixrss:    i64,
	ru_idrss:    i64,
	ru_isrss:    i64,
	ru_minflt:   i64,
	ru_majflt:   i64,
	ru_nswap:    i64,
	ru_inblock:  i64,
	ru_oublock:  i64,
	ru_msgsnd:   i64,
	ru_msgrcv:   i64,
	ru_nsignals: i64,
	ru_nvcsw:    i64,
	ru_nivcsw:   i64,
}

foreign import libc_lib "system:System.framework"

@(default_calling_convention = "c")
foreign libc_lib {
	getrusage :: proc(who: i32, usage: ^Rusage) -> i32 ---
}

format_size :: proc(bytes: u64) -> string {
	b := f64(bytes)
	if b >= 1_073_741_824 {
		return fmt.tprintf("%.2f GB", b / 1_073_741_824)
	} else if b >= 1_048_576 {
		return fmt.tprintf("%.2f MB", b / 1_048_576)
	} else if b >= 1024 {
		return fmt.tprintf("%.2f KB", b / 1024)
	} else {
		return fmt.tprintf("%d B", bytes)
	}
}

print_progress :: proc(bytes_read: u64, total_bytes: u64, rows: u64, start_tick: time.Tick) {
	now := time.tick_now()
	elapsed := time.duration_seconds(time.tick_diff(start_tick, now))
	rows_per_sec: u64 = 0
	mb_per_sec: f64 = 0
	if elapsed > 0 {
		rows_per_sec = u64(f64(rows) / elapsed)
		mb_per_sec = f64(bytes_read) / 1_048_576 / elapsed
	}

	percent: f64 = 0
	if total_bytes > 0 {
		percent = f64(bytes_read) / f64(total_bytes) * 100
	}

	bar_width :: 30
	filled := 0
	if total_bytes > 0 {
		filled = int(f64(bar_width) * f64(bytes_read) / f64(total_bytes))
	}
	if filled > bar_width { filled = bar_width }

	bar: [bar_width * 3]u8
	pos := 0
	for i in 0 ..< bar_width {
		if i < filled {
			bar[pos] = 0xe2; bar[pos + 1] = 0x96; bar[pos + 2] = 0x88
		} else {
			bar[pos] = 0xe2; bar[pos + 1] = 0x96; bar[pos + 2] = 0x91
		}
		pos += 3
	}

	fmt.printf("\r[%s] %.2f%% | %d rows | %d rows/sec | %.2f MB/s    ",
		string(bar[:pos]), percent, rows, rows_per_sec, mb_per_sec)
}

process_line :: proc(
	line: string,
	rows_processed: ^u64,
	invalid_rows: ^u64,
	total_salary: ^f64,
	min_salary: ^f64,
	max_salary: ^f64,
	total_age: ^i64,
	countries: ^map[string]Country_Stats,
	professions: ^map[string]Profession_Stats,
	allocator: mem.Allocator,
) {
	parts := strings.split_n(line, ",", 8, allocator)
	defer delete(parts, allocator)

	if len(parts) < 7 {
		invalid_rows^ += 1
		rows_processed^ += 1
		return
	}

	id := parts[0]
	name := parts[1]
	email := parts[2]
	country := parts[3]
	age_str := parts[4]
	profession := parts[5]
	salary_str := strings.trim_right(parts[6], "\r")

	if len(id) == 0 || !strings.contains(email, "@") {
		invalid_rows^ += 1
		rows_processed^ += 1
		return
	}

	age, age_ok := strconv.parse_int(age_str)
	if !age_ok {
		invalid_rows^ += 1
		rows_processed^ += 1
		return
	}

	salary, salary_ok := strconv.parse_f64(salary_str)
	if !salary_ok {
		invalid_rows^ += 1
		rows_processed^ += 1
		return
	}

	user := User{
		id         = id,
		name       = name,
		email      = email,
		country    = country,
		age        = age,
		profession = profession,
		salary     = salary,
	}
	_ = user

	total_salary^ += salary
	if salary < min_salary^ { min_salary^ = salary }
	if salary > max_salary^ { max_salary^ = salary }
	total_age^ += i64(age)

	if country in countries^ {
		cs := &countries^[country]
		cs.count += 1
		cs.total_salary += salary
		cs.total_age += i64(age)
	} else {
		key := strings.clone(country, allocator)
		countries^[key] = Country_Stats{
			count        = 1,
			total_salary = salary,
			total_age    = i64(age),
		}
	}

	if profession in professions^ {
		ps := &professions^[profession]
		ps.count += 1
		ps.total_salary += salary
	} else {
		key := strings.clone(profession, allocator)
		professions^[key] = Profession_Stats{
			count        = 1,
			total_salary = salary,
		}
	}

	rows_processed^ += 1
}

write_to_file :: proc(f: ^os.File, s: string) {
	os.write(f, transmute([]u8)s)
}

main :: proc() {
	csv_path := CSV_PATH

	fmt.println("==================================================")
	fmt.println("Cross-Language Benchmark")
	fmt.println("Language : Odin")
	fmt.println("==================================================")
	fmt.println()
	fmt.printf("Input File : %s\n\n", csv_path)

	fd, err := os.open(csv_path)
	if err != nil {
		fmt.eprintfln("Error:\nUnable to open %s", csv_path)
		os.exit(1)
	}
	defer os.close(fd)

	file_size: u64
	{
		size, serr := os.file_size(fd)
		if serr != nil {
			fmt.eprintfln("Error:\nUnable to stat %s", csv_path)
			os.exit(1)
		}
		file_size = u64(size)
	}

	start_tick := time.tick_now()

	rows_processed: u64 = 0
	invalid_rows: u64 = 0
	bytes_read: u64 = 0

	total_salary: f64 = 0
	min_salary: f64 = max(f64)
	max_salary: f64 = -max(f64)
	total_age: i64 = 0

	countries: map[string]Country_Stats
	professions: map[string]Profession_Stats
	defer delete(countries)
	defer delete(professions)

	allocator := context.allocator

	BUF_SIZE :: 8 * 1024 * 1024
	buf := make([]u8, BUF_SIZE)
	defer delete(buf)

	leftover: [4096]u8
	leftover_len := 0
	header_skipped := false
	last_progress_tick := start_tick

	for {
		n, read_err := os.read(fd, buf)
		if n == 0 || read_err != nil {
			if leftover_len > 0 && header_skipped {
				lo := string(leftover[:leftover_len])
				lo = strings.trim_right(lo, "\r\n")
				if len(lo) > 0 {
					process_line(lo, &rows_processed, &invalid_rows,
						&total_salary, &min_salary, &max_salary,
						&total_age, &countries, &professions, allocator)
				}
			}
			break
		}

		bytes_read += u64(n)
		chunk := buf[:n]

		line_start := 0
		for i in 0 ..< n {
			if chunk[i] == '\n' {
				segment := chunk[line_start:i]

				line: string
				if leftover_len > 0 {
					copy_len := min(len(segment), len(leftover) - leftover_len)
					copy(leftover[leftover_len:], segment[:copy_len])
					full_len := leftover_len + copy_len
					line = strings.trim_right(string(leftover[:full_len]), "\r")
					leftover_len = 0
				} else {
					line = strings.trim_right(string(segment), "\r")
				}

				if !header_skipped {
					header_skipped = true
				} else if len(line) > 0 {
					process_line(line, &rows_processed, &invalid_rows,
						&total_salary, &min_salary, &max_salary,
						&total_age, &countries, &professions, allocator)
				}

				line_start = i + 1
			}
		}

		if line_start < n {
			remaining := n - line_start
			copy_len := min(remaining, len(leftover))
			copy(leftover[:], chunk[line_start:line_start + copy_len])
			leftover_len = copy_len
		} else {
			leftover_len = 0
		}

		now := time.tick_now()
		if time.duration_milliseconds(time.tick_diff(last_progress_tick, now)) >= 50 {
			print_progress(bytes_read, file_size, rows_processed, start_tick)
			last_progress_tick = now
		}
	}

	print_progress(file_size, file_size, rows_processed, start_tick)
	fmt.printf("\n\n")

	valid_rows := rows_processed - invalid_rows
	avg_salary: f64 = 0
	avg_age: f64 = 0
	if valid_rows > 0 {
		avg_salary = total_salary / f64(valid_rows)
		avg_age = f64(total_age) / f64(valid_rows)
	}
	if min_salary == max(f64) { min_salary = 0 }
	if max_salary == -max(f64) { max_salary = 0 }

	highest_prof := ""
	highest_avg: f64 = -max(f64)
	lowest_prof := ""
	lowest_avg: f64 = max(f64)

	for name, ps in professions {
		avg := ps.total_salary / f64(ps.count)
		if avg > highest_avg { highest_avg = avg; highest_prof = name }
		if avg < lowest_avg { lowest_avg = avg; lowest_prof = name }
	}

	// Write JSON
	output_path := "result.json"
	out_fd, out_err := os.open(output_path, {.Read, .Write, .Create, .Trunc})
	if out_err != nil {
		fmt.eprintfln("Error:\nFailed to write %s", output_path)
		os.exit(1)
	}

	wf :: write_to_file
	wl :: proc(f: ^os.File, format: string, args: ..any) {
		s := fmt.tprintf(format, ..args)
		write_to_file(f, s)
		write_to_file(f, "\n")
	}

	wf(out_fd, "{\n")
	wf(out_fd, "  \"summary\": {\n")
	wl(out_fd, "    \"total_records\": %d,", rows_processed)
	wl(out_fd, "    \"valid_records\": %d,", valid_rows)
	wl(out_fd, "    \"invalid_records\": %d,", invalid_rows)
	wl(out_fd, "    \"average_salary\": %.2f,", avg_salary)
	wl(out_fd, "    \"min_salary\": %.2f,", min_salary)
	wl(out_fd, "    \"max_salary\": %.2f,", max_salary)
	wl(out_fd, "    \"average_age\": %.2f,", avg_age)
	wl(out_fd, "    \"highest_paid_profession\": \"%s\",", highest_prof)
	wl(out_fd, "    \"lowest_paid_profession\": \"%s\"", lowest_prof)
	wf(out_fd, "  },\n")

	wf(out_fd, "  \"countries\": {\n")
	ci := 0
	country_total := len(countries)
	for name, cs in countries {
		ci += 1
		ca := cs.total_salary / f64(cs.count)
		aa := f64(cs.total_age) / f64(cs.count)
		wl(out_fd, "    \"%s\": {{", name)
		wl(out_fd, "      \"total_users\": %d,", cs.count)
		wl(out_fd, "      \"average_salary\": %.2f,", ca)
		wl(out_fd, "      \"average_age\": %.2f", aa)
		if ci < country_total {
			wf(out_fd, "    },\n")
		} else {
			wf(out_fd, "    }\n")
		}
	}
	wf(out_fd, "  },\n")

	wf(out_fd, "  \"professions\": {\n")
	pi := 0
	prof_total := len(professions)
	for name, ps in professions {
		pi += 1
		pa := ps.total_salary / f64(ps.count)
		wl(out_fd, "    \"%s\": {{", name)
		wl(out_fd, "      \"count\": %d,", ps.count)
		wl(out_fd, "      \"average_salary\": %.2f", pa)
		if pi < prof_total {
			wf(out_fd, "    },\n")
		} else {
			wf(out_fd, "    }\n")
		}
	}
	wf(out_fd, "  }\n")
	wf(out_fd, "}\n")

	json_size: u64
	{
		js, _ := os.file_size(out_fd)
		json_size = u64(js)
	}
	os.close(out_fd)

	end_tick := time.tick_now()
	elapsed := time.duration_seconds(time.tick_diff(start_tick, end_tick))
	rows_per_sec: u64 = 0
	if elapsed > 0 {
		rows_per_sec = u64(f64(rows_processed) / elapsed)
	}

	usage: Rusage
	getrusage(0, &usage)
	peak_rss := u64(usage.ru_maxrss)

	fmt.println("==================================================")
	fmt.println("Benchmark Complete")
	fmt.println("==================================================")
	fmt.println()
	fmt.println("Language           : Odin")
	fmt.println()
	fmt.printf("Rows Processed     : %d\n", rows_processed)
	fmt.printf("Invalid Rows       : %d\n", invalid_rows)
	fmt.println()
	fmt.printf("CSV Size           : %s\n", format_size(file_size))
	fmt.printf("JSON Size          : %s\n", format_size(json_size))
	fmt.println()
	fmt.printf("Execution Time     : %.3f seconds\n", elapsed)
	fmt.println()
	fmt.printf("Rows / Second      : %d\n", rows_per_sec)
	fmt.println()
	fmt.printf("Peak Memory        : %s\n", format_size(peak_rss))
	fmt.println()
	fmt.printf("Output File        : %s\n", output_path)
	fmt.println()
	fmt.println("==================================================")
}
