let csv_path = "../users-big.csv"

type user = {
  id: string;
  name: string;
  email: string;
  country: string;
  age: int;
  profession: string;
  salary: float;
}

type country_stats = {
  mutable count: int;
  mutable total_salary: float;
  mutable total_age: int;
}

type profession_stats = {
  mutable p_count: int;
  mutable p_total_salary: float;
}

let format_size bytes =
  let b = Float.of_int bytes in
  if b >= 1073741824.0 then Printf.sprintf "%.2f GB" (b /. 1073741824.0)
  else if b >= 1048576.0 then Printf.sprintf "%.2f MB" (b /. 1048576.0)
  else if b >= 1024.0 then Printf.sprintf "%.2f KB" (b /. 1024.0)
  else Printf.sprintf "%d B" bytes

let get_time_ns () =
  let t = Unix.gettimeofday () in
  t *. 1e9

let print_progress bytes_read total_bytes rows start_ns =
  let now = get_time_ns () in
  let elapsed = (now -. start_ns) /. 1e9 in
  let rows_per_sec = if elapsed > 0.0 then int_of_float (Float.of_int rows /. elapsed) else 0 in
  let mb_per_sec = if elapsed > 0.0 then Float.of_int bytes_read /. 1048576.0 /. elapsed else 0.0 in
  let percent = if total_bytes > 0 then Float.of_int bytes_read /. Float.of_int total_bytes *. 100.0 else 0.0 in
  let bar_width = 30 in
  let filled = if total_bytes > 0 then
    min bar_width (int_of_float (Float.of_int bar_width *. Float.of_int bytes_read /. Float.of_int total_bytes))
  else 0 in
  let bar = Buffer.create (bar_width * 3) in
  for i = 0 to bar_width - 1 do
    if i < filled then Buffer.add_string bar "\xe2\x96\x88"
    else Buffer.add_string bar "\xe2\x96\x91"
  done;
  Printf.printf "\r[%s] %.2f%% | %d rows | %d rows/sec | %.2f MB/s    "
    (Buffer.contents bar) percent rows rows_per_sec mb_per_sec;
  flush stdout

let split_line line =
  let len = String.length line in
  let fields = Array.make 7 "" in
  let start = ref 0 in
  let ok = ref true in
  for f = 0 to 5 do
    if !ok then begin
      match String.index_from_opt line !start ',' with
      | Some pos ->
        fields.(f) <- String.sub line !start (pos - !start);
        start := pos + 1
      | None -> ok := false
    end
  done;
  if !ok then begin
    fields.(6) <- String.sub line !start (len - !start);
    Some fields
  end else None

let process_line line rows_processed invalid_rows total_salary min_salary max_salary
    total_age countries professions =
  match split_line line with
  | None ->
    invalid_rows := !invalid_rows + 1;
    rows_processed := !rows_processed + 1
  | Some fields ->
    let id = fields.(0) in
    let name = fields.(1) in
    let email = fields.(2) in
    let country = fields.(3) in
    let age_str = fields.(4) in
    let profession = fields.(5) in
    let salary_str = let s = fields.(6) in
      if String.length s > 0 && s.[String.length s - 1] = '\r'
      then String.sub s 0 (String.length s - 1) else s in
    (* Validation *)
    if String.length id = 0 || not (String.contains email '@') then begin
      invalid_rows := !invalid_rows + 1;
      rows_processed := !rows_processed + 1
    end else begin
      match int_of_string_opt age_str with
      | None ->
        invalid_rows := !invalid_rows + 1;
        rows_processed := !rows_processed + 1
      | Some age ->
        match float_of_string_opt salary_str with
        | None ->
          invalid_rows := !invalid_rows + 1;
          rows_processed := !rows_processed + 1
        | Some salary ->
          (* Create user record *)
          let _user = { id; name; email; country; age; profession; salary } in
          ignore _user;
          (* Statistics *)
          total_salary := !total_salary +. salary;
          if salary < !min_salary then min_salary := salary;
          if salary > !max_salary then max_salary := salary;
          total_age := !total_age + age;
          (* Country grouping *)
          (match Hashtbl.find_opt countries country with
          | Some cs ->
            cs.count <- cs.count + 1;
            cs.total_salary <- cs.total_salary +. salary;
            cs.total_age <- cs.total_age + age
          | None ->
            Hashtbl.add countries country { count = 1; total_salary = salary; total_age = age });
          (* Profession grouping *)
          (match Hashtbl.find_opt professions profession with
          | Some ps ->
            ps.p_count <- ps.p_count + 1;
            ps.p_total_salary <- ps.p_total_salary +. salary
          | None ->
            Hashtbl.add professions profession { p_count = 1; p_total_salary = salary });
          rows_processed := !rows_processed + 1
    end

let () =
  Printf.printf "==================================================\n";
  Printf.printf "Cross-Language Benchmark\n";
  Printf.printf "Language : OCaml\n";
  Printf.printf "==================================================\n\n";
  Printf.printf "Input File : %s\n\n" csv_path;

  (* Open file *)
  let fd = try Unix.openfile csv_path [Unix.O_RDONLY] 0
    with Unix.Unix_error _ ->
      Printf.eprintf "Error:\nUnable to open %s\n" csv_path;
      exit 1
  in

  (* Get file size *)
  let stats = Unix.fstat fd in
  let csv_size_bytes = stats.Unix.st_size in

  (* Start timing *)
  let start_ns = get_time_ns () in

  let rows_processed = ref 0 in
  let invalid_rows = ref 0 in
  let bytes_read = ref 0 in

  let total_salary = ref 0.0 in
  let min_salary = ref infinity in
  let max_salary = ref neg_infinity in
  let total_age = ref 0 in

  let countries = Hashtbl.create 64 in
  let professions = Hashtbl.create 64 in

  (* Streaming read with 8MB buffer *)
  let buf_size = 8 * 1024 * 1024 in
  let buf = Bytes.create buf_size in
  let leftover = Buffer.create 4096 in
  let header_skipped = ref false in
  let last_progress_ns = ref start_ns in

  let running = ref true in
  while !running do
    let n = Unix.read fd buf 0 buf_size in
    if n = 0 then begin
      (* Process remaining leftover *)
      if Buffer.length leftover > 0 && !header_skipped then begin
        let lo = String.trim (Buffer.contents leftover) in
        if String.length lo > 0 then
          process_line lo rows_processed invalid_rows total_salary
            min_salary max_salary total_age countries professions
      end;
      running := false
    end else begin
      bytes_read := !bytes_read + n;
      let chunk = Bytes.sub_string buf 0 n in

      let data = if Buffer.length leftover > 0 then begin
        Buffer.add_string leftover chunk;
        let s = Buffer.contents leftover in
        Buffer.clear leftover;
        s
      end else chunk in

      let data_len = String.length data in
      let line_start = ref 0 in
      for i = 0 to data_len - 1 do
        if data.[i] = '\n' then begin
          let line_end = if i > !line_start && data.[i-1] = '\r' then i - 1 else i in
          let line = String.sub data !line_start (line_end - !line_start) in
          line_start := i + 1;

          if not !header_skipped then
            header_skipped := true
          else if String.length line > 0 then
            process_line line rows_processed invalid_rows total_salary
              min_salary max_salary total_age countries professions
        end
      done;

      (* Save leftover *)
      if !line_start < data_len then
        Buffer.add_string leftover (String.sub data !line_start (data_len - !line_start));

      (* Progress every 50ms *)
      let now = get_time_ns () in
      if now -. !last_progress_ns >= 50000000.0 then begin
        print_progress !bytes_read csv_size_bytes !rows_processed start_ns;
        last_progress_ns := now
      end
    end
  done;

  Unix.close fd;

  (* Final progress *)
  print_progress csv_size_bytes csv_size_bytes !rows_processed start_ns;
  Printf.printf "\n\n";

  let valid_rows = !rows_processed - !invalid_rows in
  let avg_salary = if valid_rows > 0 then !total_salary /. Float.of_int valid_rows else 0.0 in
  let avg_age = if valid_rows > 0 then Float.of_int !total_age /. Float.of_int valid_rows else 0.0 in
  let min_sal = if !min_salary = infinity then 0.0 else !min_salary in
  let max_sal = if !max_salary = neg_infinity then 0.0 else !max_salary in

  (* Find highest/lowest paid profession *)
  let highest_prof = ref "" in
  let highest_avg = ref neg_infinity in
  let lowest_prof = ref "" in
  let lowest_avg = ref infinity in
  Hashtbl.iter (fun name ps ->
    let avg = ps.p_total_salary /. Float.of_int ps.p_count in
    if avg > !highest_avg then begin highest_avg := avg; highest_prof := name end;
    if avg < !lowest_avg then begin lowest_avg := avg; lowest_prof := name end
  ) professions;

  (* Write JSON *)
  let output_path = "result.json" in
  let oc = open_out output_path in
  let wf s = output_string oc s in
  let wl fmt = Printf.ksprintf (fun s -> output_string oc s; output_char oc '\n') fmt in

  wf "{\n";
  wf "  \"summary\": {\n";
  wl "    \"total_records\": %d," !rows_processed;
  wl "    \"valid_records\": %d," valid_rows;
  wl "    \"invalid_records\": %d," !invalid_rows;
  wl "    \"average_salary\": %.2f," avg_salary;
  wl "    \"min_salary\": %.2f," min_sal;
  wl "    \"max_salary\": %.2f," max_sal;
  wl "    \"average_age\": %.2f," avg_age;
  wl "    \"highest_paid_profession\": \"%s\"," !highest_prof;
  wl "    \"lowest_paid_profession\": \"%s\"" !lowest_prof;
  wf "  },\n";

  wf "  \"countries\": {\n";
  let country_list = Hashtbl.fold (fun k v acc -> (k, v) :: acc) countries [] in
  let country_total = List.length country_list in
  let ci = ref 0 in
  List.iter (fun (name, cs) ->
    ci := !ci + 1;
    let ca = cs.total_salary /. Float.of_int cs.count in
    let aa = Float.of_int cs.total_age /. Float.of_int cs.count in
    wl "    \"%s\": {" name;
    wl "      \"total_users\": %d," cs.count;
    wl "      \"average_salary\": %.2f," ca;
    wl "      \"average_age\": %.2f" aa;
    if !ci < country_total then wf "    },\n" else wf "    }\n"
  ) country_list;
  wf "  },\n";

  wf "  \"professions\": {\n";
  let prof_list = Hashtbl.fold (fun k v acc -> (k, v) :: acc) professions [] in
  let prof_total = List.length prof_list in
  let pi = ref 0 in
  List.iter (fun (name, ps) ->
    pi := !pi + 1;
    let pa = ps.p_total_salary /. Float.of_int ps.p_count in
    wl "    \"%s\": {" name;
    wl "      \"count\": %d," ps.p_count;
    wl "      \"average_salary\": %.2f" pa;
    if !pi < prof_total then wf "    },\n" else wf "    }\n"
  ) prof_list;
  wf "  }\n";
  wf "}\n";

  let json_size = pos_out oc in
  close_out oc;

  let end_ns = get_time_ns () in
  let elapsed = (end_ns -. start_ns) /. 1e9 in
  let rows_per_sec = if elapsed > 0.0 then int_of_float (Float.of_int !rows_processed /. elapsed) else 0 in

  (* Peak memory via GC top_heap_words *)
  let gc_stat = Gc.stat () in
  let peak_memory = gc_stat.Gc.top_heap_words * (Sys.word_size / 8) in

  Printf.printf "==================================================\n";
  Printf.printf "Benchmark Complete\n";
  Printf.printf "==================================================\n\n";
  Printf.printf "Language           : OCaml\n\n";
  Printf.printf "Rows Processed     : %d\n" !rows_processed;
  Printf.printf "Invalid Rows       : %d\n\n" !invalid_rows;
  Printf.printf "CSV Size           : %s\n" (format_size csv_size_bytes);
  Printf.printf "JSON Size          : %s\n\n" (format_size json_size);
  Printf.printf "Execution Time     : %.3f seconds\n\n" elapsed;
  Printf.printf "Rows / Second      : %d\n\n" rows_per_sec;
  Printf.printf "Peak Memory        : %s\n\n" (format_size peak_memory);
  Printf.printf "Output File        : %s\n\n" output_path;
  Printf.printf "==================================================\n"
