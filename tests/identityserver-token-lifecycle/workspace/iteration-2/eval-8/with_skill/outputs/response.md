# Shortening Access Token Lifetimes and Configuring Token Cleanup

Here's how to apply security best practices for token lifetimes and configure operational store cleanup.

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

            // Shortened from 3600 (1 hour) to 300 (5 minutes)
            AccessTokenLifetime = 300
        },
        new Client
        {
            ClientId = "m2m_client",
            ClientName = "Machine to Machine Client",
            AllowedGrantTypes = GrantTypes.ClientCredentials,
            ClientSecrets = { new Secret("m2m_secret".Sha256()) },
            AllowedScopes = { "api1" },

            // 10 minutes for machine-to-machine
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

            // 5 minutes for mobile app
            AccessTokenLifetime = 300
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
    })
    .AddOperationalStore(options =>
    {
        // Enable automatic token cleanup
        options.EnableTokenCleanup = true;

        // Run cleanup every 30 minutes (1800 seconds)
        options.TokenCleanupInterval = 1800;

        // Also clean up consumed refresh tokens
        options.RemoveConsumedTokens = true;

        // Wait 5 minutes after consumption before deleting
        options.ConsumedTokenCleanupDelay = 300;
    });

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## Key Changes

### Access Token Lifetimes

| Client       | Before   | After   | Rationale                                              |
| ------------ | -------- | ------- | ------------------------------------------------------ |
| `web_app`    | 3600 (1h)| 300 (5m)| JWT tokens can't be revoked; keep short                |
| `m2m_client` | default  | 600 (10m)| M2M clients can more easily refresh; slightly longer  |
| `mobile_app` | default  | 300 (5m)| Mobile apps should use refresh tokens for longevity    |

### Token Cleanup Configuration

- **`EnableTokenCleanup = true`** — Activates the background cleanup job for expired and consumed tokens in the operational store.
- **`TokenCleanupInterval = 1800`** — Runs cleanup every 30 minutes (1800 seconds).
- **`RemoveConsumedTokens = true`** — Also removes consumed (used) refresh tokens during cleanup, not just expired ones.
- **`ConsumedTokenCleanupDelay = 300`** — Waits 5 minutes (300 seconds) after a token is consumed before deleting it. This provides a grace period for any in-flight operations that might still reference the consumed token.

### Why Short Lifetimes Matter

JWT access tokens cannot be revoked before their expiration. A 1-hour JWT means a compromised token grants access for up to 1 hour. By reducing to 5-10 minutes, you dramatically limit the window of exposure. Clients that need persistent access should use refresh tokens to obtain new short-lived access tokens transparently.
