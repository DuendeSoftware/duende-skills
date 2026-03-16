# Configuring Refresh Tokens for the web_app Client

To enable refresh tokens for the `web_app` client with a 30-day absolute lifetime and 1-day sliding window, you need to update the client configuration. Here's the modified `Program.cs`:

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

            // Refresh token lifetime settings
            RefreshTokenExpiration = TokenExpiration.Sliding,
            AbsoluteRefreshTokenLifetime = 2592000, // 30 days in seconds
            SlidingRefreshTokenLifetime = 86400,     // 1 day in seconds

            // Keep default ReUse rotation
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

## Key Changes

1. **`AllowOfflineAccess = true`** — This is required for the client to be able to request refresh tokens. Without this, IdentityServer will not issue refresh tokens regardless of the scopes requested.

2. **`"offline_access"` added to `AllowedScopes`** — The client must also request the `offline_access` scope in the authorization request. Adding it to `AllowedScopes` allows the client to request this scope.

3. **`RefreshTokenExpiration = TokenExpiration.Sliding`** — This configures sliding expiration, meaning the refresh token lifetime is extended each time it's used, up to the absolute maximum.

4. **`AbsoluteRefreshTokenLifetime = 2592000`** — 30 days in seconds (30 × 24 × 60 × 60 = 2,592,000). This is the maximum lifetime regardless of activity.

5. **`SlidingRefreshTokenLifetime = 86400`** — 1 day in seconds (24 × 60 × 60 = 86,400). Each time the refresh token is used, its expiration is extended by this amount, but never beyond the absolute lifetime.

6. **`RefreshTokenUsage = TokenUsage.ReUse`** — This is actually the default since Duende IdentityServer v7.0. The same refresh token is reused across requests, which is robust to network failures. With `OneTime`, a new refresh token is issued on each use and the old one is consumed — but if the response is lost, the client cannot recover without forcing a new login.

## How It Works

With sliding expiration:
- When the user first authenticates, a refresh token is issued valid for 1 day (sliding) up to 30 days (absolute).
- Each time the client uses the refresh token, its expiration is extended by another 1 day.
- If the user is inactive for more than 1 day, the refresh token expires.
- After 30 days, the refresh token expires regardless of activity, and the user must re-authenticate.
