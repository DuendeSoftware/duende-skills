Here's how to add a local API endpoint and proxy to a remote service with Duende BFF:

```csharp
// Program.cs
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddBff();
builder.Services.AddAuthentication(options =>
{
    options.DefaultScheme = "Cookies";
    options.DefaultChallengeScheme = "OpenIdConnect";
})
.AddCookie("Cookies")
.AddOpenIdConnect("OpenIdConnect", options =>
{
    options.Authority = "https://idp.example.com";
    options.ClientId = "spa-bff-client";
    options.ClientSecret = "secret";
    options.ResponseType = "code";
    options.SaveTokens = true;
});

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseRouting();
app.UseAuthentication();
app.UseBff();
app.UseAuthorization();

app.MapBffManagementEndpoints();

// Local API endpoint
app.MapGet("/api/orders", () =>
{
    var orders = new[]
    {
        new { Id = 1, Name = "Order #1" },
        new { Id = 2, Name = "Order #2" }
    };
    return Results.Ok(orders);
})
.RequireAuthorization();

// Remote API proxy
app.MapRemoteBffApiEndpoint("/api/catalog", new Uri("https://catalog-service.internal/api"))
    .RequireAccessToken(TokenType.User);

app.Run();
```

This configures:
- A local `/api/orders` endpoint that requires authentication
- A remote proxy for `/api/catalog` that forwards requests to your catalog service with the user's access token
