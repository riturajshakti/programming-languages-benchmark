# Command

```sh
nim c -d:release -o:main main.nim
./main
```

# Small File Output

```
==================================================
Cross-Language Benchmark
Language : Nim
==================================================

Input File : ../users-small.csv

[██████████████████████████████] 100.00% | 5 rows | 3176 rows/sec | 0.18 MB/s    

==================================================
Benchmark Complete
==================================================

Language           : Nim

Rows Processed     : 5
Invalid Rows       : 0

CSV Size           : 302 B
JSON Size          : 1.23 KB

Execution Time     : 0.002 seconds

Rows / Second      : 2429

Peak Memory        : 9.47 MB

Output File        : result.json

==================================================
```

# Large File Output

```
==================================================
Cross-Language Benchmark
Language : Nim
==================================================

Input File : ../users-big.csv

[██████████████████████████████] 100.00% | 50000000 rows | 3360546 rows/sec | 159.92 MB/s    

==================================================
Benchmark Complete
==================================================

Language           : Nim

Rows Processed     : 50000000
Invalid Rows       : 0

CSV Size           : 2.32 GB
JSON Size          : 2.26 KB

Execution Time     : 14.879 seconds

Rows / Second      : 3360496

Peak Memory        : 25.50 MB

Output File        : result.json

==================================================
```
