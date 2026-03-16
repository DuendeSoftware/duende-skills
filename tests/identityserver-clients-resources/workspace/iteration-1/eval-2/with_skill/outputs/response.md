# React SPA Client Configuration

Here's the full configuration for a React SPA at `https://spa.myapp.com` that authenticates users and calls your API.

## Client Definition

SPAs are **public clients** — they cannot securely hold a secret. Use `GrantTypes.Code` (authorization code flow with PKCE, which is the default in Duende IdentityServer where `RequirePkce = true`). Never use the implicit flow.

```csharp
new Client
{
    ClientId = "react-spa",
    ClientName = "React SPA",

    AllowedGrantTypes = GrantTypes.Code,
    RequireClientSecret = false,  // Public client — SPA cannot hold a secret
    RequirePkce = true,           // Default in Duende IS, but explicit for clarity

    RedirectUris = { "https://spa.myapp.com/callback" },
    PostLogoutRedirectUris = { "https://spa.myapp.com" },

    AllowedCorsOrigins = { "https://spa.myapp.com" },

    AllowOfflineAccess = true,    // Enable refresh tokens

    AllowedScopes =
    {
        IdentityServerConstants.StandardScopes.OpenId,
        IdentityServerConstants.StandardScopes.Profile,
        "orders.read"
    }
}
```

## API Scope Definition

```csharp
public static IEnumerable<ApiScope> ApiScopes =>
[
    new ApiScope("api1", "My API"),
    new ApiScope("orders.read", "Read orders")
];
```

## Key Configuration Decisions

1. **`GrantTypes.Code`** — Authorization code flow with PKCE is the only recommended flow for SPAs. The implicit flow (`GrantTypes.Implicit`) is deprecated and should never be used for new applications.

2. **`RequireClientSecret = false`** — SPAs run in the browser and cannot securely store a client secret. This makes it a public client.

3. **`AllowedCorsOrigins`** — Required for browser-based clients so the SPA can make cross-origin requests to the token endpoint and other IdentityServer endpoints. IdentityServer's built-in CORS policy service uses this property automatically.

4. **`AllowOfflineAccess = true`** — Enables refresh token issuance. Without this, the client won't receive a refresh token even if it requests the `offline_access` scope.

5. **`AllowedScopes`** — Includes `openid` (mandatory for OIDC), `profile` (user info claims), and the API scope `orders.read`. The `openid` scope is required by the OpenID Connect spec and returns the `sub` claim.

## Program.cs Registration

```csharp
builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients)
    .AddTestUsers(TestUsers.Users);
```
