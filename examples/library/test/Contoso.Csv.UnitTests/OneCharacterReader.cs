namespace Contoso.Csv.UnitTests;

/// <summary>
/// A <see cref="TextReader"/> that returns at most one character per read, so
/// every character of the input lands at a buffer boundary of its caller.
/// </summary>
internal sealed class OneCharacterReader(string text) : TextReader
{
    private int _position;

    public override ValueTask<int> ReadAsync(Memory<char> buffer, CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();

        if (_position == text.Length || buffer.IsEmpty)
        {
            return ValueTask.FromResult(0);
        }

        buffer.Span[0] = text[_position++];
        return ValueTask.FromResult(1);
    }
}
