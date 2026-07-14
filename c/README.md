# Command

```sh
gcc -O3 -o main main.c -lm
./main
```

# Small File Output

```
==================================================
Cross-Language Benchmark
Language : C
==================================================

Input File : ../users-small.csv

[██████████████████████████████] 100.00% | 5 rows | 108695 rows/sec | 6.26 MB/s    

==================================================
Benchmark Complete
==================================================

Language           : C

Rows Processed     : 5
Invalid Rows       : 0

CSV Size           : 302 B
JSON Size          : 1.23 KB

Execution Time     : 0.001 seconds

Rows / Second      : 9057

Peak Memory        : 1.36 MB

Output File        : result.json

==================================================
```

# Large File Output

```
==================================================
Cross-Language Benchmark
Language : C
==================================================

Input File : ../users-big.csv

[██████████████████████████████] 100.00% | 50000000 rows | 9841613 rows/sec | 468.35 MB/s    

==================================================
Benchmark Complete
==================================================

Language           : C

Rows Processed     : 50000000
Invalid Rows       : 0

CSV Size           : 2.32 GB
JSON Size          : 2.26 KB

Execution Time     : 5.081 seconds

Rows / Second      : 9841161

Peak Memory        : 9.34 MB

Output File        : result.json

==================================================
```
