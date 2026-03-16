# Resilient Refresh Token Handling

To handle network failures during token refresh with one-time-use tokens, you can implement a custom service that accepts recently-consumed tokens.

## Custom Refresh Token Service

```csharp
using Duende.IdentityServer.Services;
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
        // Accept consumed tokens within a 30-second window
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

## Registration and Configuration

```csharp
// Register the custom service
builder.Services.AddTransient<IRefreshTokenService, ResilientRefreshTokenService>();
```

For the mobile_app client, make sure refresh tokens are configured:

```csharp
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
    RefreshTokenUsage = TokenUsage.OneTimeOnly
}
```

You should also ensure that consumed tokens are not immediately deleted so the grace period check works. Configure the operational store settings accordingly.
