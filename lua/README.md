# Command

```sh
luajit main.lua
```

# Small File Output

```
==================================================
Cross-Language Benchmark
Language : LuaJIT
==================================================

Input File : ../users-small.csv

[██████████████████████████████] 100.00% | 5 rows | 4496 rows/sec | 0.26 MB/s    

==================================================
Benchmark Complete
==================================================

Language           : LuaJIT

Rows Processed     : 5
Invalid Rows       : 0

CSV Size           : 302 B
JSON Size          : 1.23 KB

Execution Time     : 0.001 seconds

Rows / Second      : 3633

Peak Memory        : 4.05 MB

Output File        : result.json

==================================================
```

# Large File Output

```
==================================================
Cross-Language Benchmark
Language : LuaJIT
==================================================

Input File : ../users-big.csv

[██████████████████████████████] 100.00% | 50000000 rows | 3494346 rows/sec | 166.29 MB/s    

==================================================
Benchmark Complete
==================================================

Language           : LuaJIT

Rows Processed     : 50000000
Invalid Rows       : 0

CSV Size           : 2.32 GB
JSON Size          : 2.26 KB

Execution Time     : 14.310 seconds

Rows / Second      : 3494161

Peak Memory        : 2.08 MB

Output File        : result.json

==================================================
```
