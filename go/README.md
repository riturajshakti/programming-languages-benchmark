# Command

```sh
go build -o main main.go
./main
```

# Small File Output

```
==================================================
Cross-Language Benchmark
Language : Go
==================================================

Input File : ../users-small.csv

[██████████████████████████████] 100.00% | 5 rows | 16431 rows/sec | 0.95 MB/s    

==================================================
Benchmark Complete
==================================================

Language           : Go

Rows Processed     : 5
Invalid Rows       : 0

CSV Size           : 302 B
JSON Size          : 1.18 KB

Execution Time     : 0.001 seconds

Rows / Second      : 6736

Peak Memory        : 4.61 MB

Output File        : result.json

==================================================
```

# Large File Output

```
==================================================
Cross-Language Benchmark
Language : Go
==================================================

Input File : ../users-big.csv

[██████████████████████████████] 100.00% | 50000000 rows | 7470227 rows/sec | 355.50 MB/s    

==================================================
Benchmark Complete
==================================================

Language           : Go

Rows Processed     : 50000000
Invalid Rows       : 0

CSV Size           : 2.32 GB
JSON Size          : 2.16 KB

Execution Time     : 6.694 seconds

Rows / Second      : 7469788

Peak Memory        : 23.00 MB

Output File        : result.json

==================================================
```
