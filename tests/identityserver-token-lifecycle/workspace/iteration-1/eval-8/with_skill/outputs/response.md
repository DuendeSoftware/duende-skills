# Applying Token Lifetime Best Practices and Configuring Token Cleanup

## Why Shorten Access Token Lifetimes?

JWT access tokens **cannot be revoked** before expiration. A 1-hour lifetime means a leaked token is valid for up to 1 hour. Shorter lifetimes (5-15 minutes) significantly reduce this risk window. Clients use refresh tokens to get new access tokens when needed.

## Updated Program.cs

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
            AllowedScopes = { "openid", "profile", "api1" },

            // 5-minute access token lifetime
            AccessTokenLifetime = 300
        },
        new Client
        {
            ClientId = "m2m_client",
            ClientName = "Machine to Machine Client",
            AllowedGrantTypes = GrantTypes.ClientCredentials,
            ClientSecrets = { new Secret("m2m_secret".Sha256()) },
            AllowedScopes = { "api1" },

            // 10-minute access token lifetime for M2M
            AccessTokenLifetime = 600
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
            RequirePkce = true,

            // 5-minute access token lifetime
            AccessTokenLifetime = 300
        }
    })
    .AddInMemoryApiScopes(new List<ApiScope>
    {
        new ApiScope("api1", "API 1")
    })
    .AddInMemoryApiResources(new List<ApiResource>
    {
        new ApiResource("api1_resource") { Scopes = { "api1" } }
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
    })
    .AddOperationalStore(options =>
    {
        // Token cleanup configuration
        options.EnableTokenCleanup = true;
        options.TokenCleanupInterval = 1800;         // Run every 30 minutes
        options.RemoveConsumedTokens = true;           // Clean up consumed refresh tokens
        options.ConsumedTokenCleanupDelay = 300;       // Wait 5 minutes after consumption before cleanup
    });

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## Token Lifetime Rationale

| Client       | Lifetime | Rationale                                                                                                    |
|-------------|----------|--------------------------------------------------------------------------------------------------------------|
| `web_app`    | 300s (5 min) | Interactive user flow with refresh tokens available. Short lifetime limits exposure from leaked JWTs.       |
| `m2m_client` | 600s (10 min) | Machine-to-machine flow. Slightly longer since there's no user interaction and the client can easily re-request. |
| `mobile_app` | 300s (5 min) | Mobile apps are more susceptible to token theft. Short lifetime combined with refresh tokens is best practice. |

## Token Cleanup Configuration

| Setting                    | Value | Description                                                                |
|---------------------------|-------|----------------------------------------------------------------------------|
| `EnableTokenCleanup`       | `true` | Activates the background cleanup job                                       |
| `TokenCleanupInterval`     | `1800` | Runs every 30 minutes (in seconds)                                         |
| `RemoveConsumedTokens`     | `true` | Cleans up consumed one-time-use refresh tokens                             |
| `ConsumedTokenCleanupDelay`| `300`  | Waits 5 minutes after consumption before removing — allows grace periods   |

The `ConsumedTokenCleanupDelay` is particularly important if you're using one-time refresh tokens with a grace period for network failures. It ensures consumed tokens remain available long enough for retry scenarios before being cleaned up.
