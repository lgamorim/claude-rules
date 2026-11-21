using System.Text;
using BenchmarkDotNet.Attributes;

namespace Contoso.Csv.Benchmarks;

/// <summary>
/// Measures <see cref="CsvReader.ReadAsync"/> over text held in memory, so the
/// numbers reflect parsing rather than I/O.
/// </summary>
[MemoryDiagnoser]
public class CsvReaderBenchmarks
{
    private string _csv = string.Empty;

    /// <summary>
    /// Gets or sets the number of records in the text.
    /// </summary>
    [Params(1_000, 100_000)]
    public int Records { get; set; }

    /// <summary>
    /// Builds text whose records mix unquoted fields, quoted fields holding a
    /// delimiter, and quoted fields holding escaped quotes.
    /// </summary>
    [GlobalSetup]
    public void Setup()
    {
        var text = new StringBuilder();
        for (var i = 0; i < Records; i++)
        {
            text.Append(i).Append(",Ana Silva,\"Lisbon, PT\",42.50,\"said \"\"hi\"\"\"\r\n");
        }

        _csv = text.ToString();
    }

    /// <summary>
    /// Reads every record and counts its fields.
    /// </summary>
    /// <returns>The number of fields read, so the work cannot be optimized away.</returns>
    [Benchmark]
    public async Task<int> ReadAllRecordsAsync()
    {
        var fields = 0;
        await foreach (var record in CsvReader.ReadAsync(new StringReader(_csv)))
        {
            fields += record.Count;
        }

        return fields;
    }
}
