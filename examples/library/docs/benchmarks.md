# Benchmark baselines

Measured locally, never in CI, as `overlays/benchmarks.md` requires: numbers
from shared runners are noise. Re-measure on the same machine before
comparing a change against these.

Run from `examples/library/`:

```sh
dotnet run -c Release --project bench/Contoso.Csv.Benchmarks
```

## 2026-11-19 — `Contoso.Csv` `1.0.0`

BenchmarkDotNet `0.15.8`, default job, Windows 11 (`10.0.26300`), Intel
Core i7-9750H, .NET SDK `10.0.404`, runtime `10.0.15` (X64 RyuJIT).

Each record is five fields: two unquoted, one quoted around a delimiter,
one decimal, and one quoted with escaped quotes.

| Method              | Records | Mean        | Error     | StdDev    | Allocated   |
|-------------------- |-------- |------------:|----------:|----------:|------------:|
| ReadAllRecordsAsync | 1000    |    379.1 us |  19.77 us |  56.08 us |   258.51 KB |
| ReadAllRecordsAsync | 100000  | 36,598.3 us | 707.13 us | 967.93 us | 25008.51 KB |
