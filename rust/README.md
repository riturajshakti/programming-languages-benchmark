# Command

```sh
cargo build --release
./target/release/benchmark
```

# Small File Output

```
==================================================
Cross-Language Benchmark
Language : Rust
==================================================

Input File : ../users-small.csv

[██████████████████████████████] 100.00% | 5 rows | 6175 rows/sec | 0.36 MB/s    

==================================================
Benchmark Complete
==================================================

Language           : Rust

Rows Processed     : 5
Invalid Rows       : 0

CSV Size           : 302 B
JSON Size          : 1.23 KB

Execution Time     : 0.001 seconds

Rows / Second      : 4888

Peak Memory        : 1.61 MB

Output File        : result.json

==================================================
```

# Large File Output

```
==================================================
Cross-Language Benchmark
Language : Rust
==================================================

Input File : ../users-big.csv

[██████████████████████████████] 100.00% | 50000000 rows | 3168933 rows/sec | 150.81 MB/s    

==================================================
Benchmark Complete
==================================================

Language           : Rust

Rows Processed     : 50000000
Invalid Rows       : 0

CSV Size           : 2.32 GB
JSON Size          : 2.26 KB

Execution Time     : 15.778 seconds

Rows / Second      : 3168891

Peak Memory        : 9.83 MB

Output File        : result.json

==================================================
```
