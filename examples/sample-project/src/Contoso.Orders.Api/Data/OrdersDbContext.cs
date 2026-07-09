using Contoso.Orders.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace Contoso.Orders.Api.Data;

/// <summary>
/// EF Core database context for the Orders bounded context.
/// </summary>
/// <param name="options">The EF Core options used to configure this context.</param>
public class OrdersDbContext(DbContextOptions<OrdersDbContext> options) : DbContext(options)
{
    /// <summary>
    /// Gets the set of persisted orders.
    /// </summary>
    public DbSet<Order> Orders => Set<Order>();

    /// <inheritdoc />
    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Order>()
            .Property(o => o.CustomerName)
            .HasMaxLength(200);
    }
}
