# Command

```sh
php main.php
```

# Small File Output

```
==================================================
Cross-Language Benchmark
Language : PHP
==================================================

Input File : ../users-small.csv

[██████████████████████████████] 100.00% | 5 rows | 87977 rows/sec | 5.07 MB/s    

==================================================
Benchmark Complete
==================================================

Language           : PHP

Rows Processed     : 5
Invalid Rows       : 0

CSV Size           : 302 B
JSON Size          : 1.23 KB

Execution Time     : 0.000 seconds

Rows / Second      : 14485

Peak Memory        : 10.02 MB

Output File        : result.json

==================================================
```

# Large File Output

```
==================================================
Cross-Language Benchmark
Language : PHP
==================================================

Input File : ../users-big.csv

[██████████████████████████████] 100.00% | 50000000 rows | 1164918 rows/sec | 55.44 MB/s    

==================================================
Benchmark Complete
==================================================

Language           : PHP

Rows Processed     : 50000000
Invalid Rows       : 0

CSV Size           : 2.32 GB
JSON Size          : 2.26 KB

Execution Time     : 42.922 seconds

Rows / Second      : 1164908

Peak Memory        : 26.05 MB

Output File        : result.json

==================================================
```
