local CSV_PATH = "../users-big.csv"

local function format_size(bytes)
    local b = tonumber(bytes)
    if b >= 1073741824 then
        return string.format("%.2f GB", b / 1073741824)
    elseif b >= 1048576 then
        return string.format("%.2f MB", b / 1048576)
    elseif b >= 1024 then
        return string.format("%.2f KB", b / 1024)
    else
        return tostring(bytes) .. " B"
    end
end

local function get_time()
    return os.clock()
end

local function print_progress(bytes_read, total_bytes, rows, start_time)
    local now = get_time()
    local elapsed = now - start_time
    local rows_per_sec = elapsed > 0 and math.floor(rows / elapsed) or 0
    local mb_per_sec = elapsed > 0 and (bytes_read / 1048576 / elapsed) or 0
    local percent = total_bytes > 0 and (bytes_read / total_bytes * 100) or 0

    local bar_width = 30
    local filled = total_bytes > 0 and math.floor(bar_width * bytes_read / total_bytes) or 0
    if filled > bar_width then filled = bar_width end

    local bar = string.rep("\xe2\x96\x88", filled) .. string.rep("\xe2\x96\x91", bar_width - filled)
    io.write(string.format("\r[%s] %.2f%% | %d rows | %d rows/sec | %.2f MB/s    ",
        bar, percent, rows, rows_per_sec, mb_per_sec))
    io.flush()
end

local function split_line(line)
    local fields = {}
    local start = 1
    for i = 1, 6 do
        local comma = line:find(",", start, true)
        if not comma then return nil end
        fields[i] = line:sub(start, comma - 1)
        start = comma + 1
    end
    fields[7] = line:sub(start)
    return fields
end

-- Main
local csv_path = CSV_PATH

print("==================================================")
print("Cross-Language Benchmark")
print("Language : LuaJIT")
print("==================================================")
print()
print("Input File : " .. csv_path)
print()

-- Open file
local fp = io.open(csv_path, "rb")
if not fp then
    io.stderr:write("Error:\nUnable to open " .. csv_path .. "\n")
    os.exit(1)
end

-- Get file size
local csv_size_bytes = fp:seek("end")
fp:seek("set", 0)

-- Start timing
local start_time = get_time()

local rows_processed = 0
local invalid_rows = 0
local bytes_read = 0

local total_salary = 0.0
local min_salary = math.huge
local max_salary = -math.huge
local total_age = 0

local countries = {}
local professions = {}

-- Streaming read with 8MB buffer
local BUF_SIZE = 8 * 1024 * 1024
local leftover = ""
local header_skipped = false
local last_progress_time = start_time

while true do
    local chunk = fp:read(BUF_SIZE)
    if not chunk then
        -- Process remaining leftover
        if #leftover > 0 and header_skipped then
            local line = leftover:gsub("[\r\n]+$", "")
            if #line > 0 then
                local fields = split_line(line)
                if fields then
                    local id = fields[1]
                    local email = fields[3]
                    if #id > 0 and email:find("@", 1, true) then
                        local age = tonumber(fields[5])
                        local salary_str = fields[7]:gsub("\r$", "")
                        local salary = tonumber(salary_str)
                        if age and salary then
                            total_salary = total_salary + salary
                            if salary < min_salary then min_salary = salary end
                            if salary > max_salary then max_salary = salary end
                            total_age = total_age + age
                            local country = fields[4]
                            local profession = fields[6]
                            if not countries[country] then
                                countries[country] = {count = 0, total_salary = 0, total_age = 0}
                            end
                            local cs = countries[country]
                            cs.count = cs.count + 1
                            cs.total_salary = cs.total_salary + salary
                            cs.total_age = cs.total_age + age
                            if not professions[profession] then
                                professions[profession] = {count = 0, total_salary = 0}
                            end
                            local ps = professions[profession]
                            ps.count = ps.count + 1
                            ps.total_salary = ps.total_salary + salary
                        else
                            invalid_rows = invalid_rows + 1
                        end
                    else
                        invalid_rows = invalid_rows + 1
                    end
                else
                    invalid_rows = invalid_rows + 1
                end
                rows_processed = rows_processed + 1
            end
        end
        break
    end

    bytes_read = bytes_read + #chunk

    local data
    if #leftover > 0 then
        data = leftover .. chunk
        leftover = ""
    else
        data = chunk
    end

    local line_start = 1
    local i = 1
    while i <= #data do
        if data:byte(i) == 10 then -- \n
            local line_end = i - 1
            if line_end >= line_start and data:byte(line_end) == 13 then -- \r
                line_end = line_end - 1
            end
            local line = data:sub(line_start, line_end)
            line_start = i + 1

            if not header_skipped then
                header_skipped = true
            elseif #line > 0 then
                local fields = split_line(line)
                if not fields then
                    invalid_rows = invalid_rows + 1
                    rows_processed = rows_processed + 1
                else
                    local id = fields[1]
                    local email = fields[3]

                    if #id == 0 or not email:find("@", 1, true) then
                        invalid_rows = invalid_rows + 1
                        rows_processed = rows_processed + 1
                    else
                        local age = tonumber(fields[5])
                        if not age then
                            invalid_rows = invalid_rows + 1
                            rows_processed = rows_processed + 1
                        else
                            local salary_str = fields[7]:gsub("\r$", "")
                            local salary = tonumber(salary_str)
                            if not salary then
                                invalid_rows = invalid_rows + 1
                                rows_processed = rows_processed + 1
                            else
                                -- Create user table
                                local user = {
                                    id = id, name = fields[2], email = email,
                                    country = fields[4], age = age,
                                    profession = fields[6], salary = salary
                                }
                                local _ = user

                                -- Statistics
                                total_salary = total_salary + salary
                                if salary < min_salary then min_salary = salary end
                                if salary > max_salary then max_salary = salary end
                                total_age = total_age + age

                                -- Country grouping
                                local country = fields[4]
                                if not countries[country] then
                                    countries[country] = {count = 0, total_salary = 0, total_age = 0}
                                end
                                local cs = countries[country]
                                cs.count = cs.count + 1
                                cs.total_salary = cs.total_salary + salary
                                cs.total_age = cs.total_age + age

                                -- Profession grouping
                                local profession = fields[6]
                                if not professions[profession] then
                                    professions[profession] = {count = 0, total_salary = 0}
                                end
                                local ps = professions[profession]
                                ps.count = ps.count + 1
                                ps.total_salary = ps.total_salary + salary

                                rows_processed = rows_processed + 1
                            end
                        end
                    end
                end
            end
        end
        i = i + 1
    end

    -- Save leftover
    if line_start <= #data then
        leftover = data:sub(line_start)
    else
        leftover = ""
    end

    -- Progress every 50ms
    local now = get_time()
    if now - last_progress_time >= 0.05 then
        print_progress(bytes_read, csv_size_bytes, rows_processed, start_time)
        last_progress_time = now
    end
end

fp:close()

-- Final progress
print_progress(csv_size_bytes, csv_size_bytes, rows_processed, start_time)
io.write("\n\n")

local valid_rows = rows_processed - invalid_rows
local avg_salary = valid_rows > 0 and (total_salary / valid_rows) or 0
local avg_age = valid_rows > 0 and (total_age / valid_rows) or 0
if min_salary == math.huge then min_salary = 0 end
if max_salary == -math.huge then max_salary = 0 end

-- Find highest/lowest paid profession
local highest_prof = ""
local highest_avg = -math.huge
local lowest_prof = ""
local lowest_avg = math.huge

for name, ps in pairs(professions) do
    local avg = ps.total_salary / ps.count
    if avg > highest_avg then highest_avg = avg; highest_prof = name end
    if avg < lowest_avg then lowest_avg = avg; lowest_prof = name end
end

-- Write JSON
local output_path = "result.json"
local out = io.open(output_path, "w")

local function wf(s) out:write(s) end
local function wl(s) out:write(s .. "\n") end

wf("{\n")
wf("  \"summary\": {\n")
wl(string.format("    \"total_records\": %d,", rows_processed))
wl(string.format("    \"valid_records\": %d,", valid_rows))
wl(string.format("    \"invalid_records\": %d,", invalid_rows))
wl(string.format("    \"average_salary\": %.2f,", avg_salary))
wl(string.format("    \"min_salary\": %.2f,", min_salary))
wl(string.format("    \"max_salary\": %.2f,", max_salary))
wl(string.format("    \"average_age\": %.2f,", avg_age))
wl(string.format("    \"highest_paid_profession\": \"%s\",", highest_prof))
wl(string.format("    \"lowest_paid_profession\": \"%s\"", lowest_prof))
wf("  },\n")

wf("  \"countries\": {\n")
local country_keys = {}
for k in pairs(countries) do country_keys[#country_keys + 1] = k end
for ci, name in ipairs(country_keys) do
    local cs = countries[name]
    local ca = cs.total_salary / cs.count
    local aa = cs.total_age / cs.count
    wl(string.format("    \"%s\": {", name))
    wl(string.format("      \"total_users\": %d,", cs.count))
    wl(string.format("      \"average_salary\": %.2f,", ca))
    wl(string.format("      \"average_age\": %.2f", aa))
    if ci < #country_keys then wf("    },\n") else wf("    }\n") end
end
wf("  },\n")

wf("  \"professions\": {\n")
local prof_keys = {}
for k in pairs(professions) do prof_keys[#prof_keys + 1] = k end
for pi, name in ipairs(prof_keys) do
    local ps = professions[name]
    local pa = ps.total_salary / ps.count
    wl(string.format("    \"%s\": {", name))
    wl(string.format("      \"count\": %d,", ps.count))
    wl(string.format("      \"average_salary\": %.2f", pa))
    if pi < #prof_keys then wf("    },\n") else wf("    }\n") end
end
wf("  }\n")
wf("}\n")
out:close()

local json_info = io.open(output_path, "r")
local json_size_bytes = json_info:seek("end")
json_info:close()

local end_time = get_time()
local elapsed = end_time - start_time
local rows_per_sec = elapsed > 0 and math.floor(rows_processed / elapsed) or 0

-- Peak memory (Lua collectgarbage count returns KB)
collectgarbage("collect")
local peak_memory = math.floor(collectgarbage("count") * 1024)

print("==================================================")
print("Benchmark Complete")
print("==================================================")
print()
print("Language           : LuaJIT")
print()
print("Rows Processed     : " .. rows_processed)
print("Invalid Rows       : " .. invalid_rows)
print()
print("CSV Size           : " .. format_size(csv_size_bytes))
print("JSON Size          : " .. format_size(json_size_bytes))
print()
print(string.format("Execution Time     : %.3f seconds", elapsed))
print()
print("Rows / Second      : " .. rows_per_sec)
print()
print("Peak Memory        : " .. format_size(peak_memory))
print()
print("Output File        : " .. output_path)
print()
print("==================================================")
