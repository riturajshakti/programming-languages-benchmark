import java.io.*;
import java.util.*;

public class Main {

    static final String CSV_PATH = "../users-big.csv";

    static class User {
        String id, name, email, country, profession;
        int age;
        double salary;

        User(String id, String name, String email, String country,
             int age, String profession, double salary) {
            this.id = id;
            this.name = name;
            this.email = email;
            this.country = country;
            this.age = age;
            this.profession = profession;
            this.salary = salary;
        }
    }

    static class CountryStats {
        int count;
        double totalSalary;
        long totalAge;
    }

    static class ProfessionStats {
        int count;
        double totalSalary;
    }

    static String formatSize(long bytes) {
        double b = (double) bytes;
        if (b >= 1_073_741_824) return String.format("%.2f GB", b / 1_073_741_824);
        if (b >= 1_048_576) return String.format("%.2f MB", b / 1_048_576);
        if (b >= 1024) return String.format("%.2f KB", b / 1024);
        return bytes + " B";
    }

    static void printProgress(long bytesRead, long totalBytes, long rows, long startNs) {
        long now = System.nanoTime();
        double elapsed = (now - startNs) / 1e9;
        long rowsPerSec = elapsed > 0 ? (long) (rows / elapsed) : 0;
        double mbPerSec = elapsed > 0 ? bytesRead / 1_048_576.0 / elapsed : 0;
        double percent = totalBytes > 0 ? (double) bytesRead / totalBytes * 100 : 0;

        int barWidth = 30;
        int filled = totalBytes > 0 ? (int) ((double) barWidth * bytesRead / totalBytes) : 0;
        if (filled > barWidth) filled = barWidth;

        StringBuilder bar = new StringBuilder();
        for (int i = 0; i < barWidth; i++) {
            bar.append(i < filled ? "\u2588" : "\u2591");
        }

        System.out.printf("\r[%s] %.2f%% | %d rows | %d rows/sec | %.2f MB/s    ",
                bar, percent, rows, rowsPerSec, mbPerSec);
        System.out.flush();
    }

    public static void main(String[] args) {
        String csvPath = CSV_PATH;

        System.out.println("==================================================");
        System.out.println("Cross-Language Benchmark");
        System.out.println("Language : Java");
        System.out.println("==================================================");
        System.out.println();
        System.out.println("Input File : " + csvPath);
        System.out.println();

        // Open file
        File file = new File(csvPath);
        if (!file.exists()) {
            System.err.println("Error:\nUnable to open " + csvPath);
            System.exit(1);
        }
        long csvSizeBytes = file.length();

        // Start timing
        long startNs = System.nanoTime();

        // Processing state
        long rowsProcessed = 0;
        long invalidRows = 0;
        long bytesRead = 0;

        double totalSalary = 0;
        double minSalary = Double.MAX_VALUE;
        double maxSalary = -Double.MAX_VALUE;
        long totalAge = 0;

        Map<String, CountryStats> countries = new HashMap<>();
        Map<String, ProfessionStats> professions = new HashMap<>();

        // Streaming read with 8MB buffer
        try (FileInputStream fis = new FileInputStream(file)) {
            byte[] buf = new byte[8 * 1024 * 1024];
            StringBuilder leftover = new StringBuilder();
            boolean headerSkipped = false;
            long lastProgressNs = startNs;

            while (true) {
                int n = fis.read(buf);
                if (n <= 0) {
                    // Process remaining leftover
                    if (leftover.length() > 0 && headerSkipped) {
                        String line = leftover.toString();
                        if (line.endsWith("\r")) line = line.substring(0, line.length() - 1);
                        if (line.endsWith("\n")) line = line.substring(0, line.length() - 1);
                        if (!line.isEmpty()) {
                            String[] fields = splitLine(line);
                            if (fields != null && fields.length >= 7) {
                                String id = fields[0];
                                String email = fields[2];
                                if (!id.isEmpty() && email.contains("@")) {
                                    try {
                                        int age = Integer.parseInt(fields[4]);
                                        double salary = Double.parseDouble(fields[6]);
                                        totalSalary += salary;
                                        if (salary < minSalary) minSalary = salary;
                                        if (salary > maxSalary) maxSalary = salary;
                                        totalAge += age;
                                        CountryStats cs = countries.computeIfAbsent(fields[3], k -> new CountryStats());
                                        cs.count++; cs.totalSalary += salary; cs.totalAge += age;
                                        ProfessionStats ps = professions.computeIfAbsent(fields[5], k -> new ProfessionStats());
                                        ps.count++; ps.totalSalary += salary;
                                    } catch (NumberFormatException e) { invalidRows++; }
                                } else { invalidRows++; }
                            } else { invalidRows++; }
                            rowsProcessed++;
                        }
                    }
                    break;
                }

                bytesRead += n;
                String chunk = new String(buf, 0, n, java.nio.charset.StandardCharsets.UTF_8);

                String data;
                if (leftover.length() > 0) {
                    leftover.append(chunk);
                    data = leftover.toString();
                    leftover.setLength(0);
                } else {
                    data = chunk;
                }

                int lineStart = 0;
                for (int i = 0; i < data.length(); i++) {
                    if (data.charAt(i) == '\n') {
                        String line = data.substring(lineStart, i);
                        if (line.endsWith("\r")) {
                            line = line.substring(0, line.length() - 1);
                        }
                        lineStart = i + 1;

                        if (!headerSkipped) {
                            headerSkipped = true;
                            continue;
                        }
                        if (line.isEmpty()) continue;

                        // Parse fields manually
                        String[] fields = splitLine(line);
                        if (fields == null || fields.length < 7) {
                            invalidRows++;
                            rowsProcessed++;
                            continue;
                        }

                        String id = fields[0];
                        String email = fields[2];
                        String country = fields[3];
                        String ageStr = fields[4];
                        String profession = fields[5];
                        String salaryStr = fields[6];

                        // Validation
                        if (id.isEmpty() || !email.contains("@")) {
                            invalidRows++;
                            rowsProcessed++;
                            continue;
                        }

                        int age;
                        try {
                            age = Integer.parseInt(ageStr);
                        } catch (NumberFormatException e) {
                            invalidRows++;
                            rowsProcessed++;
                            continue;
                        }

                        double salary;
                        try {
                            salary = Double.parseDouble(salaryStr);
                        } catch (NumberFormatException e) {
                            invalidRows++;
                            rowsProcessed++;
                            continue;
                        }

                        // Create user object
                        User user = new User(id, fields[1], email, country, age, profession, salary);

                        // Statistics
                        totalSalary += salary;
                        if (salary < minSalary) minSalary = salary;
                        if (salary > maxSalary) maxSalary = salary;
                        totalAge += age;

                        // Country grouping
                        CountryStats cs = countries.get(country);
                        if (cs == null) {
                            cs = new CountryStats();
                            countries.put(country, cs);
                        }
                        cs.count++;
                        cs.totalSalary += salary;
                        cs.totalAge += age;

                        // Profession grouping
                        ProfessionStats ps = professions.get(profession);
                        if (ps == null) {
                            ps = new ProfessionStats();
                            professions.put(profession, ps);
                        }
                        ps.count++;
                        ps.totalSalary += salary;

                        rowsProcessed++;
                    }
                }

                // Save leftover
                if (lineStart < data.length()) {
                    leftover.append(data, lineStart, data.length());
                }

                // Progress every 50ms
                long now = System.nanoTime();
                if (now - lastProgressNs >= 50_000_000L) {
                    printProgress(bytesRead, csvSizeBytes, rowsProcessed, startNs);
                    lastProgressNs = now;
                }
            }
        } catch (IOException e) {
            System.err.println("Error:\nFailed to read " + csvPath + ": " + e.getMessage());
            System.exit(1);
        }

        // Final progress
        printProgress(csvSizeBytes, csvSizeBytes, rowsProcessed, startNs);
        System.out.println("\n");

        long validRows = rowsProcessed - invalidRows;
        double avgSalary = validRows > 0 ? totalSalary / validRows : 0;
        double avgAge = validRows > 0 ? (double) totalAge / validRows : 0;
        if (minSalary == Double.MAX_VALUE) minSalary = 0;
        if (maxSalary == -Double.MAX_VALUE) maxSalary = 0;

        // Find highest/lowest paid profession
        String highestProf = "";
        double highestAvg = -Double.MAX_VALUE;
        String lowestProf = "";
        double lowestAvg = Double.MAX_VALUE;

        for (Map.Entry<String, ProfessionStats> entry : professions.entrySet()) {
            double avg = entry.getValue().totalSalary / entry.getValue().count;
            if (avg > highestAvg) { highestAvg = avg; highestProf = entry.getKey(); }
            if (avg < lowestAvg) { lowestAvg = avg; lowestProf = entry.getKey(); }
        }

        // Write JSON
        String outputPath = "result.json";
        try (PrintWriter pw = new PrintWriter(new BufferedWriter(new FileWriter(outputPath)))) {
            pw.println("{");
            pw.println("  \"summary\": {");
            pw.printf("    \"total_records\": %d,%n", rowsProcessed);
            pw.printf("    \"valid_records\": %d,%n", validRows);
            pw.printf("    \"invalid_records\": %d,%n", invalidRows);
            pw.printf("    \"average_salary\": %.2f,%n", avgSalary);
            pw.printf("    \"min_salary\": %.2f,%n", minSalary);
            pw.printf("    \"max_salary\": %.2f,%n", maxSalary);
            pw.printf("    \"average_age\": %.2f,%n", avgAge);
            pw.printf("    \"highest_paid_profession\": \"%s\",%n", highestProf);
            pw.printf("    \"lowest_paid_profession\": \"%s\"%n", lowestProf);
            pw.println("  },");

            pw.println("  \"countries\": {");
            int ci = 0;
            int countryTotal = countries.size();
            for (Map.Entry<String, CountryStats> entry : countries.entrySet()) {
                ci++;
                CountryStats cs = entry.getValue();
                double ca = cs.totalSalary / cs.count;
                double aa = (double) cs.totalAge / cs.count;
                pw.printf("    \"%s\": {%n", entry.getKey());
                pw.printf("      \"total_users\": %d,%n", cs.count);
                pw.printf("      \"average_salary\": %.2f,%n", ca);
                pw.printf("      \"average_age\": %.2f%n", aa);
                pw.println(ci < countryTotal ? "    }," : "    }");
            }
            pw.println("  },");

            pw.println("  \"professions\": {");
            int pi = 0;
            int profTotal = professions.size();
            for (Map.Entry<String, ProfessionStats> entry : professions.entrySet()) {
                pi++;
                ProfessionStats ps = entry.getValue();
                double pa = ps.totalSalary / ps.count;
                pw.printf("    \"%s\": {%n", entry.getKey());
                pw.printf("      \"count\": %d,%n", ps.count);
                pw.printf("      \"average_salary\": %.2f%n", pa);
                pw.println(pi < profTotal ? "    }," : "    }");
            }
            pw.println("  }");
            pw.println("}");
        } catch (IOException e) {
            System.err.println("Error:\nFailed to write " + outputPath + ": " + e.getMessage());
            System.exit(1);
        }

        long jsonSizeBytes = new File(outputPath).length();

        long endNs = System.nanoTime();
        double elapsed = (endNs - startNs) / 1e9;
        long rowsPerSec = elapsed > 0 ? (long) (rowsProcessed / elapsed) : 0;

        // Peak memory
        Runtime rt = Runtime.getRuntime();
        long peakMemory = rt.totalMemory() - rt.freeMemory();

        System.out.println("==================================================");
        System.out.println("Benchmark Complete");
        System.out.println("==================================================");
        System.out.println();
        System.out.println("Language           : Java");
        System.out.println();
        System.out.println("Rows Processed     : " + rowsProcessed);
        System.out.println("Invalid Rows       : " + invalidRows);
        System.out.println();
        System.out.println("CSV Size           : " + formatSize(csvSizeBytes));
        System.out.println("JSON Size          : " + formatSize(jsonSizeBytes));
        System.out.println();
        System.out.printf("Execution Time     : %.3f seconds%n", elapsed);
        System.out.println();
        System.out.println("Rows / Second      : " + rowsPerSec);
        System.out.println();
        System.out.println("Peak Memory        : " + formatSize(peakMemory));
        System.out.println();
        System.out.println("Output File        : " + outputPath);
        System.out.println();
        System.out.println("==================================================");
    }

    static String[] splitLine(String line) {
        String[] fields = new String[7];
        int start = 0;
        for (int f = 0; f < 6; f++) {
            int comma = line.indexOf(',', start);
            if (comma == -1) return null;
            fields[f] = line.substring(start, comma);
            start = comma + 1;
        }
        fields[6] = line.substring(start);
        return fields;
    }

}
