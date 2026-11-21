using System.Runtime.CompilerServices;
using System.Text;

namespace Contoso.Csv;

/// <summary>
/// Reads CSV records as RFC 4180 defines them.
/// </summary>
/// <remarks>
/// A record ends at a CRLF, LF, or CR outside a quoted field, and a line break
/// after the last record adds no record. A blank line is a record with one
/// empty field. Records need not have the same number of fields.
/// </remarks>
public static class CsvReader
{
    private const int BufferSize = 4096;

    private enum State
    {
        RecordStart,
        FieldStart,
        Unquoted,
        Quoted,
        QuoteInQuoted,
    }

    /// <summary>
    /// Reads the records of the CSV text that <paramref name="reader"/> returns.
    /// </summary>
    /// <param name="reader">The source of the CSV text. The caller owns it and disposes it.</param>
    /// <param name="delimiter">The character that separates fields.</param>
    /// <param name="cancellationToken">A token that stops the reading.</param>
    /// <returns>The records, each as its fields in order.</returns>
    /// <exception cref="ArgumentNullException"><paramref name="reader"/> is <see langword="null"/>.</exception>
    /// <exception cref="ArgumentException">
    /// <paramref name="delimiter"/> is a double quote, a carriage return, or a line feed.
    /// </exception>
    /// <exception cref="CsvFormatException">
    /// Thrown while enumerating, when the text breaks the format; the records before the
    /// malformed one have been returned.
    /// </exception>
    public static IAsyncEnumerable<IReadOnlyList<string>> ReadAsync(
        TextReader reader,
        char delimiter = ',',
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(reader);

        if (delimiter is '"' or '\r' or '\n')
        {
            throw new ArgumentException(
                "The delimiter cannot be a double quote, a carriage return, or a line feed.",
                nameof(delimiter));
        }

        return ReadRecordsAsync(reader, delimiter, cancellationToken);
    }

    private static async IAsyncEnumerable<IReadOnlyList<string>> ReadRecordsAsync(
        TextReader reader,
        char delimiter,
        [EnumeratorCancellation] CancellationToken cancellationToken)
    {
        var buffer = new char[BufferSize];
        var fields = new List<string>();
        var field = new StringBuilder();
        var state = State.RecordStart;
        var line = 1;
        var quoteLine = 1;
        var previous = '\0';

        while (true)
        {
            cancellationToken.ThrowIfCancellationRequested();

            var count = await reader.ReadAsync(buffer.AsMemory(), cancellationToken).ConfigureAwait(false);
            if (count == 0)
            {
                break;
            }

            for (var i = 0; i < count; i++)
            {
                var c = buffer[i];
                var recordEnded = false;

                switch (state)
                {
                    case State.RecordStart when c == '\n' && previous == '\r':
                        break;
                    case State.RecordStart or State.FieldStart when c == '"':
                        state = State.Quoted;
                        quoteLine = line;
                        break;
                    case State.RecordStart or State.FieldStart or State.Unquoted or State.QuoteInQuoted
                        when c == delimiter:
                        EndField(fields, field);
                        state = State.FieldStart;
                        break;
                    case State.RecordStart or State.FieldStart or State.Unquoted or State.QuoteInQuoted
                        when c is '\r' or '\n':
                        EndField(fields, field);
                        recordEnded = true;
                        break;
                    case State.RecordStart or State.FieldStart:
                        field.Append(c);
                        state = State.Unquoted;
                        break;
                    case State.Unquoted when c == '"':
                        throw new CsvFormatException(
                            $"Line {line}: a double quote appears inside an unquoted field.", line);
                    case State.Unquoted:
                        field.Append(c);
                        break;
                    case State.Quoted when c == '"':
                        state = State.QuoteInQuoted;
                        break;
                    case State.Quoted:
                        field.Append(c);
                        break;
                    case State.QuoteInQuoted when c == '"':
                        field.Append('"');
                        state = State.Quoted;
                        break;
                    case State.QuoteInQuoted:
                        throw new CsvFormatException(
                            $"Line {line}: a character other than a delimiter or a line break follows a closing quote.",
                            line);
                }

                if (c == '\r' || (c == '\n' && previous != '\r'))
                {
                    line++;
                }

                previous = c;

                if (recordEnded)
                {
                    yield return fields.ToArray();
                    fields.Clear();
                    state = State.RecordStart;
                    cancellationToken.ThrowIfCancellationRequested();
                }
            }
        }

        switch (state)
        {
            case State.Quoted:
                throw new CsvFormatException(
                    $"Line {quoteLine}: a quoted field is not closed before the end of the text.", quoteLine);
            case State.FieldStart or State.Unquoted or State.QuoteInQuoted:
                EndField(fields, field);
                yield return fields.ToArray();
                break;
        }
    }

    private static void EndField(List<string> fields, StringBuilder field)
    {
        fields.Add(field.ToString());
        field.Clear();
    }
}
