# Command

```sh
dart compile exe main.dart -o main
./main
```

# Small File Output

```
==================================================
Cross-Language Benchmark
Language : Dart
==================================================

Input File : ../users-small.csv

[██████████████████████████████] 100.00% | 5 rows | 55555 rows/sec | 3.20 MB/s    

==================================================
Benchmark Complete
==================================================

Language           : Dart

Rows Processed     : 5
Invalid Rows       : 0

CSV Size           : 302 B
JSON Size          : 1.21 KB

Execution Time     : 0.000 seconds

Rows / Second      : 12853

Peak Memory        : 13.83 MB

Output File        : result.json

==================================================
```

# Large File Output

```
==================================================
Cross-Language Benchmark
Language : Dart
==================================================

Input File : ../users-big.csv

[██████████████████████████████] 100.00% | 50000000 rows | 3769918 rows/sec | 179.41 MB/s    

==================================================
Benchmark Complete
==================================================

Language           : Dart

Rows Processed     : 50000000
Invalid Rows       : 0

CSV Size           : 2.32 GB
JSON Size          : 2.22 KB

Execution Time     : 13.263 seconds

Rows / Second      : 3769813

Peak Memory        : 17.33 MB

Output File        : result.json

==================================================
```
