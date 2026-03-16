# Resilient Refresh Token Service with Grace Period

Here's how to implement a resilient refresh token service that accepts consumed tokens within a 30-second grace period, along with the necessary configuration changes.

## ResilientRefreshTokenService

```csharp
using Duende.IdentityServer.Services;
using Duende.IdentityServer.Stores;
using Duende.IdentityServer.Models;

public class ResilientRefreshTokenService : DefaultRefreshTokenService
{
    public ResilientRefreshTokenService(
        IRefreshTokenStore refreshTokenStore,
        IProfileService profile,
        IClock clock,
        ILogger<DefaultRefreshTokenService> logger)
        : base(refreshTokenStore, profile, clock, logger)
    {
    }

    protected override Task<bool> AcceptConsumedTokenAsync(RefreshToken refreshToken)
    {
        // Allow consumed tokens within a 30-second grace period
        var consumedAt = refreshToken.ConsumedTime ?? DateTime.UtcNow;
        if (DateTime.UtcNow - consumedAt < TimeSpan.FromSeconds(30))
        {
            return Task.FromResult(true);
        }
        return Task.FromResult(false);
    }
}
```

## Updated Program.cs

```csharp
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Services;
using Microsoft.Extensions.DependencyInjection.Extensions;

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
            AccessTokenLifetime = 3600
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
            RequirePkce = true,
            AllowOfflineAccess = true,

            // One-time use refresh tokens
            RefreshTokenUsage = TokenUsage.OneTimeOnly
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
        // IMPORTANT: Do not delete consumed tokens immediately
        // This is required for the grace period to work
        options.DeleteOneTimeOnlyRefreshTokensOnUse = false;
    });

// Register the resilient refresh token service
builder.Services.TryAddTransient<IRefreshTokenService, ResilientRefreshTokenService>();

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## Key Points

### Why This Is Needed

When using `OneTimeOnly` refresh tokens, the token is consumed (marked as used) on the first use and a new token is issued in the response. But if the network drops during the response, the client:

1. Successfully sent the refresh token request (so the server consumed the old token)
2. Never received the response (so the client doesn't have the new token)
3. The client is stuck — it has a consumed token and no new one

The grace period allows the client to retry with the consumed token within 30 seconds.

### `DeleteOneTimeOnlyRefreshTokensOnUse = false`

By default, consumed one-time-use tokens are **deleted** from the store. Setting `DeleteOneTimeOnlyRefreshTokensOnUse = false` changes the behavior to **mark** tokens as consumed (setting `ConsumedTime`) rather than deleting them. This is essential because:

- If the token is deleted, `AcceptConsumedTokenAsync` is never called (the token doesn't exist)
- If the token is marked as consumed, the grace period logic can check `ConsumedTime` and decide whether to accept it

### `RefreshTokenUsage = TokenUsage.OneTimeOnly`

The `mobile_app` client is configured with `TokenUsage.OneTimeOnly` which means:
- Each refresh token can only be used once
- A new refresh token is issued with each access token refresh
- The old token is consumed (not deleted, thanks to our configuration)
