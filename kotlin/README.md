# Command

```sh
kotlinc Main.kt -include-runtime -d Main.jar
java -jar Main.jar
```

# Small File Output

```
==================================================
Cross-Language Benchmark
Language : Kotlin
==================================================

Input File : ../users-small.csv

[██████████████████████████████] 100.00% | 5 rows | 599 rows/sec | 0.03 MB/s    

==================================================
Benchmark Complete
==================================================

Language           : Kotlin

Rows Processed     : 5
Invalid Rows       : 0

CSV Size           : 302 B
JSON Size          : 1.23 KB

Execution Time     : 0.036 seconds

Rows / Second      : 140

Peak Memory        : 17.46 MB

Output File        : result.json

==================================================
```

# Large File Output

```
==================================================
Cross-Language Benchmark
Language : Kotlin
==================================================

Input File : ../users-big.csv

[██████████████████████████████] 100.00% | 50000000 rows | 4136950 rows/sec | 196.87 MB/s    

==================================================
Benchmark Complete
==================================================

Language           : Kotlin

Rows Processed     : 50000000
Invalid Rows       : 0

CSV Size           : 2.32 GB
JSON Size          : 2.26 KB

Execution Time     : 12.091 seconds

Rows / Second      : 4135178

Peak Memory        : 293.79 MB

Output File        : result.json

==================================================
```
