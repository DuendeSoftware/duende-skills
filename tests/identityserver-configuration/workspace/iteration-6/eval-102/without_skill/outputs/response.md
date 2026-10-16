```csharp
using Duende.IdentityServer.Models;

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(new IdentityResource[]
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile()
    })
    .AddInMemoryApiScopes(new[] { new ApiScope("orders.read") })
    .AddInMemoryClients(new[]
    {
        new Client
        {
            ClientId = "react-spa",
            ClientName = "React SPA",
            AllowedGrantTypes = GrantTypes.Code,
            RequireClientSecret = false,   // public client
            RequirePkce = true,
            RedirectUris = { "https://spa.myapp.com/callback" },
            PostLogoutRedirectUris = { "https://spa.myapp.com/" },
            AllowedCorsOrigins = { "https://spa.myapp.com" },
            AllowedScopes = { "openid", "profile", "orders.read" },
            AllowOfflineAccess = true,     // refresh tokens
            RefreshTokenUsage = TokenUsage.OneTimeOnly,
            RefreshTokenExpiration = TokenExpiration.Sliding,
            AbsoluteRefreshTokenLifetime = 86400,
            SlidingRefreshTokenLifetime = 3600
        }
    });
```
The SPA is a public client, so no secret; it uses code flow + PKCE. Refresh tokens require `AllowOfflineAccess` and the client requesting `offline_access`. One-time-use rotation is recommended for browsers. Add `app.UseIdentityServer();` in the pipeline.
