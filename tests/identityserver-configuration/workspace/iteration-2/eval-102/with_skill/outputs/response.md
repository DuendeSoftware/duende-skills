Here's the SPA client configuration for a React application at `https://spa.myapp.com`:

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

var idsvrBuilder = builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(new List<IdentityResource>
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile()
    })
    .AddInMemoryApiScopes(new List<ApiScope>
    {
        new ApiScope("orders.read", "Read orders")
    })
    .AddInMemoryClients(new List<Client>
    {
        new Client
        {
            ClientId = "react-spa",
            ClientName = "React SPA",

            // Authorization code flow with PKCE — required for SPAs
            AllowedGrantTypes = GrantTypes.Code,
            RequirePkce = true,

            // SPA is a public client — no client secret
            RequireClientSecret = false,

            // Redirect URIs
            RedirectUris = { "https://spa.myapp.com/callback" },
            PostLogoutRedirectUris = { "https://spa.myapp.com" },

            // CORS — required for SPAs making cross-origin token requests
            AllowedCorsOrigins = { "https://spa.myapp.com" },

            // Enable refresh tokens
            AllowOfflineAccess = true,

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
app.UseAuthorization();
app.Run();
```

**Key configuration choices:**

1. **`GrantTypes.Code`** (not Implicit) — Authorization code flow with PKCE is the recommended flow for SPAs. Implicit flow is deprecated.
2. **`RequireClientSecret = false`** — SPAs are public clients; they cannot safely store a secret.
3. **`AllowedCorsOrigins`** — Required so the SPA can make cross-origin requests to the token endpoint.
4. **`AllowOfflineAccess = true`** — Enables refresh token issuance for the SPA.
5. **Scopes include `openid`, `profile`, and `orders.read`** — `openid` is mandatory for OIDC.

> **Note:** For production SPAs, consider the Backend-for-Frontend (BFF) pattern where the SPA communicates through a server-side component that holds the client secret. This provides better security than a public client.
