# Command

```sh
node main.js
```

# Small File Output

```
==================================================
Cross-Language Benchmark
Language : Node.js
==================================================

Input File : ../users-small.csv

[██████████████████████████████] 100.00% | 5 rows | 12899 rows/sec | 0.74 MB/s    

==================================================
Benchmark Complete
==================================================

Language           : Node.js

Rows Processed     : 5
Invalid Rows       : 0

CSV Size           : 302 B
JSON Size          : 1.18 KB

Execution Time     : 0.002 seconds

Rows / Second      : 3214

Peak Memory        : 42.80 MB

Output File        : result.json

==================================================
```

# Large File Output

```
==================================================
Cross-Language Benchmark
Language : Node.js
==================================================

Input File : ../users-big.csv

[██████████████████████████████] 100.00% | 50000000 rows | 4520293 rows/sec | 215.11 MB/s    

==================================================
Benchmark Complete
==================================================

Language           : Node.js

Rows Processed     : 50000000
Invalid Rows       : 0

CSV Size           : 2.32 GB
JSON Size          : 2.16 KB

Execution Time     : 11.064 seconds

Rows / Second      : 4519277

Peak Memory        : 832.23 MB

Output File        : result.json

==================================================
```
