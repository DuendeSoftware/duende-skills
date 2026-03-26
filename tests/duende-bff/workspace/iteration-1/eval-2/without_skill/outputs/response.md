# Adding Local and Remote API Endpoints

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddBff();
builder.Services.AddAuthentication(/* ... */);
builder.Services.AddAuthorization();

var app = builder.Build();

app.UseRouting();
app.UseAuthentication();
app.UseBff();
app.UseAuthorization();

// Local API endpoint
app.MapGet("/api/orders", () =>
{
    return Results.Ok(new[]
    {
        new { Id = 1, Product = "Widget", Quantity = 5 },
    });
}).RequireAuthorization();

// Remote proxy to catalog service
app.MapRemoteBffApiEndpoint("/api/catalog", new Uri("https://catalog-service.internal/api"))
    .RequireAccessToken(TokenType.User);

app.MapBffManagementEndpoints();

app.Run();
```

The local endpoint requires authorization, and the remote endpoint proxies to the catalog service with the user's access token.
