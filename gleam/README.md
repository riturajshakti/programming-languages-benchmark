# Command

```sh
gleam run
```

# Small File Output

```
==================================================
Cross-Language Benchmark
Language : Gleam
==================================================

Input File : ../users-small.csv

[██████████████████████████████] 100.00% | 5 rows | 449 rows/sec | 0.03 MB/s    

==================================================
Benchmark Complete
==================================================

Language           : Gleam

Rows Processed     : 5
Invalid Rows       : 0

CSV Size           : 302 B
JSON Size          : 1.23 KB

Execution Time     : 0.011 seconds

Rows / Second      : 439

Peak Memory        : 32.71 MB

Output File        : result.json

==================================================
```

# Large File Output

```
==================================================
Cross-Language Benchmark
Language : Gleam
==================================================

Input File : ../users-big.csv

[██████████████████████████████] 100.00% | 50000000 rows | 128764 rows/sec | 6.13 MB/s    

==================================================
Benchmark Complete
==================================================

Language           : Gleam

Rows Processed     : 50000000
Invalid Rows       : 0

CSV Size           : 2.32 GB
JSON Size          : 2.26 KB

Execution Time     : 388.305 seconds

Rows / Second      : 128764

Peak Memory        : 47.85 MB

Output File        : result.json

==================================================
```
