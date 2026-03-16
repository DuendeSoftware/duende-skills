# Local and Remote API Endpoints

## Local API Endpoint

```csharp
app.MapGet("/api/orders", (HttpContext ctx) =>
{
    var orders = new[] { new { Id = 1, Name = "Order 1" } };
    return Results.Ok(orders);
})
.RequireAuthorization()
.AsBffApiEndpoint();
```

## Remote API Proxy

For the remote proxy, you can use BFF's remote API support:

```csharp
app.MapRemoteBffApiEndpoint("/api/catalog", new Uri("https://catalog-service.internal/api"))
    .RequireAccessToken(TokenType.User);
```

This will proxy requests from `/api/catalog` to the remote catalog service, automatically attaching the user's access token.

The local endpoint uses `.AsBffApiEndpoint()` for anti-forgery protection and `.RequireAuthorization()` to ensure the user is logged in.
