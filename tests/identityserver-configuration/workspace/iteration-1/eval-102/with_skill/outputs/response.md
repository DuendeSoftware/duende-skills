# React SPA Client Configuration

For a SPA client, the key difference is that it's a **public client** (no client secret) since the JavaScript code can't securely store a secret:

```csharp
var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    options.Events.RaiseErrorEvents = true;
    options.Events.RaiseInformationEvents = true;
    options.Events.RaiseFailureEvents = true;
    options.Events.RaiseSuccessEvents = true;
})
    .AddInMemoryIdentityResources(new IdentityResource[]
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile()
    })
    .AddInMemoryApiScopes(new ApiScope[]
    {
        new ApiScope("orders.read", "Read orders")
    })
    .AddInMemoryClients(new Client[]
    {
        new Client
        {
            ClientId = "react-spa",
            ClientName = "React SPA",

            AllowedGrantTypes = GrantTypes.Code,
            RequirePkce = true,                // Default, but explicit for clarity
            RequireClientSecret = false,        // Public client - SPA can't hold a secret

            RedirectUris = { "https://spa.myapp.com/callback" },
            PostLogoutRedirectUris = { "https://spa.myapp.com/" },

            AllowedCorsOrigins = { "https://spa.myapp.com" },

            AllowOfflineAccess = true,          // Enable refresh tokens

            AllowedScopes =
            {
                IdentityServerConstants.StandardScopes.OpenId,
                IdentityServerConstants.StandardScopes.Profile,
                "orders.read"
            }
        }
    });
```

## Key Configuration Choices

### Public Client (RequireClientSecret = false)

SPAs run entirely in the browser and can't securely store a client secret. Setting `RequireClientSecret = false` makes this a public client that authenticates using PKCE alone.

### Authorization Code + PKCE

`GrantTypes.Code` with `RequirePkce = true` (the default) is the only recommended flow for SPAs. Never use the implicit flow for new applications.

### CORS Origins

`AllowedCorsOrigins` must include the SPA's origin (`https://spa.myapp.com`). Without this, the SPA's JavaScript requests to the token endpoint will be blocked by the browser's CORS policy.

### Refresh Tokens

`AllowOfflineAccess = true` enables refresh tokens. For a SPA, this allows the app to silently refresh access tokens without redirecting the user. Consider also setting:

```csharp
RefreshTokenUsage = TokenUsage.OneTimeOnly,  // Rotate on each use
RefreshTokenExpiration = TokenExpiration.Sliding,
SlidingRefreshTokenLifetime = 900,           // 15 minutes
AbsoluteRefreshTokenLifetime = 3600          // 1 hour max
```

### BFF Pattern Recommendation

For production SPAs, consider using the Backend-for-Frontend (BFF) pattern instead of having the SPA handle tokens directly. The BFF acts as a confidential client, keeping tokens on the server side. See the `duende-bff` skill for details.
