# React SPA Client Configuration

A React SPA is a public client, so it uses authorization code flow with PKCE, no client secret, CORS origins for the browser to reach the token endpoint, and offline access for refresh tokens.

```csharp
using Duende.IdentityServer.Models;

public static IEnumerable<Client> Clients =>
    new Client[]
    {
        new Client
        {
            ClientId = "react-spa",

            AllowedGrantTypes = GrantTypes.Code,
            RequireClientSecret = false,   // public SPA client
            RequirePkce = true,

            RedirectUris           = { "https://spa.myapp.com/callback" },
            PostLogoutRedirectUris = { "https://spa.myapp.com/" },

            AllowedCorsOrigins = { "https://spa.myapp.com" },

            AllowOfflineAccess = true,

            AllowedScopes =
            {
                "openid",
                "profile",
                "orders.read"
            }
        }
    };
```

Register it along with the scope and identity resources:

```csharp
builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(new IdentityResource[]
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile()
    })
    .AddInMemoryApiScopes(new[] { new ApiScope("orders.read") })
    .AddInMemoryClients(Clients);
```

## Notes

- `GrantTypes.Code` with PKCE is the correct, secure flow for SPAs (implicit flow is deprecated).
- `RequireClientSecret = false` because a browser app can't keep a secret.
- `AllowedCorsOrigins` must include `https://spa.myapp.com` so the SPA can call the token/userinfo endpoints from the browser.
- `AllowOfflineAccess = true` enables refresh tokens; use rotation for SPAs.
- Scopes: `openid`, `profile`, and `orders.read`.
