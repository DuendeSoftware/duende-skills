# React SPA Client Configuration

A browser-based SPA is a **public client** (it cannot keep a secret), so it uses authorization code flow with PKCE, `RequireClientSecret = false`, CORS origins for the token endpoint, and `AllowOfflineAccess = true` for refresh tokens.

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;

public static IEnumerable<Client> Clients =>
    new Client[]
    {
        new Client
        {
            ClientId = "react-spa",
            ClientName = "React SPA",

            AllowedGrantTypes = GrantTypes.Code,   // authorization code, NOT implicit
            RequireClientSecret = false,           // public client — no secret
            RequirePkce = true,                    // mandatory for public code-flow clients

            RedirectUris          = { "https://spa.myapp.com/callback" },
            PostLogoutRedirectUris = { "https://spa.myapp.com/" },

            // Browser calls the token endpoint cross-origin, so allow the SPA origin
            AllowedCorsOrigins = { "https://spa.myapp.com" },

            AllowOfflineAccess = true,             // refresh tokens

            AllowedScopes =
            {
                IdentityServerConstants.StandardScopes.OpenId,
                IdentityServerConstants.StandardScopes.Profile,
                "orders.read"
            }
        }
    };
```

Supporting scope and registration:

```csharp
public static IEnumerable<ApiScope> ApiScopes =>
    new ApiScope[] { new ApiScope("orders.read", "Read orders") };

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(new IdentityResource[]
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile()
    })
    .AddInMemoryApiScopes(ApiScopes)
    .AddInMemoryClients(Clients);
```

## Notes

- **`GrantTypes.Code` + `RequirePkce = true`** — the current best practice for SPAs. Never use `GrantTypes.Implicit`, which is deprecated and insecure.
- **`RequireClientSecret = false`** — a SPA runs entirely in the browser and cannot protect a secret, so it's a public client. PKCE replaces the client secret as proof.
- **`AllowedCorsOrigins = { "https://spa.myapp.com" }`** — required because the SPA's JavaScript calls the `/connect/token` (and userinfo) endpoints cross-origin. IdentityServer's CORS policy service reads this property automatically.
- **`AllowOfflineAccess = true`** — enables refresh tokens. For SPAs, use refresh token rotation (`RefreshTokenUsage = OneTimeOnly`) and consider a BFF pattern to keep tokens out of the browser for stronger security.
- **`AllowedScopes`** includes `openid`, `profile`, and the API scope `orders.read`.

> For production, strongly consider the **Backend-for-Frontend (BFF)** pattern instead of storing tokens in the browser — it holds tokens server-side and hardens the SPA against token theft.
