# Shortening Token Lifetimes and Configuring Token Cleanup

Here's the updated configuration with security-hardened token lifetimes and operational store token cleanup:

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
            AccessTokenLifetime = 300  // 5 minutes
        },
        new Client
        {
            ClientId = "m2m_client",
            ClientName = "Machine to Machine Client",
            AllowedGrantTypes = GrantTypes.ClientCredentials,
            ClientSecrets = { new Secret("m2m_secret".Sha256()) },
            AllowedScopes = { "api1" },
            AccessTokenLifetime = 600  // 10 minutes
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
            AccessTokenLifetime = 300  // 5 minutes
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
        // Token cleanup configuration
        options.EnableTokenCleanup = true;
        options.TokenCleanupInterval = 1800;       // Run every 30 minutes (in seconds)
        options.RemoveConsumedTokens = true;         // Clean up consumed tokens too
        options.ConsumedTokenCleanupDelay = 300;     // Wait 5 minutes after consumption before cleanup
    });

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## Best Practices Applied

### Token Lifetime Reductions

| Client | Before | After | Rationale |
|--------|--------|-------|-----------|
| web_app | 3600s (1 hour) | 300s (5 min) | JWT access tokens cannot be revoked; short lifetimes limit exposure |
| m2m_client | default (1 hour) | 600s (10 min) | M2M tokens typically don't need long lifetimes |
| mobile_app | default (1 hour) | 300s (5 min) | Mobile tokens are at risk of device theft |

Short-lived JWT access tokens (5-15 minutes) are a security best practice because JWTs cannot be revoked before expiration. Use refresh tokens for long-lived API access.

### Token Cleanup

- **`EnableTokenCleanup = true`**: Enables the background cleanup task for expired and consumed grants
- **`TokenCleanupInterval = 1800`**: Runs cleanup every 30 minutes
- **`RemoveConsumedTokens = true`**: Also cleans up consumed tokens (e.g., used one-time refresh tokens)
- **`ConsumedTokenCleanupDelay = 300`**: Waits 5 minutes after a token is consumed before removing it, which allows for grace period replay detection
