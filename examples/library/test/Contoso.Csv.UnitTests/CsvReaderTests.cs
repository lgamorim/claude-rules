using Xunit;

namespace Contoso.Csv.UnitTests;

public class CsvReaderTests
{
    [Fact]
    public async Task Should_ReturnNoRecords_When_InputIsEmpty()
    {
        var records = await ReadAllAsync(new StringReader(string.Empty));

        Assert.Empty(records);
    }

    [Fact]
    public async Task Should_SplitFieldsOnComma_When_FieldsAreUnquoted()
    {
        var records = await ReadAllAsync(new StringReader("a,b,c"));

        Assert.Equal([["a", "b", "c"]], records);
    }

    [Theory]
    [InlineData("a,b\r\nc,d")]
    [InlineData("a,b\nc,d")]
    [InlineData("a,b\rc,d")]
    public async Task Should_ReturnOneRecordPerLine_When_LinesEndWithAnyLineBreak(string csv)
    {
        var records = await ReadAllAsync(new StringReader(csv));

        Assert.Equal([["a", "b"], ["c", "d"]], records);
    }

    [Theory]
    [InlineData("a,b\r\n")]
    [InlineData("a,b\n")]
    [InlineData("a,b\r")]
    public async Task Should_ReturnNoTrailingRecord_When_InputEndsWithLineBreak(string csv)
    {
        var records = await ReadAllAsync(new StringReader(csv));

        Assert.Equal([["a", "b"]], records);
    }

    [Fact]
    public async Task Should_ReturnRecordWithOneEmptyField_When_LineIsBlank()
    {
        var records = await ReadAllAsync(new StringReader("a\r\n\r\nb"));

        Assert.Equal([["a"], [""], ["b"]], records);
    }

    [Fact]
    public async Task Should_ReturnEmptyFields_When_DelimitersAreAdjacentOrAtLineEdges()
    {
        var records = await ReadAllAsync(new StringReader(",a,,b,"));

        Assert.Equal([["", "a", "", "b", ""]], records);
    }

    [Fact]
    public async Task Should_KeepSpaces_When_UnquotedFieldHasLeadingOrTrailingSpaces()
    {
        var records = await ReadAllAsync(new StringReader(" a , b "));

        Assert.Equal([[" a ", " b "]], records);
    }

    [Fact]
    public async Task Should_KeepDelimitersAndLineBreaks_When_FieldIsQuoted()
    {
        var records = await ReadAllAsync(new StringReader("\"a,b\r\nc\",d"));

        Assert.Equal([["a,b\r\nc", "d"]], records);
    }

    [Fact]
    public async Task Should_UnescapeDoubledQuotes_When_FieldIsQuoted()
    {
        var records = await ReadAllAsync(new StringReader("\"say \"\"hi\"\"\",x"));

        Assert.Equal([["say \"hi\"", "x"]], records);
    }

    [Fact]
    public async Task Should_ReturnEmptyField_When_QuotedFieldIsEmpty()
    {
        var records = await ReadAllAsync(new StringReader("\"\",a,\"\""));

        Assert.Equal([["", "a", ""]], records);
    }

    [Fact]
    public async Task Should_ReturnEachRecordsOwnFieldCount_When_RecordsAreRagged()
    {
        var records = await ReadAllAsync(new StringReader("a\nb,c,d\ne,f"));

        Assert.Equal([["a"], ["b", "c", "d"], ["e", "f"]], records);
    }

    [Fact]
    public async Task Should_SplitOnGivenDelimiter_When_DelimiterIsNotComma()
    {
        var records = await ReadAllAsync(new StringReader("a\tb,c\t\"d\te\""), '\t');

        Assert.Equal([["a", "b,c", "d\te"]], records);
    }

    [Fact]
    public async Task Should_ReturnSameRecords_When_ReaderReturnsOneCharacterPerRead()
    {
        const string Csv = "a,\"b\"\"c\"\r\n\"d\r\ne\",f\r\n\r\ng,\"\"\r\n";

        var records = await ReadAllAsync(new OneCharacterReader(Csv));

        Assert.Equal([["a", "b\"c"], ["d\r\ne", "f"], [""], ["g", ""]], records);
    }

    [Fact]
    public async Task Should_ReadWholeField_When_FieldIsLongerThanAnyReadBuffer()
    {
        var longField = new string('x', 100_000);

        var records = await ReadAllAsync(new StringReader($"{longField},\"{longField}\""));

        Assert.Equal([[longField, longField]], records);
    }

    [Fact]
    public async Task Should_ThrowCsvFormatException_When_QuotedFieldIsUnterminated()
    {
        var exception = await Assert.ThrowsAsync<CsvFormatException>(
            () => ReadAllAsync(new StringReader("a,b\nc,\"d\ne")));

        Assert.Equal(2, exception.LineNumber);
    }

    [Fact]
    public async Task Should_ThrowCsvFormatException_When_QuoteAppearsInUnquotedField()
    {
        var exception = await Assert.ThrowsAsync<CsvFormatException>(
            () => ReadAllAsync(new StringReader("a,b\"c")));

        Assert.Equal(1, exception.LineNumber);
    }

    [Fact]
    public async Task Should_ThrowCsvFormatException_When_CharacterFollowsClosingQuote()
    {
        var exception = await Assert.ThrowsAsync<CsvFormatException>(
            () => ReadAllAsync(new StringReader("\"a\"b,c")));

        Assert.Equal(1, exception.LineNumber);
    }

    [Theory]
    [InlineData("a\r\n\"b\r\nc\"\r\n\"d\"e")]
    [InlineData("a\n\"b\nc\"\n\"d\"e")]
    [InlineData("a\r\"b\rc\"\r\"d\"e")]
    public async Task Should_ReportPhysicalLineNumber_When_ErrorFollowsLineBreaks(string csv)
    {
        var exception = await Assert.ThrowsAsync<CsvFormatException>(
            () => ReadAllAsync(new StringReader(csv)));

        Assert.Equal(4, exception.LineNumber);
    }

    [Fact]
    public async Task Should_ReturnRecordsBeforeError_When_LaterRecordIsMalformed()
    {
        var records = new List<string[]>();

        await Assert.ThrowsAsync<CsvFormatException>(async () =>
        {
            await foreach (var record in CsvReader.ReadAsync(new StringReader("a,b\nc\"d")))
            {
                records.Add([.. record]);
            }
        });

        Assert.Equal([["a", "b"]], records);
    }

    [Fact]
    public void Should_ThrowArgumentNullException_When_ReaderIsNull()
    {
        // `!` passes the null that nullable annotations forbid, which is the case under test.
        var exception = Assert.Throws<ArgumentNullException>(() => CsvReader.ReadAsync(null!));

        Assert.Equal("reader", exception.ParamName);
    }

    [Theory]
    [InlineData('"')]
    [InlineData('\r')]
    [InlineData('\n')]
    public void Should_ThrowArgumentException_When_DelimiterIsQuoteOrLineBreak(char delimiter)
    {
        var exception = Assert.Throws<ArgumentException>(
            () => CsvReader.ReadAsync(new StringReader("a"), delimiter));

        Assert.Equal("delimiter", exception.ParamName);
    }

    [Fact]
    public async Task Should_ThrowOperationCanceledException_When_TokenIsCanceledBeforeReading()
    {
        using var cancellation = new CancellationTokenSource();
        await cancellation.CancelAsync();

        await Assert.ThrowsAnyAsync<OperationCanceledException>(
            () => ReadAllAsync(new StringReader("a,b"), cancellationToken: cancellation.Token));
    }

    [Fact]
    public async Task Should_StopAfterCurrentRecord_When_TokenIsCanceledBetweenRecords()
    {
        using var cancellation = new CancellationTokenSource();
        await using var records = CsvReader
            .ReadAsync(new StringReader("a\nb\nc"), cancellationToken: cancellation.Token)
            .GetAsyncEnumerator();

        Assert.True(await records.MoveNextAsync());
        await cancellation.CancelAsync();

        await Assert.ThrowsAnyAsync<OperationCanceledException>(async () => await records.MoveNextAsync());
    }

    private static async Task<string[][]> ReadAllAsync(
        TextReader reader,
        char delimiter = ',',
        CancellationToken cancellationToken = default)
    {
        var records = new List<string[]>();

        await foreach (var record in CsvReader.ReadAsync(reader, delimiter, cancellationToken))
        {
            records.Add([.. record]);
        }

        return [.. records];
    }
}
