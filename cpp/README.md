# Command

```sh
g++ -O3 -std=c++17 -o main main.cpp
./main
```

# Small File Output

```
==================================================
Cross-Language Benchmark
Language : C++
==================================================

Input File : ../users-small.csv

[██████████████████████████████] 100.00% | 5 rows | 16722 rows/sec | 0.96 MB/s    

==================================================
Benchmark Complete
==================================================

Language           : C++

Rows Processed     : 5
Invalid Rows       : 0

CSV Size           : 302 B
JSON Size          : 1.23 KB

Execution Time     : 0.001 seconds

Rows / Second      : 8460

Peak Memory        : 1.33 MB

Output File        : result.json

==================================================
```

# Large File Output

```
==================================================
Cross-Language Benchmark
Language : C++
==================================================

Input File : ../users-big.csv

[██████████████████████████████] 100.00% | 50000000 rows | 8121134 rows/sec | 386.47 MB/s    

==================================================
Benchmark Complete
==================================================

Language           : C++

Rows Processed     : 50000000
Invalid Rows       : 0

CSV Size           : 2.32 GB
JSON Size          : 2.26 KB

Execution Time     : 6.157 seconds

Rows / Second      : 8120830

Peak Memory        : 9.41 MB

Output File        : result.json

==================================================
```
