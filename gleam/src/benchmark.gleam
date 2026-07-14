import gleam/dict.{type Dict}
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/string

const csv_path = "../users-big.csv"

pub type User {
  User(
    id: String,
    name: String,
    email: String,
    country: String,
    age: Int,
    profession: String,
    salary: Float,
  )
}

pub type CountryStats {
  CountryStats(count: Int, total_salary: Float, total_age: Int)
}

pub type ProfessionStats {
  ProfessionStats(count: Int, total_salary: Float)
}

pub type State {
  State(
    rows_processed: Int,
    invalid_rows: Int,
    total_salary: Float,
    min_salary: Float,
    max_salary: Float,
    total_age: Int,
    countries: Dict(String, CountryStats),
    professions: Dict(String, ProfessionStats),
  )
}

pub fn main() -> Nil {
  io.println("==================================================")
  io.println("Cross-Language Benchmark")
  io.println("Language : Gleam")
  io.println("==================================================")
  io.println("")
  io.println("Input File : " <> csv_path)
  io.println("")

  // Get file size
  let csv_size_bytes = file_size(csv_path)
  case csv_size_bytes {
    Error(_) -> {
      write_stderr("Error:\nUnable to open " <> csv_path <> "\n")
      halt(1)
    }
    Ok(_) -> Nil
  }
  let assert Ok(size) = csv_size_bytes

  // Open file
  let fd = file_open(csv_path)
  case fd {
    Error(_) -> {
      write_stderr("Error:\nUnable to open " <> csv_path <> "\n")
      halt(1)
    }
    Ok(_) -> Nil
  }
  let assert Ok(handle) = fd

  // Start timing
  let start_ns = monotonic_time_ns()

  // Process file
  let initial_state =
    State(
      rows_processed: 0,
      invalid_rows: 0,
      total_salary: 0.0,
      min_salary: 1.0e308,
      max_salary: -1.0e308,
      total_age: 0,
      countries: dict.new(),
      professions: dict.new(),
    )

  let #(final_state, _) =
    stream_loop(handle, size, start_ns, initial_state, "", False, 0, start_ns)

  file_close(handle)

  // Final progress
  print_progress(size, size, final_state.rows_processed, start_ns)
  io.print("\n\n")

  let valid_rows = final_state.rows_processed - final_state.invalid_rows
  let avg_salary = case valid_rows > 0 {
    True -> final_state.total_salary /. int.to_float(valid_rows)
    False -> 0.0
  }
  let avg_age = case valid_rows > 0 {
    True -> int.to_float(final_state.total_age) /. int.to_float(valid_rows)
    False -> 0.0
  }
  let min_sal = case final_state.min_salary >=. 1.0e308 {
    True -> 0.0
    False -> final_state.min_salary
  }
  let max_sal = case final_state.max_salary <=. -1.0e308 {
    True -> 0.0
    False -> final_state.max_salary
  }

  // Find highest/lowest paid profession
  let #(highest_prof, lowest_prof) =
    dict.fold(final_state.professions, #("", -1.0e308, "", 1.0e308), fn(
      acc,
      name,
      ps,
    ) {
      let avg = ps.total_salary /. int.to_float(ps.count)
      let #(h, ha, l, la) = acc
      let #(nh, nha) = case avg >. ha {
        True -> #(name, avg)
        False -> #(h, ha)
      }
      let #(nl, nla) = case avg <. la {
        True -> #(name, avg)
        False -> #(l, la)
      }
      #(nh, nha, nl, nla)
    })
    |> fn(r) {
      let #(h, _, l, _) = r
      #(h, l)
    }

  // Write JSON
  let output_path = "result.json"
  let json = build_json(
    final_state.rows_processed,
    valid_rows,
    final_state.invalid_rows,
    avg_salary,
    min_sal,
    max_sal,
    avg_age,
    highest_prof,
    lowest_prof,
    final_state.countries,
    final_state.professions,
  )
  write_file(output_path, json)

  let json_size = string.byte_size(json)

  let end_ns = monotonic_time_ns()
  let elapsed = int.to_float(end_ns - start_ns) /. 1_000_000_000.0
  let rows_per_sec = case elapsed >. 0.0 {
    True -> float.truncate(
      int.to_float(final_state.rows_processed) /. elapsed,
    )
    False -> 0
  }

  // Peak memory
  let peak_memory = erlang_memory_total()

  io.println("==================================================")
  io.println("Benchmark Complete")
  io.println("==================================================")
  io.println("")
  io.println("Language           : Gleam")
  io.println("")
  io.println("Rows Processed     : " <> int.to_string(
    final_state.rows_processed,
  ))
  io.println("Invalid Rows       : " <> int.to_string(
    final_state.invalid_rows,
  ))
  io.println("")
  io.println("CSV Size           : " <> format_size(size))
  io.println("JSON Size          : " <> format_size(json_size))
  io.println("")
  io.println("Execution Time     : " <> float_to_fixed(elapsed, 3)
    <> " seconds")
  io.println("")
  io.println("Rows / Second      : " <> int.to_string(rows_per_sec))
  io.println("")
  io.println("Peak Memory        : " <> format_size(peak_memory))
  io.println("")
  io.println("Output File        : " <> output_path)
  io.println("")
  io.println("==================================================")
}

fn stream_loop(
  handle: Dynamic,
  total_bytes: Int,
  start_ns: Int,
  state: State,
  leftover: String,
  header_skipped: Bool,
  bytes_read: Int,
  last_progress_ns: Int,
) -> #(State, Int) {
  let chunk_result = file_read(handle, 8_388_608)
  case chunk_result {
    Error(_) -> {
      // EOF - process leftover
      case leftover != "" && header_skipped {
        True -> {
          let line = string.trim_end(leftover)
          case line != "" {
            True -> #(process_line(line, state), bytes_read)
            False -> #(state, bytes_read)
          }
        }
        False -> #(state, bytes_read)
      }
    }
    Ok(data) -> {
      let new_bytes = bytes_read + string.byte_size(data)
      let combined = leftover <> data

      let #(new_state, new_leftover, new_header) =
        process_chunk_lines(combined, state, header_skipped)

      // Progress every 50ms
      let now = monotonic_time_ns()
      let new_last = case now - last_progress_ns >= 50_000_000 {
        True -> {
          print_progress(new_bytes, total_bytes, new_state.rows_processed, start_ns)
          now
        }
        False -> last_progress_ns
      }

      stream_loop(
        handle,
        total_bytes,
        start_ns,
        new_state,
        new_leftover,
        new_header,
        new_bytes,
        new_last,
      )
    }
  }
}

fn process_chunk_lines(
  data: String,
  state: State,
  header_skipped: Bool,
) -> #(State, String, Bool) {
  case string.split_once(data, "\n") {
    Ok(#(line, rest)) -> {
      let trimmed = string.trim_end(line)
      case header_skipped {
        False -> process_chunk_lines(rest, state, True)
        True -> {
          case trimmed != "" {
            True -> {
              let new_state = process_line(trimmed, state)
              process_chunk_lines(rest, new_state, True)
            }
            False -> process_chunk_lines(rest, state, True)
          }
        }
      }
    }
    Error(_) -> #(state, data, header_skipped)
  }
}

fn process_line(line: String, state: State) -> State {
  let parts = string.split(line, ",")
  case list.length(parts) >= 7 {
    False ->
      State(
        ..state,
        rows_processed: state.rows_processed + 1,
        invalid_rows: state.invalid_rows + 1,
      )
    True -> {
      let assert [id, name, email, country, age_str, profession, salary_str, ..] =
        parts
      let clean_salary = string.trim_end(salary_str)

      case id != "" && string.contains(email, "@") {
        False ->
          State(
            ..state,
            rows_processed: state.rows_processed + 1,
            invalid_rows: state.invalid_rows + 1,
          )
        True -> {
          case int.parse(age_str) {
            Error(_) ->
              State(
                ..state,
                rows_processed: state.rows_processed + 1,
                invalid_rows: state.invalid_rows + 1,
              )
            Ok(age) -> {
              case float.parse(clean_salary) {
                Error(_) -> {
                  // Try parsing as int
                  case int.parse(clean_salary) {
                    Error(_) ->
                      State(
                        ..state,
                        rows_processed: state.rows_processed + 1,
                        invalid_rows: state.invalid_rows + 1,
                      )
                    Ok(sal_int) ->
                      apply_valid_row(
                        state,
                        id,
                        name,
                        email,
                        country,
                        age,
                        profession,
                        int.to_float(sal_int),
                      )
                  }
                }
                Ok(salary) ->
                  apply_valid_row(
                    state, id, name, email, country, age, profession, salary,
                  )
              }
            }
          }
        }
      }
    }
  }
}

fn apply_valid_row(
  state: State,
  id: String,
  name: String,
  email: String,
  country: String,
  age: Int,
  profession: String,
  salary: Float,
) -> State {
  let _user =
    User(
      id: id,
      name: name,
      email: email,
      country: country,
      age: age,
      profession: profession,
      salary: salary,
    )

  let new_min = case salary <. state.min_salary {
    True -> salary
    False -> state.min_salary
  }
  let new_max = case salary >. state.max_salary {
    True -> salary
    False -> state.max_salary
  }

  let new_countries = case dict.get(state.countries, country) {
    Ok(cs) ->
      dict.insert(state.countries, country, CountryStats(
        count: cs.count + 1,
        total_salary: cs.total_salary +. salary,
        total_age: cs.total_age + age,
      ))
    Error(_) ->
      dict.insert(
        state.countries,
        country,
        CountryStats(count: 1, total_salary: salary, total_age: age),
      )
  }

  let new_professions = case dict.get(state.professions, profession) {
    Ok(ps) ->
      dict.insert(state.professions, profession, ProfessionStats(
        count: ps.count + 1,
        total_salary: ps.total_salary +. salary,
      ))
    Error(_) ->
      dict.insert(
        state.professions,
        profession,
        ProfessionStats(count: 1, total_salary: salary),
      )
  }

  State(
    rows_processed: state.rows_processed + 1,
    invalid_rows: state.invalid_rows,
    total_salary: state.total_salary +. salary,
    min_salary: new_min,
    max_salary: new_max,
    total_age: state.total_age + age,
    countries: new_countries,
    professions: new_professions,
  )
}

fn format_size(bytes: Int) -> String {
  let b = int.to_float(bytes)
  case True {
    _ if b >=. 1_073_741_824.0 ->
      float_to_fixed(b /. 1_073_741_824.0, 2) <> " GB"
    _ if b >=. 1_048_576.0 -> float_to_fixed(b /. 1_048_576.0, 2) <> " MB"
    _ if b >=. 1024.0 -> float_to_fixed(b /. 1024.0, 2) <> " KB"
    _ -> int.to_string(bytes) <> " B"
  }
}

fn float_to_fixed(f: Float, decimals: Int) -> String {
  erlang_float_to_list(f, decimals)
}

fn print_progress(
  bytes_read: Int,
  total_bytes: Int,
  rows: Int,
  start_ns: Int,
) -> Nil {
  let now = monotonic_time_ns()
  let elapsed = int.to_float(now - start_ns) /. 1_000_000_000.0
  let rows_per_sec = case elapsed >. 0.0 {
    True -> float.truncate(int.to_float(rows) /. elapsed)
    False -> 0
  }
  let mb_per_sec = case elapsed >. 0.0 {
    True -> int.to_float(bytes_read) /. 1_048_576.0 /. elapsed
    False -> 0.0
  }
  let percent = case total_bytes > 0 {
    True -> int.to_float(bytes_read) /. int.to_float(total_bytes) *. 100.0
    False -> 0.0
  }
  let bar_width = 30
  let filled = case total_bytes > 0 {
    True -> {
      let f =
        float.truncate(
          int.to_float(bar_width)
          *. int.to_float(bytes_read)
          /. int.to_float(total_bytes),
        )
      case f > bar_width {
        True -> bar_width
        False -> f
      }
    }
    False -> 0
  }

  let bar =
    string.repeat("█", filled) <> string.repeat("░", bar_width - filled)

  write_stdout_raw(
    "\r["
    <> bar
    <> "] "
    <> float_to_fixed(percent, 2)
    <> "% | "
    <> int.to_string(rows)
    <> " rows | "
    <> int.to_string(rows_per_sec)
    <> " rows/sec | "
    <> float_to_fixed(mb_per_sec, 2)
    <> " MB/s    ",
  )
}

fn build_json(
  total_records: Int,
  valid_records: Int,
  invalid_records: Int,
  avg_salary: Float,
  min_salary: Float,
  max_salary: Float,
  avg_age: Float,
  highest_prof: String,
  lowest_prof: String,
  countries: Dict(String, CountryStats),
  professions: Dict(String, ProfessionStats),
) -> String {
  let summary =
    "{\n"
    <> "  \"summary\": {\n"
    <> "    \"total_records\": "
    <> int.to_string(total_records)
    <> ",\n"
    <> "    \"valid_records\": "
    <> int.to_string(valid_records)
    <> ",\n"
    <> "    \"invalid_records\": "
    <> int.to_string(invalid_records)
    <> ",\n"
    <> "    \"average_salary\": "
    <> float_to_fixed(avg_salary, 2)
    <> ",\n"
    <> "    \"min_salary\": "
    <> float_to_fixed(min_salary, 2)
    <> ",\n"
    <> "    \"max_salary\": "
    <> float_to_fixed(max_salary, 2)
    <> ",\n"
    <> "    \"average_age\": "
    <> float_to_fixed(avg_age, 2)
    <> ",\n"
    <> "    \"highest_paid_profession\": \""
    <> highest_prof
    <> "\",\n"
    <> "    \"lowest_paid_profession\": \""
    <> lowest_prof
    <> "\"\n"
    <> "  },\n"

  let country_list = dict.to_list(countries)
  let country_total = list.length(country_list)
  let countries_json =
    "  \"countries\": {\n"
    <> {
      list.index_map(country_list, fn(entry, idx) {
        let #(name, cs) = entry
        let ca = cs.total_salary /. int.to_float(cs.count)
        let aa = int.to_float(cs.total_age) /. int.to_float(cs.count)
        let comma = case idx + 1 < country_total {
          True -> ","
          False -> ""
        }
        "    \""
        <> name
        <> "\": {\n"
        <> "      \"total_users\": "
        <> int.to_string(cs.count)
        <> ",\n"
        <> "      \"average_salary\": "
        <> float_to_fixed(ca, 2)
        <> ",\n"
        <> "      \"average_age\": "
        <> float_to_fixed(aa, 2)
        <> "\n"
        <> "    }"
        <> comma
        <> "\n"
      })
      |> string.join("")
    }
    <> "  },\n"

  let prof_list = dict.to_list(professions)
  let prof_total = list.length(prof_list)
  let profs_json =
    "  \"professions\": {\n"
    <> {
      list.index_map(prof_list, fn(entry, idx) {
        let #(name, ps) = entry
        let pa = ps.total_salary /. int.to_float(ps.count)
        let comma = case idx + 1 < prof_total {
          True -> ","
          False -> ""
        }
        "    \""
        <> name
        <> "\": {\n"
        <> "      \"count\": "
        <> int.to_string(ps.count)
        <> ",\n"
        <> "      \"average_salary\": "
        <> float_to_fixed(pa, 2)
        <> "\n"
        <> "    }"
        <> comma
        <> "\n"
      })
      |> string.join("")
    }
    <> "  }\n"

  summary <> countries_json <> profs_json <> "}\n"
}

// FFI to Erlang
pub type Dynamic

@external(erlang, "benchmark_ffi", "file_open")
fn file_open(path: String) -> Result(Dynamic, String)

@external(erlang, "benchmark_ffi", "file_close")
fn file_close(handle: Dynamic) -> Nil

@external(erlang, "benchmark_ffi", "file_read")
fn file_read(handle: Dynamic, size: Int) -> Result(String, String)

@external(erlang, "benchmark_ffi", "file_size")
fn file_size(path: String) -> Result(Int, String)

@external(erlang, "benchmark_ffi", "monotonic_time_ns")
fn monotonic_time_ns() -> Int

@external(erlang, "benchmark_ffi", "erlang_memory_total")
fn erlang_memory_total() -> Int

@external(erlang, "benchmark_ffi", "write_stderr")
fn write_stderr(msg: String) -> Nil

@external(erlang, "benchmark_ffi", "write_stdout_raw")
fn write_stdout_raw(msg: String) -> Nil

@external(erlang, "benchmark_ffi", "write_file")
fn write_file(path: String, content: String) -> Nil

@external(erlang, "benchmark_ffi", "halt")
fn halt(code: Int) -> Nil

@external(erlang, "benchmark_ffi", "erlang_float_to_list")
fn erlang_float_to_list(f: Float, decimals: Int) -> String
