# Command

```sh
javac Main.java
java Main
```

# Small File Output

```
==================================================
Cross-Language Benchmark
Language : Java
==================================================

Input File : ../users-small.csv

[██████████████████████████████] 100.00% | 5 rows | 1367 rows/sec | 0.08 MB/s    

==================================================
Benchmark Complete
==================================================

Language           : Java

Rows Processed     : 5
Invalid Rows       : 0

CSV Size           : 302 B
JSON Size          : 1.23 KB

Execution Time     : 0.019 seconds

Rows / Second      : 259

Peak Memory        : 15.20 MB

Output File        : result.json

==================================================
```

# Large File Output

```
==================================================
Cross-Language Benchmark
Language : Java
==================================================

Input File : ../users-big.csv

[██████████████████████████████] 100.00% | 50000000 rows | 5918456 rows/sec | 281.65 MB/s    

==================================================
Benchmark Complete
==================================================

Language           : Java

Rows Processed     : 50000000
Invalid Rows       : 0

CSV Size           : 2.32 GB
JSON Size          : 2.26 KB

Execution Time     : 8.450 seconds

Rows / Second      : 5917224

Peak Memory        : 215.60 MB

Output File        : result.json

==================================================
```
