# Handling Network Failures with One-Time Refresh Tokens

When using one-time refresh tokens, network failures can cause problems because the old token gets consumed but the client doesn't receive the new one. Here's how to add a grace period.

## Custom Refresh Token Service

```csharp
using Duende.IdentityServer.Services;
using Duende.IdentityServer.Models;

public class GracefulRefreshTokenService : DefaultRefreshTokenService
{
    public GracefulRefreshTokenService(
        IRefreshTokenStore refreshTokenStore,
        IProfileService profile,
        IClock clock,
        ILogger<DefaultRefreshTokenService> logger)
        : base(refreshTokenStore, profile, clock, logger)
    {
    }

    protected override Task<bool> AcceptConsumedTokenAsync(RefreshToken refreshToken)
    {
        // Allow consumed tokens within 30 seconds
        if (refreshToken.ConsumedTime.HasValue)
        {
            var elapsed = DateTime.UtcNow - refreshToken.ConsumedTime.Value;
            if (elapsed < TimeSpan.FromSeconds(30))
            {
                return Task.FromResult(true);
            }
        }
        return Task.FromResult(false);
    }
}
```

Register it:

```csharp
builder.Services.AddTransient<IRefreshTokenService, GracefulRefreshTokenService>();
```

Configure the mobile client:

```csharp
new Client
{
    ClientId = "mobile_app",
    // ... existing config ...
    AllowOfflineAccess = true,
    RefreshTokenUsage = TokenUsage.OneTimeOnly
}
```

This allows retries within a 30-second window if the network drops during refresh.
