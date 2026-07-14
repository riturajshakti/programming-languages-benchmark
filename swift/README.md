# Command

```sh
swiftc -O -o main main.swift
./main
```

# Small File Output

```
==================================================
Cross-Language Benchmark
Language : Swift
==================================================

Input File : ../users-small.csv

[██████████████████████████████] 100.00% | 5 rows | 5502 rows/sec | 0.32 MB/s    

==================================================
Benchmark Complete
==================================================

Language           : Swift

Rows Processed     : 5
Invalid Rows       : 0

CSV Size           : 302 B
JSON Size          : 1.23 KB

Execution Time     : 0.001 seconds

Rows / Second      : 4058

Peak Memory        : 5.98 MB

Output File        : result.json

==================================================
```

# Large File Output

```
==================================================
Cross-Language Benchmark
Language : Swift
==================================================

Input File : ../users-big.csv

[██████████████████████████████] 100.00% | 50000000 rows | 587655 rows/sec | 27.97 MB/s    

==================================================
Benchmark Complete
==================================================

Language           : Swift

Rows Processed     : 50000000
Invalid Rows       : 0

CSV Size           : 2.32 GB
JSON Size          : 2.26 KB

Execution Time     : 85.084 seconds

Rows / Second      : 587653

Peak Memory        : 22.20 MB

Output File        : result.json

==================================================
```
