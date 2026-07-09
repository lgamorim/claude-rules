using Contoso.Orders.Api.Data;
using Contoso.Orders.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace Contoso.Orders.Api.Endpoints;

/// <summary>
/// Provides extension methods for mapping the Orders minimal API endpoints.
/// </summary>
public static class OrdersEndpoints
{
    /// <summary>
    /// Maps the <c>/orders</c> endpoint group (list, get by id, create) onto the given application.
    /// </summary>
    /// <param name="app">The web application to map the endpoints onto.</param>
    public static void MapOrdersEndpoints(this WebApplication app)
    {
        var group = app.MapGroup("/orders");

        group.MapGet("/", async (OrdersDbContext db, CancellationToken ct) =>
            await db.Orders.AsNoTracking().ToListAsync(ct));

        group.MapGet("/{id:int}", async (int id, OrdersDbContext db, CancellationToken ct) =>
        {
            var order = await db.Orders
                .AsNoTracking()
                .FirstOrDefaultAsync(o => o.Id == id, ct);

            return order is null ? Results.NotFound() : Results.Ok(order);
        });

        group.MapPost("/", async (Order order, OrdersDbContext db, CancellationToken ct) =>
        {
            db.Orders.Add(order);
            await db.SaveChangesAsync(ct);
            return Results.Created($"/orders/{order.Id}", order);
        });
    }
}
