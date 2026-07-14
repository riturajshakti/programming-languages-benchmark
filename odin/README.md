# Command

```sh
odin build . -o:speed -out:main
./main
```

# Small File Output

```
==================================================
Cross-Language Benchmark
Language : Odin
==================================================

Input File : ../users-small.csv

[██████████████████████████████] 100.00% | 5 rows | 142857 rows/sec | 8.23 MB/s    

==================================================
Benchmark Complete
==================================================

Language           : Odin

Rows Processed     : 5
Invalid Rows       : 0

CSV Size           : 302 B
JSON Size          : 1.23 KB

Execution Time     : 0.001 seconds

Rows / Second      : 8872

Peak Memory        : 1.52 MB

Output File        : result.json

==================================================
```

# Large File Output

```
==================================================
Cross-Language Benchmark
Language : Odin
==================================================

Input File : ../users-big.csv

[██████████████████████████████] 100.00% | 50000000 rows | 8603731 rows/sec | 409.44 MB/s    

==================================================
Benchmark Complete
==================================================

Language           : Odin

Rows Processed     : 50000000
Invalid Rows       : 0

CSV Size           : 2.32 GB
JSON Size          : 2.26 KB

Execution Time     : 5.812 seconds

Rows / Second      : 8603156

Peak Memory        : 9.55 MB

Output File        : result.json

==================================================
```
