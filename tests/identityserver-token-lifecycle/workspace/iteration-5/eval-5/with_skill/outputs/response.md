# Resilient Refresh Tokens for `mobile_app` (One-Time Use + Grace Period)

With one-time-use refresh tokens, the server consumes the old token the moment it issues a new one. If the network drops before the client receives the response, the client is stuck with a token that's already been consumed and must force a new login. The fix is to **accept a consumed token for a short grace window**, and to make sure the store **marks** consumed tokens rather than **deleting** them (otherwise there's nothing left to accept).

## 1. Subclass `DefaultRefreshTokenService`

```csharp
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Services;

public class ResilientRefreshTokenService : DefaultRefreshTokenService
{
    public ResilientRefreshTokenService(
        IRefreshTokenStore refreshTokenStore,
        IProfileService profile,
        IClock clock,
        IServerUrls urls,
        ILogger<DefaultRefreshTokenService> logger)
        : base(refreshTokenStore, profile, clock, urls, logger)
    {
    }

    protected override Task<bool> AcceptConsumedTokenAsync(RefreshToken refreshToken)
    {
        // Allow a consumed token to be reused within a 30-second grace period
        var consumedAt = refreshToken.ConsumedTime ?? DateTime.UtcNow;
        if (DateTime.UtcNow - consumedAt < TimeSpan.FromSeconds(30))
        {
            return Task.FromResult(true);
        }

        return Task.FromResult(false);
    }
}
```

The key is `RefreshToken.ConsumedTime`: when a one-time token is used it is stamped with a consumption time instead of being immediately removed. We compare "now" against that timestamp and accept the token if it's within 30 seconds.

## 2. Register it as `IRefreshTokenService`

```csharp
builder.Services.TryAddTransient<IRefreshTokenService, ResilientRefreshTokenService>();
```

(Requires `using Microsoft.Extensions.DependencyInjection.Extensions;`.)

## 3. Configure `mobile_app` for one-time-use rotation

```csharp
new Client
{
    ClientId = "mobile_app",
    ClientName = "Mobile Application",
    AllowedGrantTypes = GrantTypes.Code,
    RequireClientSecret = false,
    RedirectUris = { "myapp://callback" },
    PostLogoutRedirectUris = { "myapp://signout" },
    AllowedScopes = { "openid", "profile", "api1", "offline_access" },
    RequirePkce = true,

    AllowOfflineAccess = true,
    RefreshTokenUsage = TokenUsage.OneTimeOnly // rotate on each use
}
```

## 4. Keep consumed tokens instead of deleting them

For the grace period to work, consumed one-time tokens must be marked (given a `ConsumedTime`) rather than deleted on use. That's controlled by `PersistentGrantOptions.DeleteOneTimeOnlyRefreshTokensOnUse`:

```csharp
builder.Services.AddIdentityServer(options =>
{
    // Mark consumed tokens instead of deleting them immediately,
    // so AcceptConsumedTokenAsync has something to inspect.
    options.PersistentGrants.DeleteOneTimeOnlyRefreshTokensOnUse = false;
});
```

> Without setting `DeleteOneTimeOnlyRefreshTokensOnUse = false`, the consumed token is gone the instant it's used and the grace-period logic can never run. You can later reclaim these rows via the operational store's token cleanup (`RemoveConsumedTokens` + `ConsumedTokenCleanupDelay`).
