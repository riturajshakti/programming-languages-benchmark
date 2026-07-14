# Command

```sh
ocamlopt -O2 -I +unix unix.cmxa -o main main.ml
./main
```

# Small File Output

```
==================================================
Cross-Language Benchmark
Language : OCaml
==================================================

Input File : ../users-small.csv

[██████████████████████████████] 100.00% | 5 rows | 84918 rows/sec | 4.89 MB/s    

==================================================
Benchmark Complete
==================================================

Language           : OCaml

Rows Processed     : 5
Invalid Rows       : 0

CSV Size           : 302 B
JSON Size          : 1.23 KB

Execution Time     : 0.001 seconds

Rows / Second      : 9640

Peak Memory        : 8.41 MB

Output File        : result.json

==================================================
```

# Large File Output

```
==================================================
Cross-Language Benchmark
Language : OCaml
==================================================

Input File : ../users-big.csv

[██████████████████████████████] 100.00% | 50000000 rows | 4250171 rows/sec | 202.26 MB/s    

==================================================
Benchmark Complete
==================================================

Language           : OCaml

Rows Processed     : 50000000
Invalid Rows       : 0

CSV Size           : 2.32 GB
JSON Size          : 2.26 KB

Execution Time     : 11.765 seconds

Rows / Second      : 4250047

Peak Memory        : 17.51 MB

Output File        : result.json

==================================================
```
