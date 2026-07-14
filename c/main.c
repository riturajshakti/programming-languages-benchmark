#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <sys/stat.h>
#include <sys/resource.h>
#include <math.h>

#define CSV_PATH "../users-big.csv"

typedef struct {
    const char *id;
    const char *name;
    const char *email;
    const char *country;
    int age;
    const char *profession;
    double salary;
} User;

typedef struct {
    char key[64];
    int count;
    double total_salary;
    long total_age;
} CountryStats;

typedef struct {
    char key[64];
    int count;
    double total_salary;
} ProfessionStats;

#define MAX_COUNTRIES 256
#define MAX_PROFESSIONS 256

static CountryStats countries[MAX_COUNTRIES];
static int country_count = 0;

static ProfessionStats professions[MAX_PROFESSIONS];
static int profession_count = 0;

static CountryStats *find_or_add_country(const char *name) {
    for (int i = 0; i < country_count; i++) {
        if (strcmp(countries[i].key, name) == 0) {
            return &countries[i];
        }
    }
    if (country_count < MAX_COUNTRIES) {
        CountryStats *cs = &countries[country_count++];
        strncpy(cs->key, name, sizeof(cs->key) - 1);
        cs->key[sizeof(cs->key) - 1] = '\0';
        cs->count = 0;
        cs->total_salary = 0;
        cs->total_age = 0;
        return cs;
    }
    return NULL;
}

static ProfessionStats *find_or_add_profession(const char *name) {
    for (int i = 0; i < profession_count; i++) {
        if (strcmp(professions[i].key, name) == 0) {
            return &professions[i];
        }
    }
    if (profession_count < MAX_PROFESSIONS) {
        ProfessionStats *ps = &professions[profession_count++];
        strncpy(ps->key, name, sizeof(ps->key) - 1);
        ps->key[sizeof(ps->key) - 1] = '\0';
        ps->count = 0;
        ps->total_salary = 0;
        return ps;
    }
    return NULL;
}

static const char *format_size(char *buf, size_t buflen, unsigned long long bytes) {
    double b = (double)bytes;
    if (b >= 1073741824.0)
        snprintf(buf, buflen, "%.2f GB", b / 1073741824.0);
    else if (b >= 1048576.0)
        snprintf(buf, buflen, "%.2f MB", b / 1048576.0);
    else if (b >= 1024.0)
        snprintf(buf, buflen, "%.2f KB", b / 1024.0);
    else
        snprintf(buf, buflen, "%llu B", bytes);
    return buf;
}

static double get_time_ns(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec * 1e9 + (double)ts.tv_nsec;
}

static void print_progress(unsigned long long bytes_read, unsigned long long total_bytes,
                           unsigned long long rows, double start_ns) {
    double now = get_time_ns();
    double elapsed = (now - start_ns) / 1e9;
    unsigned long long rows_per_sec = elapsed > 0 ? (unsigned long long)((double)rows / elapsed) : 0;
    double mb_per_sec = elapsed > 0 ? (double)bytes_read / 1048576.0 / elapsed : 0;
    double percent = total_bytes > 0 ? (double)bytes_read / (double)total_bytes * 100.0 : 0;

    int bar_width = 30;
    int filled = total_bytes > 0 ? (int)((double)bar_width * (double)bytes_read / (double)total_bytes) : 0;
    if (filled > bar_width) filled = bar_width;

    char bar[91 + 1]; /* 30 * 3 bytes per UTF-8 char + 1 */
    int pos = 0;
    for (int i = 0; i < bar_width; i++) {
        if (i < filled) {
            bar[pos++] = '\xe2'; bar[pos++] = '\x96'; bar[pos++] = '\x88';
        } else {
            bar[pos++] = '\xe2'; bar[pos++] = '\x96'; bar[pos++] = '\x91';
        }
    }
    bar[pos] = '\0';

    printf("\r[%s] %.2f%% | %llu rows | %llu rows/sec | %.2f MB/s    ",
           bar, percent, rows, rows_per_sec, mb_per_sec);
    fflush(stdout);
}

int main(void) {
    const char *csv_path = CSV_PATH;

    /* Print header */
    printf("==================================================\n");
    printf("Cross-Language Benchmark\n");
    printf("Language : C\n");
    printf("==================================================\n\n");
    printf("Input File : %s\n\n", csv_path);

    /* Open file */
    FILE *fp = fopen(csv_path, "r");
    if (!fp) {
        fprintf(stderr, "Error:\nUnable to open %s\n", csv_path);
        return 1;
    }

    /* Get file size */
    struct stat st;
    if (fstat(fileno(fp), &st) != 0) {
        fprintf(stderr, "Error:\nUnable to stat %s\n", csv_path);
        fclose(fp);
        return 1;
    }
    unsigned long long csv_size_bytes = (unsigned long long)st.st_size;

    /* Start timing */
    double start_ns = get_time_ns();

    /* Processing state */
    unsigned long long rows_processed = 0;
    unsigned long long invalid_rows = 0;
    unsigned long long bytes_read = 0;

    double total_salary = 0;
    double min_salary = 1e308;
    double max_salary = -1e308;
    long total_age = 0;

    /* Streaming read */
    static char buf[8 * 1024 * 1024];
    char leftover[4096];
    int leftover_len = 0;
    int header_skipped = 0;
    double last_progress_ns = start_ns;

    while (1) {
        size_t n = fread(buf, 1, sizeof(buf), fp);
        if (n == 0) {
            /* Process remaining leftover */
            if (leftover_len > 0) {
                /* Trim \r\n */
                while (leftover_len > 0 && (leftover[leftover_len - 1] == '\r' || leftover[leftover_len - 1] == '\n'))
                    leftover_len--;
                leftover[leftover_len] = '\0';

                if (leftover_len > 0 && header_skipped) {
                    /* Process this line (same as below) */
                    char *line = leftover;
                    char *fields[7];
                    int fc = 0;
                    char *p = line;
                    while (fc < 7) {
                        char *comma = strchr(p, ',');
                        if (comma && fc < 6) {
                            *comma = '\0';
                            fields[fc++] = p;
                            p = comma + 1;
                        } else {
                            fields[fc++] = p;
                            break;
                        }
                    }
                    if (fc >= 7) {
                        /* Trim \r from salary */
                        char *sal = fields[6];
                        size_t sl = strlen(sal);
                        while (sl > 0 && sal[sl - 1] == '\r') sal[--sl] = '\0';

                        if (strlen(fields[0]) == 0 || strchr(fields[2], '@') == NULL) {
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
                                    User user = { fields[0], fields[1], fields[2], fields[3],
                                                  (int)age, fields[5], salary };
                                    (void)user;
                                    total_salary += salary;
                                    if (salary < min_salary) min_salary = salary;
                                    if (salary > max_salary) max_salary = salary;
                                    total_age += age;
                                    CountryStats *cs = find_or_add_country(fields[3]);
                                    if (cs) { cs->count++; cs->total_salary += salary; cs->total_age += age; }
                                    ProfessionStats *ps = find_or_add_profession(fields[5]);
                                    if (ps) { ps->count++; ps->total_salary += salary; }
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

        /* Process lines from leftover + chunk */
        int start = 0;
        for (size_t i = 0; i < n; i++) {
            if (buf[i] == '\n') {
                int seg_len = (int)(i - start);

                char line_buf[4096];
                int line_len = 0;

                if (leftover_len > 0) {
                    memcpy(line_buf, leftover, leftover_len);
                    line_len = leftover_len;
                    leftover_len = 0;
                }
                int copy = seg_len;
                if (line_len + copy > (int)sizeof(line_buf) - 1)
                    copy = (int)sizeof(line_buf) - 1 - line_len;
                if (copy > 0) {
                    memcpy(line_buf + line_len, buf + start, copy);
                    line_len += copy;
                }
                /* Trim \r */
                while (line_len > 0 && line_buf[line_len - 1] == '\r')
                    line_len--;
                line_buf[line_len] = '\0';

                start = (int)i + 1;

                if (!header_skipped) {
                    header_skipped = 1;
                    continue;
                }
                if (line_len == 0) continue;

                /* Parse fields */
                char *fields[7];
                int fc = 0;
                char *p = line_buf;
                while (fc < 7) {
                    char *comma = strchr(p, ',');
                    if (comma && fc < 6) {
                        *comma = '\0';
                        fields[fc++] = p;
                        p = comma + 1;
                    } else {
                        fields[fc++] = p;
                        break;
                    }
                }

                if (fc < 7) {
                    invalid_rows++;
                    rows_processed++;
                    continue;
                }

                /* Validation */
                if (strlen(fields[0]) == 0 || strchr(fields[2], '@') == NULL) {
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

                /* Create user struct */
                User user = { fields[0], fields[1], fields[2], fields[3],
                              (int)age, fields[5], salary };
                (void)user;

                /* Statistics */
                total_salary += salary;
                if (salary < min_salary) min_salary = salary;
                if (salary > max_salary) max_salary = salary;
                total_age += age;

                /* Country grouping */
                CountryStats *cs = find_or_add_country(fields[3]);
                if (cs) {
                    cs->count++;
                    cs->total_salary += salary;
                    cs->total_age += age;
                }

                /* Profession grouping */
                ProfessionStats *ps = find_or_add_profession(fields[5]);
                if (ps) {
                    ps->count++;
                    ps->total_salary += salary;
                }

                rows_processed++;
            }
        }

        /* Save leftover */
        if (start < (int)n) {
            int remaining = (int)n - start;
            if (remaining > (int)sizeof(leftover) - 1)
                remaining = (int)sizeof(leftover) - 1;
            memcpy(leftover, buf + start, remaining);
            leftover_len = remaining;
        } else {
            leftover_len = 0;
        }

        /* Progress every 50ms */
        double now = get_time_ns();
        if (now - last_progress_ns >= 50000000.0) {
            print_progress(bytes_read, csv_size_bytes, rows_processed, start_ns);
            last_progress_ns = now;
        }
    }

    fclose(fp);

    /* Final progress */
    print_progress(csv_size_bytes, csv_size_bytes, rows_processed, start_ns);
    printf("\n\n");

    unsigned long long valid_rows = rows_processed - invalid_rows;
    double avg_salary = valid_rows > 0 ? total_salary / (double)valid_rows : 0;
    double avg_age = valid_rows > 0 ? (double)total_age / (double)valid_rows : 0;
    if (min_salary > 1e307) min_salary = 0;
    if (max_salary < -1e307) max_salary = 0;

    /* Find highest/lowest paid profession */
    const char *highest_prof = "";
    double highest_avg = -1e308;
    const char *lowest_prof = "";
    double lowest_avg = 1e308;

    for (int i = 0; i < profession_count; i++) {
        double avg = professions[i].total_salary / (double)professions[i].count;
        if (avg > highest_avg) { highest_avg = avg; highest_prof = professions[i].key; }
        if (avg < lowest_avg) { lowest_avg = avg; lowest_prof = professions[i].key; }
    }

    /* Build and write JSON */
    const char *output_path = "result.json";
    FILE *out = fopen(output_path, "w");
    if (!out) {
        fprintf(stderr, "Error:\nFailed to write %s\n", output_path);
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
    fprintf(out, "    \"highest_paid_profession\": \"%s\",\n", highest_prof);
    fprintf(out, "    \"lowest_paid_profession\": \"%s\"\n", lowest_prof);
    fprintf(out, "  },\n");

    fprintf(out, "  \"countries\": {\n");
    for (int i = 0; i < country_count; i++) {
        double ca = countries[i].total_salary / (double)countries[i].count;
        double aa = (double)countries[i].total_age / (double)countries[i].count;
        fprintf(out, "    \"%s\": {\n", countries[i].key);
        fprintf(out, "      \"total_users\": %d,\n", countries[i].count);
        fprintf(out, "      \"average_salary\": %.2f,\n", ca);
        fprintf(out, "      \"average_age\": %.2f\n", aa);
        fprintf(out, "    }%s\n", i < country_count - 1 ? "," : "");
    }
    fprintf(out, "  },\n");

    fprintf(out, "  \"professions\": {\n");
    for (int i = 0; i < profession_count; i++) {
        double pa = professions[i].total_salary / (double)professions[i].count;
        fprintf(out, "    \"%s\": {\n", professions[i].key);
        fprintf(out, "      \"count\": %d,\n", professions[i].count);
        fprintf(out, "      \"average_salary\": %.2f\n", pa);
        fprintf(out, "    }%s\n", i < profession_count - 1 ? "," : "");
    }
    fprintf(out, "  }\n");
    fprintf(out, "}\n");

    long json_size = ftell(out);
    fclose(out);
    unsigned long long json_size_bytes = (unsigned long long)json_size;

    double end_ns = get_time_ns();
    double elapsed = (end_ns - start_ns) / 1e9;
    unsigned long long rows_per_sec = elapsed > 0 ? (unsigned long long)((double)rows_processed / elapsed) : 0;

    /* Peak memory */
    struct rusage usage;
    getrusage(RUSAGE_SELF, &usage);
    unsigned long long peak_rss = (unsigned long long)usage.ru_maxrss;

    char sbuf1[64], sbuf2[64], sbuf3[64];

    printf("==================================================\n");
    printf("Benchmark Complete\n");
    printf("==================================================\n\n");
    printf("Language           : C\n\n");
    printf("Rows Processed     : %llu\n", rows_processed);
    printf("Invalid Rows       : %llu\n\n", invalid_rows);
    printf("CSV Size           : %s\n", format_size(sbuf1, sizeof(sbuf1), csv_size_bytes));
    printf("JSON Size          : %s\n\n", format_size(sbuf2, sizeof(sbuf2), json_size_bytes));
    printf("Execution Time     : %.3f seconds\n\n", elapsed);
    printf("Rows / Second      : %llu\n\n", rows_per_sec);
    printf("Peak Memory        : %s\n\n", format_size(sbuf3, sizeof(sbuf3), peak_rss));
    printf("Output File        : %s\n\n", output_path);
    printf("==================================================\n");

    return 0;
}
