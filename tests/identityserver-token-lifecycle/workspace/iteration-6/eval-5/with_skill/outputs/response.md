## 1. Client: one-time refresh tokens

```csharp
new Client
{
    ClientId = "mobile_app",
    // ...
    AllowedScopes = { "openid", "profile", "api1", "offline_access" },
    AllowOfflineAccess = true,
    RefreshTokenUsage = TokenUsage.OneTimeOnly
}
```

(Note: `ReUse` is the default since v7 and is itself robust to network failures. Keep OneTime only if you need rotation; the grace period below makes it tolerable.)

## 2. Resilient refresh token service

```csharp
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Services;

public class ResilientRefreshTokenService : DefaultRefreshTokenService
{
    private static readonly TimeSpan GracePeriod = TimeSpan.FromSeconds(30);

    public ResilientRefreshTokenService(
        IRefreshTokenStore refreshTokenStore, IProfileService profile,
        TimeProvider clock, IPersistentGrantOptions? options /* match your version's ctor */,
        ILogger<DefaultRefreshTokenService> logger)
        : base(refreshTokenStore, profile, clock, options, logger) { }

    protected override Task<bool> AcceptConsumedTokenAsync(RefreshToken refreshToken)
    {
        if (refreshToken.ConsumedTime.HasValue &&
            DateTime.UtcNow - refreshToken.ConsumedTime.Value < GracePeriod)
        {
            return Task.FromResult(true);   // within grace: network retry
        }
        return Task.FromResult(false);
    }
}
```

(The base constructor signature differs across versions; copy your version's.)

Register it:

```csharp
builder.Services.TryAddTransient<IRefreshTokenService, ResilientRefreshTokenService>();
```

Call it after `AddIdentityServer()`'s registrations are in place, or use `AddTransient` if the default is registered first and `TryAdd` doesn't override it.

## 3. Don't delete consumed tokens immediately

```csharp
builder.Services.AddIdentityServer(options =>
    {
        // consumed one-time tokens are marked consumed, not deleted
    })
    // ...
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b => b.UseSqlServer(connectionString);
        options.EnableTokenCleanup = true;
        options.TokenCleanupInterval = 3600;
        options.RemoveConsumedTokens = true;
        options.ConsumedTokenCleanupDelay = 300;   // keep consumed tokens 5 min, > 30s grace
    });

builder.Services.Configure<PersistentGrantOptions>(o =>
    o.DeleteOneTimeOnlyRefreshTokensOnUse = false);
```

`PersistentGrantOptions.DeleteOneTimeOnlyRefreshTokensOnUse` **must** be `false` so consumed tokens remain (marked with `ConsumedTime`); otherwise the grace check never sees them. `ConsumedTokenCleanupDelay` must exceed the grace period.

## Replay detection

A consumed token presented after the grace period may indicate theft. In `AcceptConsumedTokenAsync` you can revoke the user's grants, but this is disruptive and may false-positive on network errors, so just return `false` unless you want that.
