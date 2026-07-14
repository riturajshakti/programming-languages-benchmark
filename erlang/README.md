# Command

```sh
erlc main.erl
erl -noshell -s main main
```

# Small File Output

```
==================================================
Cross-Language Benchmark
Language : Erlang
==================================================

Input File : ../users-small.csv

[██████████████████████████████] 100.00% | 5 rows | 510 rows/sec | 0.03 MB/s    

==================================================
Benchmark Complete
==================================================

Language           : Erlang

Rows Processed     : 5
Invalid Rows       : 0

CSV Size           : 302 B
JSON Size          : 1.23 KB

Execution Time     : 0.011 seconds

Rows / Second      : 474

Peak Memory        : 32.73 MB

Output File        : result.json

==================================================
```

# Large File Output

```
==================================================
Cross-Language Benchmark
Language : Erlang
==================================================

Input File : ../users-big.csv

[██████████████████████████████] 100.00% | 50000000 rows | 695441 rows/sec | 33.10 MB/s    

==================================================
Benchmark Complete
==================================================

Language           : Erlang

Rows Processed     : 50000000
Invalid Rows       : 0

CSV Size           : 2.32 GB
JSON Size          : 2.26 KB

Execution Time     : 71.898 seconds

Rows / Second      : 695429

Peak Memory        : 48.26 MB

Output File        : result.json

==================================================
```
