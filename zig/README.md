# Command

```sh
zig build-exe main.zig -OReleaseFast
./main
```

# Small File Output

```
==================================================
Cross-Language Benchmark
Language : Zig
==================================================

Input File : ../users-small.csv

[██████████████████████████████] 100.00% | 5 rows | 2866 rows/sec | 0.17 MB/s    

==================================================
Benchmark Complete
==================================================

Language           : Zig

Rows Processed     : 5
Invalid Rows       : 0

CSV Size           : 302 B
JSON Size          : 1.23 KB

Execution Time     : 0.002 seconds

Rows / Second      : 2397

Peak Memory        : 1.59 MB

Output File        : result.json

==================================================
```

# Large File Output

```
==================================================
Cross-Language Benchmark
Language : Zig
==================================================

Input File : ../users-big.csv

[██████████████████████████████] 100.00% | 50000000 rows | 15240155 rows/sec | 725.26 MB/s    

==================================================
Benchmark Complete
==================================================

Language           : Zig

Rows Processed     : 50000000
Invalid Rows       : 0

CSV Size           : 2.32 GB
JSON Size          : 2.26 KB

Execution Time     : 3.281 seconds

Rows / Second      : 15239358

Peak Memory        : 9.59 MB

Output File        : result.json

==================================================
```