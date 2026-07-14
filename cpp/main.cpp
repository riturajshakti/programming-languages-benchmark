#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <unordered_map>
#include <cstring>
#include <cmath>
#include <ctime>
#include <sys/stat.h>
#include <sys/resource.h>

const char *CSV_PATH = "../users-big.csv";

struct User {
    std::string id;
    std::string name;
    std::string email;
    std::string country;
    int age;
    std::string profession;
    double salary;
};

struct CountryStats {
    int count = 0;
    double total_salary = 0;
    long total_age = 0;
};

struct ProfessionStats {
    int count = 0;
    double total_salary = 0;
};

static double get_time_ns() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return static_cast<double>(ts.tv_sec) * 1e9 + static_cast<double>(ts.tv_nsec);
}

static std::string format_size(unsigned long long bytes) {
    double b = static_cast<double>(bytes);
    char buf[64];
    if (b >= 1073741824.0)
        snprintf(buf, sizeof(buf), "%.2f GB", b / 1073741824.0);
    else if (b >= 1048576.0)
        snprintf(buf, sizeof(buf), "%.2f MB", b / 1048576.0);
    else if (b >= 1024.0)
        snprintf(buf, sizeof(buf), "%.2f KB", b / 1024.0);
    else
        snprintf(buf, sizeof(buf), "%llu B", bytes);
    return buf;
}

static void print_progress(unsigned long long bytes_read, unsigned long long total_bytes,
                            unsigned long long rows, double start_ns) {
    double now = get_time_ns();
    double elapsed = (now - start_ns) / 1e9;
    unsigned long long rows_per_sec = elapsed > 0 ? static_cast<unsigned long long>(static_cast<double>(rows) / elapsed) : 0;
    double mb_per_sec = elapsed > 0 ? static_cast<double>(bytes_read) / 1048576.0 / elapsed : 0;
    double percent = total_bytes > 0 ? static_cast<double>(bytes_read) / static_cast<double>(total_bytes) * 100.0 : 0;

    int bar_width = 30;
    int filled = total_bytes > 0 ? static_cast<int>(static_cast<double>(bar_width) * static_cast<double>(bytes_read) / static_cast<double>(total_bytes)) : 0;
    if (filled > bar_width) filled = bar_width;

    std::string bar;
    for (int i = 0; i < bar_width; i++) {
        if (i < filled)
            bar += "\xe2\x96\x88";
        else
            bar += "\xe2\x96\x91";
    }

    printf("\r[%s] %.2f%% | %llu rows | %llu rows/sec | %.2f MB/s    ",
           bar.c_str(), percent, rows, rows_per_sec, mb_per_sec);
    fflush(stdout);
}

static bool parse_fields(char *line, char *fields[], int max_fields) {
    int count = 0;
    char *p = line;
    while (count < max_fields) {
        char *comma = strchr(p, ',');
        if (comma && count < max_fields - 1) {
            *comma = '\0';
            fields[count++] = p;
            p = comma + 1;
        } else {
            fields[count++] = p;
            break;
        }
    }
    return count >= max_fields;
}

int main() {
    const char *csv_path = CSV_PATH;

    // Print header
    std::cout << "==================================================\n";
    std::cout << "Cross-Language Benchmark\n";
    std::cout << "Language : C++\n";
    std::cout << "==================================================\n\n";
    std::cout << "Input File : " << csv_path << "\n\n";

    // Open file
    FILE *fp = fopen(csv_path, "r");
    if (!fp) {
        std::cerr << "Error:\nUnable to open " << csv_path << "\n";
        return 1;
    }

    // Get file size
    struct stat st;
    if (fstat(fileno(fp), &st) != 0) {
        std::cerr << "Error:\nUnable to stat " << csv_path << "\n";
        fclose(fp);
        return 1;
    }
    unsigned long long csv_size_bytes = static_cast<unsigned long long>(st.st_size);

    // Start timing
    double start_ns = get_time_ns();

    // Processing state
    unsigned long long rows_processed = 0;
    unsigned long long invalid_rows = 0;
    unsigned long long bytes_read = 0;

    double total_salary = 0;
    double min_salary = 1e308;
    double max_salary = -1e308;
    long total_age = 0;

    std::unordered_map<std::string, CountryStats> countries;
    std::unordered_map<std::string, ProfessionStats> professions;

    // Streaming read with 8MB buffer
    static char buf[8 * 1024 * 1024];
    char leftover[4096];
    int leftover_len = 0;
    bool header_skipped = false;
    double last_progress_ns = start_ns;

    while (true) {
        size_t n = fread(buf, 1, sizeof(buf), fp);
        if (n == 0) {
            // Process remaining leftover
            if (leftover_len > 0) {
                while (leftover_len > 0 && (leftover[leftover_len - 1] == '\r' || leftover[leftover_len - 1] == '\n'))
                    leftover_len--;
                leftover[leftover_len] = '\0';

                if (leftover_len > 0 && header_skipped) {
                    char *fields[7];
                    if (parse_fields(leftover, fields, 7)) {
                        char *sal = fields[6];
                        size_t sl = strlen(sal);
                        while (sl > 0 && sal[sl - 1] == '\r') sal[--sl] = '\0';

                        if (strlen(fields[0]) == 0 || strchr(fields[2], '@') == nullptr) {
                            invalid_rows++;
                        } else {
                            char *endp;
                            long age = strtol(fields[4], &endp, 10);
                            if (*endp != '\0') {
                                invalid_rows++;
                            } else {
                                double salary = strtod(sal, &endp);
                                if (*endp != '\0') {
                                    invalid_rows++;
                                } else {
                                    User user{fields[0], fields[1], fields[2], fields[3],
                                              static_cast<int>(age), fields[5], salary};
                                    (void)user;
                                    total_salary += salary;
                                    if (salary < min_salary) min_salary = salary;
                                    if (salary > max_salary) max_salary = salary;
                                    total_age += age;
                                    auto &cs = countries[fields[3]];
                                    cs.count++; cs.total_salary += salary; cs.total_age += age;
                                    auto &ps = professions[fields[5]];
                                    ps.count++; ps.total_salary += salary;
                                }
                            }
                        }
                        rows_processed++;
                    }
                }
            }
            break;
        }

        bytes_read += n;

        size_t start = 0;
        for (size_t i = 0; i < n; i++) {
            if (buf[i] == '\n') {
                int seg_len = static_cast<int>(i - start);

                char line_buf[4096];
                int line_len = 0;

                if (leftover_len > 0) {
                    memcpy(line_buf, leftover, leftover_len);
                    line_len = leftover_len;
                    leftover_len = 0;
                }
                int copy = seg_len;
                if (line_len + copy > static_cast<int>(sizeof(line_buf)) - 1)
                    copy = static_cast<int>(sizeof(line_buf)) - 1 - line_len;
                if (copy > 0) {
                    memcpy(line_buf + line_len, buf + start, copy);
                    line_len += copy;
                }
                while (line_len > 0 && line_buf[line_len - 1] == '\r')
                    line_len--;
                line_buf[line_len] = '\0';

                start = i + 1;

                if (!header_skipped) {
                    header_skipped = true;
                    continue;
                }
                if (line_len == 0) continue;

                // Parse fields
                char *fields[7];
                if (!parse_fields(line_buf, fields, 7)) {
                    invalid_rows++;
                    rows_processed++;
                    continue;
                }

                // Validation
                if (strlen(fields[0]) == 0 || strchr(fields[2], '@') == nullptr) {
                    invalid_rows++;
                    rows_processed++;
                    continue;
                }

                char *endp;
                long age = strtol(fields[4], &endp, 10);
                if (*endp != '\0') {
                    invalid_rows++;
                    rows_processed++;
                    continue;
                }

                double salary = strtod(fields[6], &endp);
                if (*endp != '\0') {
                    invalid_rows++;
                    rows_processed++;
                    continue;
                }

                // Create user struct
                User user{fields[0], fields[1], fields[2], fields[3],
                          static_cast<int>(age), fields[5], salary};
                (void)user;

                // Statistics
                total_salary += salary;
                if (salary < min_salary) min_salary = salary;
                if (salary > max_salary) max_salary = salary;
                total_age += age;

                // Country grouping
                auto &cs = countries[fields[3]];
                cs.count++;
                cs.total_salary += salary;
                cs.total_age += age;

                // Profession grouping
                auto &ps = professions[fields[5]];
                ps.count++;
                ps.total_salary += salary;

                rows_processed++;
            }
        }

        // Save leftover
        if (start < n) {
            int remaining = static_cast<int>(n - start);
            if (remaining > static_cast<int>(sizeof(leftover)) - 1)
                remaining = static_cast<int>(sizeof(leftover)) - 1;
            memcpy(leftover, buf + start, remaining);
            leftover_len = remaining;
        } else {
            leftover_len = 0;
        }

        // Progress every 50ms
        double now = get_time_ns();
        if (now - last_progress_ns >= 50000000.0) {
            print_progress(bytes_read, csv_size_bytes, rows_processed, start_ns);
            last_progress_ns = now;
        }
    }

    fclose(fp);

    // Final progress
    print_progress(csv_size_bytes, csv_size_bytes, rows_processed, start_ns);
    printf("\n\n");

    unsigned long long valid_rows = rows_processed - invalid_rows;
    double avg_salary = valid_rows > 0 ? total_salary / static_cast<double>(valid_rows) : 0;
    double avg_age = valid_rows > 0 ? static_cast<double>(total_age) / static_cast<double>(valid_rows) : 0;
    if (min_salary > 1e307) min_salary = 0;
    if (max_salary < -1e307) max_salary = 0;

    // Find highest/lowest paid profession
    std::string highest_prof, lowest_prof;
    double highest_avg = -1e308, lowest_avg = 1e308;

    for (auto &[name, ps] : professions) {
        double avg = ps.total_salary / static_cast<double>(ps.count);
        if (avg > highest_avg) { highest_avg = avg; highest_prof = name; }
        if (avg < lowest_avg) { lowest_avg = avg; lowest_prof = name; }
    }

    // Write JSON
    const char *output_path = "result.json";
    FILE *out = fopen(output_path, "w");
    if (!out) {
        std::cerr << "Error:\nFailed to write " << output_path << "\n";
        return 1;
    }

    fprintf(out, "{\n");
    fprintf(out, "  \"summary\": {\n");
    fprintf(out, "    \"total_records\": %llu,\n", rows_processed);
    fprintf(out, "    \"valid_records\": %llu,\n", valid_rows);
    fprintf(out, "    \"invalid_records\": %llu,\n", invalid_rows);
    fprintf(out, "    \"average_salary\": %.2f,\n", avg_salary);
    fprintf(out, "    \"min_salary\": %.2f,\n", min_salary);
    fprintf(out, "    \"max_salary\": %.2f,\n", max_salary);
    fprintf(out, "    \"average_age\": %.2f,\n", avg_age);
    fprintf(out, "    \"highest_paid_profession\": \"%s\",\n", highest_prof.c_str());
    fprintf(out, "    \"lowest_paid_profession\": \"%s\"\n", lowest_prof.c_str());
    fprintf(out, "  },\n");

    fprintf(out, "  \"countries\": {\n");
    int ci = 0;
    for (auto &[name, cs] : countries) {
        ci++;
        double ca = cs.total_salary / static_cast<double>(cs.count);
        double aa = static_cast<double>(cs.total_age) / static_cast<double>(cs.count);
        fprintf(out, "    \"%s\": {\n", name.c_str());
        fprintf(out, "      \"total_users\": %d,\n", cs.count);
        fprintf(out, "      \"average_salary\": %.2f,\n", ca);
        fprintf(out, "      \"average_age\": %.2f\n", aa);
        fprintf(out, "    }%s\n", ci < static_cast<int>(countries.size()) ? "," : "");
    }
    fprintf(out, "  },\n");

    fprintf(out, "  \"professions\": {\n");
    int pi = 0;
    for (auto &[name, ps] : professions) {
        pi++;
        double pa = ps.total_salary / static_cast<double>(ps.count);
        fprintf(out, "    \"%s\": {\n", name.c_str());
        fprintf(out, "      \"count\": %d,\n", ps.count);
        fprintf(out, "      \"average_salary\": %.2f\n", pa);
        fprintf(out, "    }%s\n", pi < static_cast<int>(professions.size()) ? "," : "");
    }
    fprintf(out, "  }\n");
    fprintf(out, "}\n");

    long json_size = ftell(out);
    fclose(out);
    unsigned long long json_size_bytes = static_cast<unsigned long long>(json_size);

    double end_ns = get_time_ns();
    double elapsed = (end_ns - start_ns) / 1e9;
    unsigned long long rows_per_sec = elapsed > 0 ? static_cast<unsigned long long>(static_cast<double>(rows_processed) / elapsed) : 0;

    // Peak memory
    struct rusage usage;
    getrusage(RUSAGE_SELF, &usage);
    unsigned long long peak_rss = static_cast<unsigned long long>(usage.ru_maxrss);

    std::cout << "==================================================\n";
    std::cout << "Benchmark Complete\n";
    std::cout << "==================================================\n\n";
    std::cout << "Language           : C++\n\n";
    std::cout << "Rows Processed     : " << rows_processed << "\n";
    std::cout << "Invalid Rows       : " << invalid_rows << "\n\n";
    std::cout << "CSV Size           : " << format_size(csv_size_bytes) << "\n";
    std::cout << "JSON Size          : " << format_size(json_size_bytes) << "\n\n";
    printf("Execution Time     : %.3f seconds\n\n", elapsed);
    std::cout << "Rows / Second      : " << rows_per_sec << "\n\n";
    std::cout << "Peak Memory        : " << format_size(peak_rss) << "\n\n";
    std::cout << "Output File        : " << output_path << "\n\n";
    std::cout << "==================================================\n";

    return 0;
}
