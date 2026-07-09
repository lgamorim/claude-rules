namespace Contoso.Orders.Api.Models;

/// <summary>
/// Represents a customer order.
/// </summary>
public class Order
{
    /// <summary>
    /// Gets or sets the unique identifier of the order.
    /// </summary>
    public int Id { get; set; }

    /// <summary>
    /// Gets or sets the name of the customer who placed the order.
    /// </summary>
    public required string CustomerName { get; set; }

    /// <summary>
    /// Gets or sets the total monetary amount of the order.
    /// </summary>
    public decimal Total { get; set; }

    /// <summary>
    /// Gets or sets the date and time the order was placed.
    /// </summary>
    public DateTimeOffset PlacedAt { get; set; }
}
