# gRPC client with the current user's token

```csharp
// cookie + OIDC must be configured with SaveTokens = true and offline_access
builder.Services.AddOpenIdConnectAccessTokenManagement();

builder.Services.AddGrpcClient<Greeter.GreeterClient>(o =>
{
    o.Address = new Uri("https://grpc.example.com");
})
.AddUserAccessTokenHandler();   // ✅ attaches the user's access token (refreshed if needed)
```

Inject `Greeter.GreeterClient` as usual; no token code at call sites.

For a machine-to-machine token instead of the user's:

```csharp
builder.Services.AddGrpcClient<Inventory.InventoryClient>(o =>
{
    o.Address = new Uri("https://grpc.example.com");
})
.AddClientAccessTokenHandler();
```

Notes:
- Requires `Duende.AccessTokenManagement.OpenIdConnect` (already in your csproj) and an authentication setup where the token is saved: `options.SaveTokens = true` (the most common misconfiguration) and the `offline_access` scope so refresh works.
- Revoke the refresh token on sign-out via the cookie's `OnSigningOut` → `e.HttpContext.RevokeRefreshTokenAsync()`.
- If you use `AddClientCredentialsTokenHandler` instead, also add `.AddDefaultAccessTokenResiliency()`.
