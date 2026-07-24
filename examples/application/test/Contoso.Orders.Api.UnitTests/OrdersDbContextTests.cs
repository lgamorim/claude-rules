using Contoso.Orders.Api.Data;
using Contoso.Orders.Api.Models;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace Contoso.Orders.Api.UnitTests;

public class OrdersDbContextTests
{
    [Fact]
    public async Task Should_ReturnSavedOrder_When_OrderIsSavedAndRetrieved()
    {
        var options = new DbContextOptionsBuilder<OrdersDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;

        await using var db = new OrdersDbContext(options);

        db.Orders.Add(new Order
        {
            CustomerName = "Ana Silva",
            Total = 42.50m,
            PlacedAt = new DateTimeOffset(2024, 1, 1, 0, 0, 0, TimeSpan.Zero)
        });
        await db.SaveChangesAsync();

        var saved = await db.Orders.AsNoTracking().SingleAsync();

        Assert.Equal("Ana Silva", saved.CustomerName);
    }
}
