# Resilient Refresh Token Service with Grace Period

When using one-time refresh tokens (`RefreshTokenUsage = TokenUsage.OneTimeOnly`), network failures during token refresh can strand the client: the old token was consumed but the response with the new token was lost. To handle this, subclass `DefaultRefreshTokenService` and implement a grace period.

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

        // Outside grace period — reject (possible replay attack)
        return Task.FromResult(false);
    }
}
```

## Updated Program.cs

```csharp
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Services;

var builder = WebApplication.CreateBuilder(args);

// Register the resilient refresh token service
builder.Services.TryAddTransient<IRefreshTokenService, ResilientRefreshTokenService>();

var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    // CRITICAL: Don't delete consumed tokens — mark them instead
    // This allows the grace period check to work
    options.PersistentGrants.DeleteOneTimeOnlyRefreshTokensOnUse = false;
})
    .AddInMemoryClients(new List<Client>
    {
        // ... other clients ...
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

            // One-time refresh tokens with our resilient service
            AllowOfflineAccess = true,
            RefreshTokenUsage = TokenUsage.OneTimeOnly
        }
    })
    // ... rest of configuration ...
    ;

var app = builder.Build();
app.UseIdentityServer();
app.MapGet("/", () => "IdentityServer is running");
app.Run();
```

## How the Grace Period Works

1. Client uses refresh token → IdentityServer marks it as consumed (sets `ConsumedTime`) and issues a new one
2. Network drops → client never receives the response with the new token
3. Client retries with the **same** (now consumed) refresh token
4. `AcceptConsumedTokenAsync` checks: was it consumed less than 30 seconds ago?
5. Yes → accept it and issue a new token
6. No (more than 30 seconds) → reject as potential replay attack

### Why `DeleteOneTimeOnlyRefreshTokensOnUse = false`?

By default, when a one-time refresh token is used, it's **deleted** from the store immediately. With deletion, there's no consumed token to check during the grace period. Setting this to `false` makes IdentityServer **mark** the token as consumed (setting `ConsumedTime`) instead of deleting it. The token cleanup job will eventually remove these consumed tokens.
