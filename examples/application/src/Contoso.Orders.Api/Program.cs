using Contoso.Orders.Api.Data;
using Contoso.Orders.Api.Endpoints;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddDbContext<OrdersDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("Orders")));

builder.Services.AddProblemDetails();

var app = builder.Build();

app.UseExceptionHandler();

app.MapOrdersEndpoints();

app.Run();
