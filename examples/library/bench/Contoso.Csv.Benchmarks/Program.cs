using BenchmarkDotNet.Running;
using Contoso.Csv.Benchmarks;

BenchmarkRunner.Run<CsvReaderBenchmarks>(args: args);
