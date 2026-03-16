# Local and Remote API Endpoints with BFF

## Service Registration

```csharp
builder.Services.AddBff()
    .ConfigureOpenIdConnect(options =>
    {
        // ... OIDC configuration
    })
    .AddRemoteApis(); // Required for MapRemoteBffApiEndpoint
```

## Local API Endpoint

```csharp
app.MapGet("/api/orders", (HttpContext ctx) =>
{
    // Your order data logic
    var orders = new[] { new { Id = 1, Name = "Order 1" } };
    return Results.Ok(orders);
})
.RequireAuthorization()
.AsBffApiEndpoint(); // Enforces X-CSRF header for CSRF protection
```

## Remote API Proxy

```csharp
app.MapRemoteBffApiEndpoint("/api/catalog", new Uri("https://catalog-service.internal/api"))
    .WithAccessToken(RequiredTokenType.User); // Forward user's access token
```

## Key Points

- **`.AsBffApiEndpoint()`** enforces the `X-CSRF: 1` header on the local endpoint — never omit this for browser-facing API endpoints.
- **`.RequireAuthorization()`** ensures the user must be authenticated.
- **`AddRemoteApis()`** must be called on the BFF builder to enable `MapRemoteBffApiEndpoint`.
- **`.WithAccessToken(RequiredTokenType.User)`** tells BFF to attach the user's access token to outgoing requests. If the user is not authenticated, a 401 challenge is triggered.
- All sub-paths under `/api/catalog` are also proxied (e.g., `/api/catalog/products`).
