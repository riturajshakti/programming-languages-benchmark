# Cross-Language Performance Benchmark

A benchmark comparing **20 programming languages** processing the same CSV workload: parsing, validation, struct creation, grouping, statistics, and JSON serialization — all using **streaming/chunked I/O**.

---

## Large File Results (50M rows, 2.32 GB)

### Speed — Rows per Second

```
Zig          ████████████████████████████████████████████████████  15,239,358
C            ██████████████████████████████████                     9,841,161
D            █████████████████████████████████                      9,468,188
Odin         ████████████████████████████                           8,603,156
C++          ███████████████████████████                            8,120,830
Go           ████████████████████████                               7,469,788
C#           ███████████████████████                                7,136,962
Java         ███████████████████                                    5,917,224
Node.js      ██████████████                                        4,519,277
OCaml        █████████████                                         4,250,047
Kotlin       █████████████                                         4,135,178
Dart         ████████████                                          3,769,813
LuaJIT       ███████████                                           3,494,161
Nim          ███████████                                           3,360,496
Rust         ██████████                                            3,168,891
PHP          ███                                                   1,164,908
Python       ██                                                      836,452
Erlang       ██                                                      695,429
Swift        █                                                       587,653
Gleam        ▏                                                       128,764
```

### Execution Time (seconds) — Lower is Better

```
Zig          ███                                                     3.281
C            █████                                                   5.081
D            █████                                                   5.281
Odin         █████                                                   5.812
C++          ██████                                                  6.157
Go           ██████                                                  6.694
C#           ███████                                                 7.006
Java         ████████                                                8.450
Node.js      ███████████                                            11.064
OCaml        ███████████                                            11.765
Kotlin       ████████████                                           12.091
Dart         █████████████                                          13.263
LuaJIT       ██████████████                                         14.310
Nim          ██████████████                                         14.879
Rust         ███████████████                                        15.778
PHP          ██████████████████████████████████████████              42.922
Python       ██████████████████████████████████████████████████████  59.776
Erlang       ██████████████████████████████████████████████████████  71.898
Swift        ██████████████████████████████████████████████████████  85.084
Gleam        ██████████████████████████████████████████████████████ 388.305
```

### Peak Memory (MB) — Lower is Better

```
LuaJIT       ▏                                                       2.08
C            █                                                       9.34
C++          █                                                       9.41
Odin         █                                                       9.55
Zig          █                                                       9.59
Rust         █                                                       9.83
Dart         ██                                                     17.33
OCaml        ██                                                     17.51
Swift        ██                                                     22.20
Go           ██                                                     23.00
Nim          ███                                                    25.50
PHP          ███                                                    26.05
Gleam        █████                                                  47.85
Python       █████                                                  48.02
Erlang       █████                                                  48.26
D            ██████                                                 62.23
C#           █████████████████                                     164.94
Java         ██████████████████████                                215.60
Kotlin       ██████████████████████████████                         293.79
Node.js      ██████████████████████████████████████████████████████ 832.23
```

---

### Speed vs Memory — Side by Side (sorted by speed)

```
              SPEED (rows/sec)                                    MEMORY (MB)
              ◄──────────────────────────────────►                ◄──────────────────────────────────►

Zig           ████████████████████████████████████  15.2M         █          9.59
C             ███████████████████████               9.8M          █          9.34
D             ██████████████████████                9.5M          ████       62.23
Odin          █████████████████████                 8.6M          █          9.55
C++           ████████████████████                  8.1M          █          9.41
Go            ██████████████████                    7.5M          █          23.00
C#            █████████████████                     7.1M          ██████████ 164.94
Java          ██████████████                        5.9M          █████████████ 215.60
Node.js       ██████████                            4.5M          ██████████████████████████████████ 832.23
OCaml         ██████████                            4.3M          █          17.51
Kotlin        █████████                             4.1M          ██████████████████ 293.79
Dart          █████████                             3.8M          █          17.33
LuaJIT        ████████                              3.5M          ▏          2.08
Nim           ████████                              3.4M          █          25.50
Rust          ███████                               3.2M          █          9.83
PHP           ██                                    1.2M          █          26.05
Python        █                                     0.8M          ███        48.02
Erlang        █                                     0.7M          ███        48.26
Swift         █                                     0.6M          █          22.20
Gleam         ▏                                     0.1M          ███        47.85
```

---

### Overall Efficiency — Speed per MB (sorted by rows/sec per MB of memory)

Higher = faster AND more memory efficient. Score = `rows_per_sec / peak_memory_MB`.

```
              SPEED (rows/sec)                                    MEMORY (MB)                          SCORE
              ◄──────────────────────────────────►                ◄──────────────────────────────────►

LuaJIT        ████████                              3.5M          ▏          2.08                     1,680,847
Zig           ████████████████████████████████████  15.2M         █          9.59                     1,588,567
C             ███████████████████████               9.8M          █          9.34                     1,053,657
Odin          █████████████████████                 8.6M          █          9.55                       900,853
C++           ████████████████████                  8.1M          █          9.41                       863,000
Rust          ███████                               3.2M          █          9.83                       322,370
Go            ██████████████████                    7.5M          █          23.00                      324,774
OCaml         ██████████                            4.3M          █          17.51                      242,721
Dart          █████████                             3.8M          █          17.33                      217,583
D             ██████████████████████                9.5M          ████       62.23                      152,155
Nim           ████████                              3.4M          █          25.50                      131,784
PHP           ██                                    1.2M          █          26.05                       44,728
C#            █████████████████                     7.1M          ██████████ 164.94                      43,268
Java          ██████████████                        5.9M          █████████████ 215.60                   27,443
Swift         █                                     0.6M          █          22.20                       26,471
Python        █                                     0.8M          ███        48.02                       17,419
Erlang        █                                     0.7M          ███        48.26                       14,409
Kotlin        █████████                             4.1M          ██████████████████ 293.79              14,076
Node.js       ██████████                            4.5M          ██████████████████████████████████ 832.23   5,430
Gleam         ▏                                     0.1M          ███        47.85                        2,691
```

---

## Large File — Summary Table

| Rank | Language | Time (s) | Rows/sec | Peak Memory |
|-----:|----------|----------:|---------:|------------:|
| 1 | Zig | 3.281 | 15,239,358 | 9.59 MB |
| 2 | C | 5.081 | 9,841,161 | 9.34 MB |
| 3 | D | 5.281 | 9,468,188 | 62.23 MB |
| 4 | Odin | 5.812 | 8,603,156 | 9.55 MB |
| 5 | C++ | 6.157 | 8,120,830 | 9.41 MB |
| 6 | Go | 6.694 | 7,469,788 | 23.00 MB |
| 7 | C# | 7.006 | 7,136,962 | 164.94 MB |
| 8 | Java | 8.450 | 5,917,224 | 215.60 MB |
| 9 | Node.js | 11.064 | 4,519,277 | 832.23 MB |
| 10 | OCaml | 11.765 | 4,250,047 | 17.51 MB |
| 11 | Kotlin | 12.091 | 4,135,178 | 293.79 MB |
| 12 | Dart | 13.263 | 3,769,813 | 17.33 MB |
| 13 | LuaJIT | 14.310 | 3,494,161 | 2.08 MB |
| 14 | Nim | 14.879 | 3,360,496 | 25.50 MB |
| 15 | Rust | 15.778 | 3,168,891 | 9.83 MB |
| 16 | PHP | 42.922 | 1,164,908 | 26.05 MB |
| 17 | Python | 59.776 | 836,452 | 48.02 MB |
| 18 | Erlang | 71.898 | 695,429 | 48.26 MB |
| 19 | Swift | 85.084 | 587,653 | 22.20 MB |
| 20 | Gleam | 388.305 | 128,764 | 47.85 MB |

---

## Small File Results (5 rows, 302 B)

| Rank | Language | Time (s) | Rows/sec | Peak Memory |
|-----:|----------|----------:|---------:|------------:|
| 1 | PHP | 0.000 | 14,485 | 10.02 MB |
| 2 | Dart | 0.000 | 12,853 | 13.83 MB |
| 3 | OCaml | 0.001 | 9,640 | 8.41 MB |
| 4 | C | 0.001 | 9,057 | 1.36 MB |
| 5 | Odin | 0.001 | 8,872 | 1.52 MB |
| 6 | Python | 0.001 | 8,615 | 15.59 MB |
| 7 | C++ | 0.001 | 8,460 | 1.33 MB |
| 8 | Go | 0.001 | 6,736 | 4.61 MB |
| 9 | Rust | 0.001 | 4,888 | 1.61 MB |
| 10 | D | 0.001 | 4,191 | 10.48 MB |
| 11 | Swift | 0.001 | 4,058 | 5.98 MB |
| 12 | LuaJIT | 0.001 | 3,633 | 4.05 MB |
| 13 | Node.js | 0.002 | 3,214 | 42.80 MB |
| 14 | Nim | 0.002 | 2,429 | 9.47 MB |
| 15 | Zig | 0.002 | 2,397 | 1.59 MB |
| 16 | C# | 0.005 | 1,020 | 41.02 MB |
| 17 | Erlang | 0.011 | 474 | 32.73 MB |
| 18 | Gleam | 0.011 | 439 | 32.71 MB |
| 19 | Java | 0.019 | 259 | 15.20 MB |
| 20 | Kotlin | 0.036 | 140 | 17.46 MB |

---

## Speed Tiers (Large File)

### Tier 1 — Over 8M rows/sec
> Zig, C, D, Odin, C++

### Tier 2 — 4M to 8M rows/sec
> Go, C#, Java, Node.js, OCaml, Kotlin

### Tier 3 — 1M to 4M rows/sec
> Dart, LuaJIT, Nim, Rust, PHP

### Tier 4 — Under 1M rows/sec
> Python, Erlang, Swift, Gleam

---

## Memory Tiers (Large File)

### Under 10 MB
> LuaJIT (2 MB), C (9 MB), C++ (9 MB), Odin (10 MB), Zig (10 MB), Rust (10 MB)

### 10–50 MB
> Dart (17 MB), OCaml (18 MB), Swift (22 MB), Go (23 MB), Nim (26 MB), PHP (26 MB), Gleam (48 MB), Python (48 MB), Erlang (48 MB)

### 50–100 MB
> D (62 MB)

### Over 100 MB
> C# (165 MB), Java (216 MB), Kotlin (294 MB), Node.js (832 MB)

---

## Speed vs Memory (Large File)

```
                     Low Memory ◄────────────────────► High Memory
                     │
Fast (< 7s)          │  Zig ★        C   Odin  C++        D              Go
                     │
Medium (7–15s)       │  OCaml  Dart                 C#    Java    Kotlin  Node.js
                     │  LuaJIT  Rust  Nim
                     │
Slow (> 15s)         │                Swift  PHP
                     │          Python  Erlang  Gleam
                     │
                     └──────────────────────────────────────────────────────────────────
                     0 MB      10 MB         50 MB       100 MB    200 MB    500 MB   800 MB
```

---

## Build Commands

| Language | Command |
|----------|---------|
| Zig | `zig build-exe main.zig -OReleaseFast` |
| C | `gcc -O3 -o main main.c -lm` |
| C++ | `g++ -O3 -std=c++17 -o main main.cpp` |
| D | `ldc2 -O3 -release -of=main main.d` |
| Odin | `odin build . -o:speed -out:main` |
| Go | `go build -o main main.go` |
| Rust | `cargo build --release` |
| Swift | `swiftc -O -o main main.swift` |
| Nim | `nim c -d:release -o:main main.nim` |
| OCaml | `ocamlopt -O2 -I +unix unix.cmxa -o main main.ml` |
| Dart | `dart compile exe main.dart -o main` |
| C# | `dotnet run -c Release` |
| Java | `javac Main.java && java Main` |
| Kotlin | `kotlinc Main.kt -include-runtime -d Main.jar && java -jar Main.jar` |
| Node.js | `node main.js` |
| PHP | `php main.php` |
| Python | `python3 main.py` |
| LuaJIT | `luajit main.lua` |
| Erlang | `erlc main.erl && erl -noshell -s main main` |
| Gleam | `gleam run` |

---

## Generating CSV Files

The CSV files are generated using `csv-generator.js` in the project root. You need Node.js, Bun, or Deno to run it.

Edit the `N` value in `csv-generator.js`:
- `N = 5` for `users-small.csv`
- `N = 50_000_000` for `users-big.csv`

```sh
node csv-generator.js
```

These CSV files must be generated before running any benchmark.

---

## How the Code Was Generated

All source code for every language was generated by **Claude (AI)** following the rules defined in `instruction.md`. The instruction specifies the exact requirements for CSV streaming, validation, statistics, JSON output, progress bar, console output format, and peak memory reporting — ensuring a fair and consistent comparison across all languages.

---

## Test Environment

- **Machine**: Apple Silicon MacBook (arm64)
- **OS**: macOS
- **Small file**: 5 rows, 302 B
- **Large file**: 50,000,000 rows, 2.32 GB
- **All implementations**: Single-threaded, streaming I/O, standard libraries
