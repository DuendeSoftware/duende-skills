## Resilient refresh token service with grace period

### 1. Client: one-time-only refresh tokens

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

### 2. Custom refresh token service

```csharp
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Services;
using Duende.IdentityServer.Stores;
using Duende.IdentityServer.Validation;

public class GracePeriodRefreshTokenService : DefaultRefreshTokenService
{
    private static readonly TimeSpan GracePeriod = TimeSpan.FromSeconds(30);

    public GracePeriodRefreshTokenService(
        IRefreshTokenStore store, IProfileService profile, TimeProvider clock,
        ILogger<DefaultRefreshTokenService> logger)
        : base(store, profile, clock, logger) { }

    protected override Task<bool> AcceptConsumedTokenAsync(RefreshToken refreshToken)
    {
        // Consumed token is still accepted if consumed within the grace window
        if (refreshToken.ConsumedTime.HasValue &&
            Clock.UtcNow - refreshToken.ConsumedTime.Value <= GracePeriod)
        {
            return Task.FromResult(true);
        }
        return base.AcceptConsumedTokenAsync(refreshToken);
    }
}
```

(Constructor parameters vary slightly between IdentityServer versions; match your version's `DefaultRefreshTokenService` constructor. Older versions use `ISystemClock`.)

### 3. Registration and operational store

```csharp
builder.Services.AddIdentityServer()
    // ... existing config ...
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b => b.UseSqlServer(connectionString);
        options.EnableTokenCleanup = true;
        options.TokenCleanupInterval = 3600;
        options.RemoveConsumedTokens = true;
        // Keep consumed tokens longer than the grace period
        options.ConsumedTokenCleanupDelay = 300; // seconds (5 min > 30 s)
    });

builder.Services.AddTransient<IRefreshTokenService, GracePeriodRefreshTokenService>();
```

Register the service after `AddIdentityServer()` so it overrides the default.

Notes:
- `ConsumedTokenCleanupDelay` must exceed the grace period, otherwise the token row may be deleted before the retry arrives.
- Consumed-token retention only works with a persistent store (EF operational store); the in-memory store does not need/perform this cleanup.
- The retried request gets a new refresh token and access token; the client must store the latest refresh token.
- Security: a larger grace window widens the replay window; keep it short.
