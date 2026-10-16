```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(new IdentityResource[]
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile()
    })
    .AddInMemoryApiScopes(new[] { new ApiScope("orders.read", "Read orders") })
    .AddInMemoryClients(new[]
    {
        new Client
        {
            ClientId = "react-spa",
            ClientName = "React SPA",

            AllowedGrantTypes = GrantTypes.Code,
            RequirePkce = true,
            RequireClientSecret = false,   // public client: browser can't keep a secret

            RedirectUris = { "https://spa.myapp.com/callback" },
            PostLogoutRedirectUris = { "https://spa.myapp.com/" },
            AllowedCorsOrigins = { "https://spa.myapp.com" },

            AllowOfflineAccess = true,     // required for refresh tokens

            // Rotate refresh tokens: safer for browser clients
            RefreshTokenUsage = TokenUsage.OneTimeOnly,
            RefreshTokenExpiration = TokenExpiration.Sliding,

            AllowedScopes =
            {
                IdentityServerConstants.StandardScopes.OpenId,
                IdentityServerConstants.StandardScopes.Profile,
                "orders.read"
            }
        }
    });

var app = builder.Build();
app.UseIdentityServer();
```
Key points:
- Authorization Code + PKCE; never implicit.
- `AllowedCorsOrigins` lets the SPA call the token endpoint cross-origin.
- Refresh tokens need `AllowOfflineAccess = true` **and** the SPA requesting `offline_access`; otherwise none is issued silently.
- `openid` is mandatory; `profile` gives the user profile info.
- Redirect URIs must match exactly (no trailing-slash mismatch).
- For better security, consider the BFF pattern (see the `duende-bff` skill), which keeps tokens out of the browser and lets you use a confidential client.
