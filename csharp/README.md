# Command

```sh
dotnet build -c Release
dotnet run -c Release
```

# Small File Output

```
==================================================
Cross-Language Benchmark
Language : C#
==================================================

Input File : ../users-small.csv

[██████████████████████████████] 100.00% | 5 rows | 1222 rows/sec | 0.07 MB/s    

==================================================
Benchmark Complete
==================================================

Language           : C#

Rows Processed     : 5
Invalid Rows       : 0

CSV Size           : 302 B
JSON Size          : 1.23 KB

Execution Time     : 0.005 seconds

Rows / Second      : 1020

Peak Memory        : 41.02 MB

Output File        : result.json

==================================================
```

# Large File Output

```
==================================================
Cross-Language Benchmark
Language : C#
==================================================

Input File : ../users-big.csv

[██████████████████████████████] 100.00% | 50000000 rows | 7137475 rows/sec | 339.66 MB/s    

==================================================
Benchmark Complete
==================================================

Language           : C#

Rows Processed     : 50000000
Invalid Rows       : 0

CSV Size           : 2.32 GB
JSON Size          : 2.26 KB

Execution Time     : 7.006 seconds

Rows / Second      : 7136962

Peak Memory        : 164.94 MB

Output File        : result.json

==================================================
```
