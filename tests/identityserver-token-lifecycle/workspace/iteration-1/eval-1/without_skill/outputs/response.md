# Configuring Refresh Tokens for the web_app Client

To enable refresh tokens for your `web_app` client with the specified lifetimes, you need to update the client configuration in `Program.cs`:

```csharp
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer()
    .AddInMemoryClients(new List<Client>
    {
        new Client
        {
            ClientId = "web_app",
            ClientName = "Web Application",
            AllowedGrantTypes = GrantTypes.Code,
            ClientSecrets = { new Secret("secret".Sha256()) },
            RedirectUris = { "https://localhost:5002/signin-oidc" },
            PostLogoutRedirectUris = { "https://localhost:5002/signout-callback-oidc" },
            AllowedScopes = { "openid", "profile", "api1", "offline_access" },
            AccessTokenLifetime = 3600,

            // Enable refresh tokens
            AllowOfflineAccess = true,

            // Refresh token settings
            RefreshTokenExpiration = TokenExpiration.Sliding,
            AbsoluteRefreshTokenLifetime = 2592000, // 30 days
            SlidingRefreshTokenLifetime = 86400,     // 1 day

            // Reuse mode
            RefreshTokenUsage = TokenUsage.ReUse
        },
        new Client
        {
            ClientId = "m2m_client",
            ClientName = "Machine to Machine Client",
            AllowedGrantTypes = GrantTypes.ClientCredentials,
            ClientSecrets = { new Secret("m2m_secret".Sha256()) },
            AllowedScopes = { "api1" }
        },
        new Client
        {
            ClientId = "mobile_app",
            ClientName = "Mobile Application",
            AllowedGrantTypes = GrantTypes.Code,
            RequireClientSecret = false,
            RedirectUris = { "myapp://callback" },
            PostLogoutRedirectUris = { "myapp://signout" },
            AllowedScopes = { "openid", "profile", "api1" },
            RequirePkce = true
        }
    })
    .AddInMemoryApiScopes(new List<ApiScope>
    {
        new ApiScope("api1", "API 1")
    })
    .AddInMemoryApiResources(new List<ApiResource>
    {
        new ApiResource("api1_resource")
        {
            Scopes = { "api1" }
        }
    })
    .AddInMemoryIdentityResources(new List<IdentityResource>
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile()
    })
    .AddTestUsers(new List<Duende.IdentityServer.Test.TestUser>
    {
        new Duende.IdentityServer.Test.TestUser
        {
            SubjectId = "1",
            Username = "alice",
            Password = "password"
        }
    });

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## What Changed

- **`AllowOfflineAccess = true`** — Required for the server to issue refresh tokens.
- **`offline_access` scope** — Added to `AllowedScopes` so the client can request it.
- **`RefreshTokenExpiration = TokenExpiration.Sliding`** — Enables sliding window expiration.
- **`AbsoluteRefreshTokenLifetime = 2592000`** — 30 days maximum lifetime.
- **`SlidingRefreshTokenLifetime = 86400`** — 1 day sliding window.
- **`RefreshTokenUsage = TokenUsage.ReUse`** — Same refresh token is reused across requests.

The client must request the `offline_access` scope during the authorization request to receive a refresh token.
