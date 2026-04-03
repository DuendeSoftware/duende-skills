# Resilient Refresh Token Service for One-Time Use Tokens

To handle network failures during token refresh with one-time use tokens, you need to implement a custom refresh token service that accepts consumed tokens within a grace period, and configure the operational store to retain consumed tokens.

## Custom Refresh Token Service

```csharp
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Services;
using Duende.IdentityServer.Stores;

public class ResilientRefreshTokenService : DefaultRefreshTokenService
{
    public ResilientRefreshTokenService(
        IRefreshTokenStore refreshTokenStore,
        IProfileService profile,
        ISystemClock clock,
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

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
    {
        // CRITICAL: Don't delete consumed tokens on use — mark them instead
        // This allows AcceptConsumedTokenAsync to see the consumed token
        options.PersistentGrants.DeleteOneTimeOnlyRefreshTokensOnUse = false;
    })
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

            // Enable refresh tokens
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
    });

// Register the resilient refresh token service
builder.Services.TryAddTransient<IRefreshTokenService, ResilientRefreshTokenService>();

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## Key Points

1. **`DefaultRefreshTokenService` subclass** — `ResilientRefreshTokenService` extends the built-in service and overrides `AcceptConsumedTokenAsync`.

2. **`AcceptConsumedTokenAsync` with grace period** — The method checks `refreshToken.ConsumedTime` to determine when the token was consumed. If consumption happened within the last 30 seconds, it returns `true` to allow the token to be reused. This handles the case where the client sent a refresh request, the server consumed the token and issued a new one, but the response was lost due to a network error.

3. **`IRefreshTokenService` registration** — The custom service is registered via `builder.Services.TryAddTransient<IRefreshTokenService, ResilientRefreshTokenService>()`.

4. **`RefreshTokenUsage = TokenUsage.OneTimeOnly`** on mobile_app — This enables one-time refresh token rotation for the mobile client.

5. **`DeleteOneTimeOnlyRefreshTokensOnUse = false`** — This is critical. By default, consumed one-time refresh tokens are deleted immediately. Setting this to `false` ensures consumed tokens are marked (with `ConsumedTime`) rather than deleted, so the grace period logic in `AcceptConsumedTokenAsync` can actually see the consumed token.
