# Handling Refresh Failures with One-Time Refresh Tokens

When you use one-time (rotating) refresh tokens, the old token is consumed as soon as a new one is issued. If the network drops before the client gets the response, the client retries with a token that's now consumed and fails. A common mitigation is to allow a consumed token to be reused for a very short grace window.

## Custom refresh token service

Duende exposes `DefaultRefreshTokenService`, which you can subclass and override the method that decides whether a consumed token is acceptable:

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
        // Accept a consumed token if it was consumed within the last 30 seconds
        if (refreshToken.ConsumedTime.HasValue &&
            DateTime.UtcNow - refreshToken.ConsumedTime.Value < TimeSpan.FromSeconds(30))
        {
            return Task.FromResult(true);
        }

        return Task.FromResult(false);
    }
}
```

Register it in DI:

```csharp
builder.Services.AddTransient<IRefreshTokenService, ResilientRefreshTokenService>();
```

## Client configuration

Make sure `mobile_app` is configured for one-time refresh tokens:

```csharp
new Client
{
    ClientId = "mobile_app",
    // ... existing settings ...
    AllowOfflineAccess = true,
    AllowedScopes = { "openid", "profile", "api1", "offline_access" },
    RefreshTokenUsage = TokenUsage.OneTimeOnly
}
```

## Don't delete consumed tokens immediately

For the grace period to be meaningful, consumed tokens must stick around long enough to be reused. Configure the operational store so consumed tokens aren't cleaned up right away — set a cleanup delay and keep `RemoveConsumedTokens` from wiping them instantly:

```csharp
builder.Services.AddIdentityServer()
    .AddOperationalStore(options =>
    {
        options.EnableTokenCleanup = true;
        options.RemoveConsumedTokens = false;      // don't remove consumed tokens immediately
        options.ConsumedTokenCleanupDelay = 300;   // if enabled, wait before cleaning up
    });
```

This way a token consumed during a failed refresh is still present for the 30-second window your custom service allows.
