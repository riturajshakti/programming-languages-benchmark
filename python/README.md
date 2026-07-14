# Command

```sh
python3 main.py
```

# Small File Output

```
==================================================
Cross-Language Benchmark
Language : Python
==================================================

Input File : ../users-small.csv

[██████████████████████████████] 100.00% | 5 rows | 20127 rows/sec | 1.16 MB/s    

==================================================
Benchmark Complete
==================================================

Language           : Python

Rows Processed     : 5
Invalid Rows       : 0

CSV Size           : 302 B
JSON Size          : 1.21 KB

Execution Time     : 0.001 seconds

Rows / Second      : 8615

Peak Memory        : 15.59 MB

Output File        : result.json

==================================================
```

# Large File Output

```
==================================================
Cross-Language Benchmark
Language : Python
==================================================

Input File : ../users-big.csv

[██████████████████████████████] 100.00% | 50000000 rows | 836457 rows/sec | 39.81 MB/s    

==================================================
Benchmark Complete
==================================================

Language           : Python

Rows Processed     : 50000000
Invalid Rows       : 0

CSV Size           : 2.32 GB
JSON Size          : 2.22 KB

Execution Time     : 59.776 seconds

Rows / Second      : 836452

Peak Memory        : 48.02 MB

Output File        : result.json

==================================================
```
