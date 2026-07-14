import 'dart:io';
import 'dart:convert';

const String CSV_PATH = '../users-big.csv';

class User {
  final String id;
  final String name;
  final String email;
  final String country;
  final int age;
  final String profession;
  final double salary;

  User(this.id, this.name, this.email, this.country, this.age, this.profession,
      this.salary);
}

class CountryStats {
  int count = 0;
  double totalSalary = 0;
  int totalAge = 0;
}

class ProfessionStats {
  int count = 0;
  double totalSalary = 0;
}

String formatSize(int bytes) {
  final b = bytes.toDouble();
  if (b >= 1073741824) return '${(b / 1073741824).toStringAsFixed(2)} GB';
  if (b >= 1048576) return '${(b / 1048576).toStringAsFixed(2)} MB';
  if (b >= 1024) return '${(b / 1024).toStringAsFixed(2)} KB';
  return '$bytes B';
}

void printProgress(
    int bytesRead, int totalBytes, int rows, Stopwatch stopwatch) {
  final elapsed = stopwatch.elapsedMicroseconds / 1e6;
  final rowsPerSec = elapsed > 0 ? (rows / elapsed).floor() : 0;
  final mbPerSec = elapsed > 0 ? bytesRead / 1048576 / elapsed : 0.0;
  final percent = totalBytes > 0 ? bytesRead / totalBytes * 100 : 0.0;

  const barWidth = 30;
  var filled = totalBytes > 0
      ? (barWidth * bytesRead / totalBytes).floor()
      : 0;
  if (filled > barWidth) filled = barWidth;

  final bar = '\u2588' * filled + '\u2591' * (barWidth - filled);
  stdout.write(
      '\r[$bar] ${percent.toStringAsFixed(2)}% | $rows rows | $rowsPerSec rows/sec | ${mbPerSec.toStringAsFixed(2)} MB/s    ');
}

void processLine(
    String line,
    List<int> counters, // [rowsProcessed, invalidRows]
    List<double> salaryStats, // [totalSalary, minSalary, maxSalary]
    List<int> ageStats, // [totalAge]
    Map<String, CountryStats> countries,
    Map<String, ProfessionStats> professions) {
  // Split into 7 fields
  final parts = <String>[];
  var start = 0;
  for (var f = 0; f < 6; f++) {
    final comma = line.indexOf(',', start);
    if (comma == -1) {
      counters[1]++;
      counters[0]++;
      return;
    }
    parts.add(line.substring(start, comma));
    start = comma + 1;
  }
  parts.add(line.substring(start));

  if (parts.length < 7) {
    counters[1]++;
    counters[0]++;
    return;
  }

  final id = parts[0];
  final name = parts[1];
  final email = parts[2];
  final country = parts[3];
  final ageStr = parts[4];
  final profession = parts[5];
  var salaryStr = parts[6];
  if (salaryStr.endsWith('\r')) {
    salaryStr = salaryStr.substring(0, salaryStr.length - 1);
  }

  // Validation
  if (id.isEmpty || !email.contains('@')) {
    counters[1]++;
    counters[0]++;
    return;
  }

  final age = int.tryParse(ageStr);
  if (age == null) {
    counters[1]++;
    counters[0]++;
    return;
  }

  final salary = double.tryParse(salaryStr);
  if (salary == null) {
    counters[1]++;
    counters[0]++;
    return;
  }

  // Create user object
  final user = User(id, name, email, country, age, profession, salary);
  user.hashCode; // prevent optimization removal

  // Statistics
  salaryStats[0] += salary;
  if (salary < salaryStats[1]) salaryStats[1] = salary;
  if (salary > salaryStats[2]) salaryStats[2] = salary;
  ageStats[0] += age;

  // Country grouping
  final cs = countries.putIfAbsent(country, () => CountryStats());
  cs.count++;
  cs.totalSalary += salary;
  cs.totalAge += age;

  // Profession grouping
  final ps = professions.putIfAbsent(profession, () => ProfessionStats());
  ps.count++;
  ps.totalSalary += salary;

  counters[0]++;
}

void main() {
  final csvPath = CSV_PATH;

  print('==================================================');
  print('Cross-Language Benchmark');
  print('Language : Dart');
  print('==================================================');
  print('');
  print('Input File : $csvPath');
  print('');

  // Open file
  final file = File(csvPath);
  if (!file.existsSync()) {
    stderr.writeln('Error:\nUnable to open $csvPath');
    exit(1);
  }
  final csvSizeBytes = file.lengthSync();

  // Start timing
  final stopwatch = Stopwatch()..start();

  // Processing state
  final counters = [0, 0]; // [rowsProcessed, invalidRows]
  final salaryStats = [0.0, double.maxFinite, -double.maxFinite]; // [total, min, max]
  final ageStats = [0]; // [totalAge]

  final countries = <String, CountryStats>{};
  final professions = <String, ProfessionStats>{};

  // Streaming read with 8MB buffer
  final raf = file.openSync();
  const bufSize = 8 * 1024 * 1024;
  var headerSkipped = false;
  var leftover = '';
  var bytesRead = 0;
  var lastProgressUs = stopwatch.elapsedMicroseconds;

  try {
    while (true) {
      final buf = raf.readSync(bufSize);
      if (buf.isEmpty) {
        // Process remaining leftover
        if (leftover.isNotEmpty && headerSkipped) {
          var line = leftover;
          while (line.endsWith('\r') || line.endsWith('\n')) {
            line = line.substring(0, line.length - 1);
          }
          if (line.isNotEmpty) {
            processLine(
                line, counters, salaryStats, ageStats, countries, professions);
          }
        }
        break;
      }

      bytesRead += buf.length;
      final chunk = utf8.decode(buf, allowMalformed: true);

      String data;
      if (leftover.isNotEmpty) {
        data = leftover + chunk;
        leftover = '';
      } else {
        data = chunk;
      }

      var lineStart = 0;
      for (var i = 0; i < data.length; i++) {
        if (data.codeUnitAt(i) == 10) {
          // \n
          var lineEnd = i;
          if (lineEnd > lineStart && data.codeUnitAt(lineEnd - 1) == 13) {
            lineEnd--;
          }
          final line = data.substring(lineStart, lineEnd);
          lineStart = i + 1;

          if (!headerSkipped) {
            headerSkipped = true;
            continue;
          }
          if (line.isEmpty) continue;

          processLine(
              line, counters, salaryStats, ageStats, countries, professions);
        }
      }

      if (lineStart < data.length) {
        leftover = data.substring(lineStart);
      }

      // Progress every 50ms
      final nowUs = stopwatch.elapsedMicroseconds;
      if (nowUs - lastProgressUs >= 50000) {
        printProgress(bytesRead, csvSizeBytes, counters[0], stopwatch);
        lastProgressUs = nowUs;
      }
    }
  } finally {
    raf.closeSync();
  }

  // Final progress
  printProgress(csvSizeBytes, csvSizeBytes, counters[0], stopwatch);
  stdout.writeln('\n');

  final rowsProcessed = counters[0];
  final invalidRows = counters[1];
  final validRows = rowsProcessed - invalidRows;
  var totalSalary = salaryStats[0];
  var minSalary = salaryStats[1];
  var maxSalary = salaryStats[2];
  final totalAge = ageStats[0];

  final avgSalary = validRows > 0 ? totalSalary / validRows : 0.0;
  final avgAge = validRows > 0 ? totalAge / validRows : 0.0;
  if (minSalary == double.maxFinite) minSalary = 0;
  if (maxSalary == -double.maxFinite) maxSalary = 0;

  // Find highest/lowest paid profession
  var highestProf = '';
  var highestAvg = -double.maxFinite;
  var lowestProf = '';
  var lowestAvg = double.maxFinite;

  for (final entry in professions.entries) {
    final avg = entry.value.totalSalary / entry.value.count;
    if (avg > highestAvg) {
      highestAvg = avg;
      highestProf = entry.key;
    }
    if (avg < lowestAvg) {
      lowestAvg = avg;
      lowestProf = entry.key;
    }
  }

  // Build JSON
  final output = <String, dynamic>{
    'summary': {
      'total_records': rowsProcessed,
      'valid_records': validRows,
      'invalid_records': invalidRows,
      'average_salary': double.parse(avgSalary.toStringAsFixed(2)),
      'min_salary': minSalary,
      'max_salary': maxSalary,
      'average_age': double.parse(avgAge.toStringAsFixed(2)),
      'highest_paid_profession': highestProf,
      'lowest_paid_profession': lowestProf,
    },
    'countries': {
      for (final entry in countries.entries)
        entry.key: {
          'total_users': entry.value.count,
          'average_salary': double.parse(
              (entry.value.totalSalary / entry.value.count)
                  .toStringAsFixed(2)),
          'average_age': double.parse(
              (entry.value.totalAge / entry.value.count).toStringAsFixed(2)),
        },
    },
    'professions': {
      for (final entry in professions.entries)
        entry.key: {
          'count': entry.value.count,
          'average_salary': double.parse(
              (entry.value.totalSalary / entry.value.count)
                  .toStringAsFixed(2)),
        },
    },
  };

  final jsonStr = const JsonEncoder.withIndent('  ').convert(output) + '\n';

  // Write JSON
  const outputPath = 'result.json';
  File(outputPath).writeAsStringSync(jsonStr);

  stopwatch.stop();
  final elapsed = stopwatch.elapsedMicroseconds / 1e6;
  final jsonSizeBytes = utf8.encode(jsonStr).length;
  final rowsPerSec = elapsed > 0 ? (rowsProcessed / elapsed).floor() : 0;

  // Peak memory
  final peakRss = ProcessInfo.currentRss;

  print('==================================================');
  print('Benchmark Complete');
  print('==================================================');
  print('');
  print('Language           : Dart');
  print('');
  print('Rows Processed     : $rowsProcessed');
  print('Invalid Rows       : $invalidRows');
  print('');
  print('CSV Size           : ${formatSize(csvSizeBytes)}');
  print('JSON Size          : ${formatSize(jsonSizeBytes)}');
  print('');
  print('Execution Time     : ${elapsed.toStringAsFixed(3)} seconds');
  print('');
  print('Rows / Second      : $rowsPerSec');
  print('');
  print('Peak Memory        : ${formatSize(peakRss)}');
  print('');
  print('Output File        : $outputPath');
  print('');
  print('==================================================');
}
