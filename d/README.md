# Command

```sh
ldc2 -O3 -release -of=main main.d
./main
```

# Small File Output

```
==================================================
Cross-Language Benchmark
Language : D
==================================================

Input File : ../users-small.csv

[██████████████████████████████] 100.00% | 5 rows | 5124 rows/sec | 0.30 MB/s    

==================================================
Benchmark Complete
==================================================

Language           : D

Rows Processed     : 5
Invalid Rows       : 0

CSV Size           : 302 B
JSON Size          : 1.23 KB

Execution Time     : 0.001 seconds

Rows / Second      : 4191

Peak Memory        : 10.48 MB

Output File        : result.json

==================================================
```

# Large File Output

```
==================================================
Cross-Language Benchmark
Language : D
==================================================

Input File : ../users-big.csv

[██████████████████████████████] 100.00% | 50000000 rows | 9468674 rows/sec | 450.60 MB/s    

==================================================
Benchmark Complete
==================================================

Language           : D

Rows Processed     : 50000000
Invalid Rows       : 0

CSV Size           : 2.32 GB
JSON Size          : 4.13 KB

Execution Time     : 5.281 seconds

Rows / Second      : 9468188

Peak Memory        : 62.23 MB

Output File        : result.json

==================================================
```
