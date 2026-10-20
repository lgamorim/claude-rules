using System.Net;
using Xunit;

namespace Contoso.Orders.Api.IntegrationTests;

public class OrdersEndpointsTests(OrdersApiFactory factory) : IClassFixture<OrdersApiFactory>
{
    [Fact]
    public async Task Should_ReturnNotFound_When_OrderDoesNotExist()
    {
        using var client = factory.CreateClient();

        var response = await client.GetAsync($"/orders/{int.MaxValue}");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }
}
