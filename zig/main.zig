const std = @import("std");
const mem = std.mem;
const fmt = std.fmt;

const csv_path = "../users-big.csv";

const Io = std.Io;
const File = Io.File;
const Dir = Io.Dir;

const User = struct {
    id: []const u8,
    name: []const u8,
    email: []const u8,
    country: []const u8,
    age: u32,
    profession: []const u8,
    salary: f64,
};

const CountryStats = struct {
    count: u64,
    total_salary: f64,
    total_age: u64,
};

const ProfessionStats = struct {
    count: u64,
    total_salary: f64,
};

fn formatSize(buf: []u8, bytes: u64) []const u8 {
    const b = @as(f64, @floatFromInt(bytes));
    if (b >= 1_073_741_824) {
        return fmt.bufPrint(buf, "{d:.2} GB", .{b / 1_073_741_824.0}) catch "??";
    } else if (b >= 1_048_576) {
        return fmt.bufPrint(buf, "{d:.2} MB", .{b / 1_048_576.0}) catch "??";
    } else if (b >= 1024) {
        return fmt.bufPrint(buf, "{d:.2} KB", .{b / 1024.0}) catch "??";
    } else {
        return fmt.bufPrint(buf, "{d} B", .{bytes}) catch "??";
    }
}

fn printToFd(fd: std.posix.fd_t, comptime format: []const u8, args: anytype) void {
    var buf: [4096]u8 = undefined;
    const msg = fmt.bufPrint(&buf, format, args) catch return;
    var total: usize = 0;
    while (total < msg.len) {
        const result = std.posix.system.write(fd, msg[total..].ptr, msg[total..].len);
        if (@as(isize, @bitCast(result)) <= 0) break;
        total += @intCast(result);
    }
}

fn printProgressFd(fd: std.posix.fd_t, bytes_read: u64, total_bytes: u64, rows: u64, start_ns: i96, now_ns: i96) void {
    const elapsed_ns = now_ns - start_ns;
    const elapsed_secs = @as(f64, @floatFromInt(@as(i64, @intCast(elapsed_ns)))) / 1_000_000_000.0;
    const rows_per_sec: u64 = if (elapsed_secs > 0) @intFromFloat(@as(f64, @floatFromInt(rows)) / elapsed_secs) else 0;
    const mb_per_sec: f64 = if (elapsed_secs > 0) @as(f64, @floatFromInt(bytes_read)) / 1_048_576.0 / elapsed_secs else 0;

    const percent = if (total_bytes > 0) @as(f64, @floatFromInt(bytes_read)) / @as(f64, @floatFromInt(total_bytes)) * 100.0 else 0.0;

    const bar_width: usize = 30;
    const filled: usize = if (total_bytes > 0) @intFromFloat(@as(f64, @floatFromInt(bar_width)) * @as(f64, @floatFromInt(bytes_read)) / @as(f64, @floatFromInt(total_bytes))) else 0;

    var bar: [30 * 3]u8 = undefined;
    var pos: usize = 0;
    for (0..bar_width) |i| {
        if (i < filled) {
            bar[pos] = 0xe2;
            bar[pos + 1] = 0x96;
            bar[pos + 2] = 0x88;
        } else {
            bar[pos] = 0xe2;
            bar[pos + 1] = 0x96;
            bar[pos + 2] = 0x91;
        }
        pos += 3;
    }

    printToFd(fd, "\r[{s}] {d:.2}% | {d} rows | {d} rows/sec | {d:.2} MB/s    ", .{
        bar[0..pos],
        percent,
        rows,
        rows_per_sec,
        mb_per_sec,
    });
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var threaded = Io.Threaded.init(std.heap.page_allocator, .{});
    const io = threaded.io();

    const stdout_fd = std.posix.STDOUT_FILENO;
    const stderr_fd = std.posix.STDERR_FILENO;

    // Print header
    printToFd(stdout_fd, "==================================================\n", .{});
    printToFd(stdout_fd, "Cross-Language Benchmark\n", .{});
    printToFd(stdout_fd, "Language : {s}\n", .{"Zig"});
    printToFd(stdout_fd, "==================================================\n\n", .{});
    printToFd(stdout_fd, "Input File : {s}\n\n", .{csv_path});

    // Open file and get size
    const cwd = Dir.cwd();
    const file = cwd.openFile(io, csv_path, .{}) catch {
        printToFd(stderr_fd, "Error:\nUnable to open {s}\n", .{csv_path});
        std.process.exit(1);
    };
    defer file.close(io);

    const file_stat = file.stat(io) catch {
        printToFd(stderr_fd, "Error:\nUnable to stat file\n", .{});
        std.process.exit(1);
    };
    const csv_size_bytes: u64 = file_stat.size;

    // Start timing
    const start_ts = Io.Clock.awake.now(io);
    const start_ns: i96 = start_ts.nanoseconds;

    // Processing state
    var rows_processed: u64 = 0;
    var invalid_rows: u64 = 0;
    var bytes_consumed: u64 = 0;

    var total_salary: f64 = 0;
    var min_salary: f64 = std.math.floatMax(f64);
    var max_salary: f64 = -std.math.floatMax(f64);
    var total_age: u64 = 0;

    var country_map = std.StringHashMap(CountryStats).init(allocator);
    var profession_map = std.StringHashMap(ProfessionStats).init(allocator);

    // Streaming read with 8MB buffer
    const BUF_SIZE = 8 * 1024 * 1024;
    var read_buf: [BUF_SIZE]u8 = undefined;

    // Fixed buffer for leftover partial line (max CSV line is well under 4KB)
    var leftover_buf: [4096]u8 = undefined;
    var leftover_len: usize = 0;

    var header_skipped = false;
    var last_progress_ns: i96 = start_ns;

    while (true) {
        const n = std.posix.read(file.handle, &read_buf) catch break;
        if (n == 0) {
            // Process any remaining leftover as the final line
            if (leftover_len > 0) {
                const line = mem.trimEnd(u8, leftover_buf[0..leftover_len], "\r\n");
                if (line.len > 0 and header_skipped) {
                    processLine(line, &rows_processed, &invalid_rows, &total_salary, &min_salary, &max_salary, &total_age, &country_map, &profession_map, allocator) catch {};
                }
            }
            break;
        }

        const chunk = read_buf[0..n];
        bytes_consumed += n;

        // Process complete lines from chunk
        var line_start: usize = 0;
        var i: usize = 0;
        while (i < chunk.len) {
            if (chunk[i] == '\n') {
                const segment = chunk[line_start..i];

                if (leftover_len > 0) {
                    // Combine leftover + segment into leftover_buf
                    const seg_len = @min(segment.len, leftover_buf.len - leftover_len);
                    @memcpy(leftover_buf[leftover_len..][0..seg_len], segment[0..seg_len]);
                    const full_len = leftover_len + seg_len;
                    const line = mem.trimEnd(u8, leftover_buf[0..full_len], "\r");
                    leftover_len = 0;

                    if (!header_skipped) {
                        header_skipped = true;
                    } else if (line.len > 0) {
                        processLine(line, &rows_processed, &invalid_rows, &total_salary, &min_salary, &max_salary, &total_age, &country_map, &profession_map, allocator) catch {};
                    }
                } else {
                    const line = mem.trimEnd(u8, segment, "\r");
                    if (!header_skipped) {
                        header_skipped = true;
                    } else if (line.len > 0) {
                        processLine(line, &rows_processed, &invalid_rows, &total_salary, &min_salary, &max_salary, &total_age, &country_map, &profession_map, allocator) catch {};
                    }
                }
                line_start = i + 1;
            }
            i += 1;
        }

        // Save any remaining partial line into leftover_buf
        if (line_start < chunk.len) {
            const remaining = chunk[line_start..];
            const copy_len = @min(remaining.len, leftover_buf.len);
            @memcpy(leftover_buf[0..copy_len], remaining[0..copy_len]);
            leftover_len = copy_len;
        } else {
            leftover_len = 0;
        }

        // Update progress at most every 50ms
        const now_ts = Io.Clock.awake.now(io);
        const now_ns: i96 = now_ts.nanoseconds;
        if (now_ns - last_progress_ns >= 50_000_000) {
            printProgressFd(stdout_fd, bytes_consumed, csv_size_bytes, rows_processed, start_ns, now_ns);
            last_progress_ns = now_ns;
        }
    }

    // Final progress
    const final_ts = Io.Clock.awake.now(io);
    printProgressFd(stdout_fd, csv_size_bytes, csv_size_bytes, rows_processed, start_ns, final_ts.nanoseconds);
    printToFd(stdout_fd, "\n\n", .{});

    const valid_rows = rows_processed - invalid_rows;
    const avg_salary = if (valid_rows > 0) total_salary / @as(f64, @floatFromInt(valid_rows)) else 0;
    const avg_age = if (valid_rows > 0) @as(f64, @floatFromInt(total_age)) / @as(f64, @floatFromInt(valid_rows)) else 0;

    // Find highest/lowest paid profession
    var highest_profession: []const u8 = "";
    var highest_avg_salary: f64 = -std.math.floatMax(f64);
    var lowest_profession: []const u8 = "";
    var lowest_avg_salary: f64 = std.math.floatMax(f64);

    var prof_iter = profession_map.iterator();
    while (prof_iter.next()) |entry| {
        const prof_avg = entry.value_ptr.total_salary / @as(f64, @floatFromInt(entry.value_ptr.count));
        if (prof_avg > highest_avg_salary) {
            highest_avg_salary = prof_avg;
            highest_profession = entry.key_ptr.*;
        }
        if (prof_avg < lowest_avg_salary) {
            lowest_avg_salary = prof_avg;
            lowest_profession = entry.key_ptr.*;
        }
    }

    // Build JSON output
    var json: std.ArrayList(u8) = .empty;
    var print_buf: [512]u8 = undefined;

    try json.appendSlice(allocator, "{\n");

    // Summary
    try json.appendSlice(allocator, "  \"summary\": {\n");
    try json.appendSlice(allocator, fmt.bufPrint(&print_buf, "    \"total_records\": {d},\n", .{rows_processed}) catch unreachable);
    try json.appendSlice(allocator, fmt.bufPrint(&print_buf, "    \"valid_records\": {d},\n", .{valid_rows}) catch unreachable);
    try json.appendSlice(allocator, fmt.bufPrint(&print_buf, "    \"invalid_records\": {d},\n", .{invalid_rows}) catch unreachable);
    try json.appendSlice(allocator, fmt.bufPrint(&print_buf, "    \"average_salary\": {d:.2},\n", .{avg_salary}) catch unreachable);
    try json.appendSlice(allocator, fmt.bufPrint(&print_buf, "    \"min_salary\": {d:.2},\n", .{if (min_salary == std.math.floatMax(f64)) @as(f64, 0) else min_salary}) catch unreachable);
    try json.appendSlice(allocator, fmt.bufPrint(&print_buf, "    \"max_salary\": {d:.2},\n", .{if (max_salary == -std.math.floatMax(f64)) @as(f64, 0) else max_salary}) catch unreachable);
    try json.appendSlice(allocator, fmt.bufPrint(&print_buf, "    \"average_age\": {d:.2},\n", .{avg_age}) catch unreachable);
    try json.appendSlice(allocator, fmt.bufPrint(&print_buf, "    \"highest_paid_profession\": \"{s}\",\n", .{highest_profession}) catch unreachable);
    try json.appendSlice(allocator, fmt.bufPrint(&print_buf, "    \"lowest_paid_profession\": \"{s}\"\n", .{lowest_profession}) catch unreachable);
    try json.appendSlice(allocator, "  },\n");

    // Countries
    try json.appendSlice(allocator, "  \"countries\": {\n");
    var country_iter = country_map.iterator();
    var country_count: usize = 0;
    const country_total = country_map.count();
    while (country_iter.next()) |entry| {
        country_count += 1;
        const c_avg_salary = entry.value_ptr.total_salary / @as(f64, @floatFromInt(entry.value_ptr.count));
        const c_avg_age = @as(f64, @floatFromInt(entry.value_ptr.total_age)) / @as(f64, @floatFromInt(entry.value_ptr.count));
        try json.appendSlice(allocator, fmt.bufPrint(&print_buf, "    \"{s}\": {{\n", .{entry.key_ptr.*}) catch unreachable);
        try json.appendSlice(allocator, fmt.bufPrint(&print_buf, "      \"total_users\": {d},\n", .{entry.value_ptr.count}) catch unreachable);
        try json.appendSlice(allocator, fmt.bufPrint(&print_buf, "      \"average_salary\": {d:.2},\n", .{c_avg_salary}) catch unreachable);
        try json.appendSlice(allocator, fmt.bufPrint(&print_buf, "      \"average_age\": {d:.2}\n", .{c_avg_age}) catch unreachable);
        if (country_count < country_total) {
            try json.appendSlice(allocator, "    },\n");
        } else {
            try json.appendSlice(allocator, "    }\n");
        }
    }
    try json.appendSlice(allocator, "  },\n");

    // Professions
    try json.appendSlice(allocator, "  \"professions\": {\n");
    var prof_iter2 = profession_map.iterator();
    var prof_count: usize = 0;
    const prof_total = profession_map.count();
    while (prof_iter2.next()) |entry| {
        prof_count += 1;
        const p_avg_salary = entry.value_ptr.total_salary / @as(f64, @floatFromInt(entry.value_ptr.count));
        try json.appendSlice(allocator, fmt.bufPrint(&print_buf, "    \"{s}\": {{\n", .{entry.key_ptr.*}) catch unreachable);
        try json.appendSlice(allocator, fmt.bufPrint(&print_buf, "      \"count\": {d},\n", .{entry.value_ptr.count}) catch unreachable);
        try json.appendSlice(allocator, fmt.bufPrint(&print_buf, "      \"average_salary\": {d:.2}\n", .{p_avg_salary}) catch unreachable);
        if (prof_count < prof_total) {
            try json.appendSlice(allocator, "    },\n");
        } else {
            try json.appendSlice(allocator, "    }\n");
        }
    }
    try json.appendSlice(allocator, "  }\n");
    try json.appendSlice(allocator, "}\n");

    // Write JSON to disk
    const output_path = "result.json";
    const out_file = try cwd.createFile(io, output_path, .{});
    defer out_file.close(io);
    try out_file.writeStreamingAll(io, json.items);

    const end_ts = Io.Clock.awake.now(io);
    const end_ns: i96 = end_ts.nanoseconds;
    const elapsed_ns = end_ns - start_ns;
    const elapsed_secs = @as(f64, @floatFromInt(@as(i64, @intCast(elapsed_ns)))) / 1_000_000_000.0;

    const json_size_bytes: u64 = @intCast(json.items.len);
    const rows_per_sec: u64 = if (elapsed_secs > 0) @intFromFloat(@as(f64, @floatFromInt(rows_processed)) / elapsed_secs) else 0;

    // Get peak memory via getrusage
    const usage = std.posix.getrusage(0); // RUSAGE_SELF
    const peak_rss: u64 = @intCast(usage.maxrss);
    var peak_buf: [64]u8 = undefined;

    // Print completion summary
    var size_buf1: [64]u8 = undefined;
    var size_buf2: [64]u8 = undefined;

    printToFd(stdout_fd, "==================================================\n", .{});
    printToFd(stdout_fd, "Benchmark Complete\n", .{});
    printToFd(stdout_fd, "==================================================\n\n", .{});
    printToFd(stdout_fd, "Language           : {s}\n\n", .{"Zig"});
    printToFd(stdout_fd, "Rows Processed     : {d}\n", .{rows_processed});
    printToFd(stdout_fd, "Invalid Rows       : {d}\n\n", .{invalid_rows});
    printToFd(stdout_fd, "CSV Size           : {s}\n", .{formatSize(&size_buf1, csv_size_bytes)});
    printToFd(stdout_fd, "JSON Size          : {s}\n\n", .{formatSize(&size_buf2, json_size_bytes)});
    printToFd(stdout_fd, "Execution Time     : {d:.3} seconds\n\n", .{elapsed_secs});
    printToFd(stdout_fd, "Rows / Second      : {d}\n\n", .{rows_per_sec});
    printToFd(stdout_fd, "Peak Memory        : {s}\n\n", .{formatSize(&peak_buf, peak_rss)});
    printToFd(stdout_fd, "Output File        : {s}\n\n", .{output_path});
    printToFd(stdout_fd, "==================================================\n", .{});
}

fn processLine(
    line: []const u8,
    rows_processed: *u64,
    invalid_rows: *u64,
    total_salary: *f64,
    min_salary: *f64,
    max_salary: *f64,
    total_age: *u64,
    country_map: *std.StringHashMap(CountryStats),
    profession_map: *std.StringHashMap(ProfessionStats),
    allocator: std.mem.Allocator,
) !void {
    // Parse CSV fields
    var fields: [7][]const u8 = undefined;
    var field_count: usize = 0;
    var field_iter = mem.splitScalar(u8, line, ',');
    while (field_iter.next()) |field| {
        if (field_count >= 7) break;
        fields[field_count] = field;
        field_count += 1;
    }

    if (field_count < 7) {
        invalid_rows.* += 1;
        rows_processed.* += 1;
        return;
    }

    const id = fields[0];
    const email = fields[2];
    const country = fields[3];
    const age_str = fields[4];
    const profession = fields[5];
    const salary_str = mem.trimEnd(u8, fields[6], "\r");

    // Validation
    if (id.len == 0 or mem.indexOf(u8, email, "@") == null) {
        invalid_rows.* += 1;
        rows_processed.* += 1;
        return;
    }

    const age = fmt.parseUnsigned(u32, age_str, 10) catch {
        invalid_rows.* += 1;
        rows_processed.* += 1;
        return;
    };

    const salary = fmt.parseFloat(f64, salary_str) catch {
        invalid_rows.* += 1;
        rows_processed.* += 1;
        return;
    };

    // Create user struct (required by spec)
    const user = User{
        .id = id,
        .name = fields[1],
        .email = email,
        .country = country,
        .age = age,
        .profession = profession,
        .salary = salary,
    };
    _ = user;

    // Accumulate statistics
    total_salary.* += salary;
    if (salary < min_salary.*) min_salary.* = salary;
    if (salary > max_salary.*) max_salary.* = salary;
    total_age.* += age;

    // Country grouping
    if (country_map.getPtr(country)) |stats| {
        stats.count += 1;
        stats.total_salary += salary;
        stats.total_age += age;
    } else {
        const owned = try allocator.dupe(u8, country);
        try country_map.put(owned, CountryStats{
            .count = 1,
            .total_salary = salary,
            .total_age = age,
        });
    }

    // Profession grouping
    if (profession_map.getPtr(profession)) |stats| {
        stats.count += 1;
        stats.total_salary += salary;
    } else {
        const owned = try allocator.dupe(u8, profession);
        try profession_map.put(owned, ProfessionStats{
            .count = 1,
            .total_salary = salary,
        });
    }

    rows_processed.* += 1;
}
