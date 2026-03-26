# React SPA Client Configuration

```csharp
builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(new[]
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile()
    })
    .AddInMemoryApiScopes(new[]
    {
        new ApiScope("orders.read")
    })
    .AddInMemoryClients(new[]
    {
        new Client
        {
            ClientId = "react-spa",
            AllowedGrantTypes = GrantTypes.Code,
            RequireClientSecret = false,
            RedirectUris = { "https://spa.myapp.com/callback" },
            PostLogoutRedirectUris = { "https://spa.myapp.com" },
            AllowOfflineAccess = true,
            AllowedScopes = { "openid", "profile", "orders.read" }
        }
    });
```

This configures a public client SPA using authorization code flow with PKCE. No client secret is required since it's a browser app.
