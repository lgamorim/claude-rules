namespace Contoso.Csv;

/// <summary>
/// The exception thrown when CSV text breaks the format RFC 4180 defines.
/// </summary>
public sealed class CsvFormatException : FormatException
{
    internal CsvFormatException(string message, int lineNumber)
        : base(message) =>
        LineNumber = lineNumber;

    /// <summary>
    /// Gets the 1-based line of the text on which the error was found.
    /// </summary>
    public int LineNumber { get; }
}
