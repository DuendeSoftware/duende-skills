# Mobile App Refresh Token Configuration

Here's a client configured for rotating refresh tokens with a 7-day absolute lifetime, a 1-day sliding window, and claim updates on refresh.

```csharp
using Duende.IdentityServer.Models;

new Client
{
    ClientId = "mobile-app",

    AllowedGrantTypes = GrantTypes.Code,
    RequireClientSecret = false,
    RequirePkce = true,

    AllowOfflineAccess = true,                       // enable refresh tokens

    RefreshTokenUsage = TokenUsage.OneTimeOnly,      // rotate on each use
    RefreshTokenExpiration = TokenExpiration.Sliding,
    AbsoluteRefreshTokenLifetime = 604800,           // 7 days in seconds
    SlidingRefreshTokenLifetime = 86400,             // 1 day in seconds

    UpdateAccessTokenClaimsOnRefresh = true,         // refresh claims each time

    RedirectUris = { "com.example.app://callback" },

    AllowedScopes = { "openid", "profile", "api1" }
}
```

## Notes

- `AllowOfflineAccess = true` enables refresh tokens.
- `RefreshTokenUsage = TokenUsage.OneTimeOnly` rotates the refresh token on every use — each refresh returns a brand-new token and invalidates the previous one.
- `AbsoluteRefreshTokenLifetime = 604800` sets the hard 7-day maximum.
- `SlidingRefreshTokenLifetime = 86400` with `RefreshTokenExpiration = TokenExpiration.Sliding` gives a 1-day sliding window (bounded by the absolute lifetime).
- `UpdateAccessTokenClaimsOnRefresh = true` re-reads the user's claims so refreshed access tokens stay current.

Because rotation is enabled, the app must always store and send the latest refresh token from each response.
