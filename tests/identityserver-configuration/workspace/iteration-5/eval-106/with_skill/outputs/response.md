# Mobile App Refresh Token Configuration

This client rotates refresh tokens on every use (one-time only), has a 7-day absolute cap, a 1-day sliding window, and updates the access token claims on each refresh.

```csharp
using Duende.IdentityServer.Models;

new Client
{
    ClientId = "mobile-app",
    ClientName = "Mobile App",

    AllowedGrantTypes = GrantTypes.Code,
    RequireClientSecret = false, // native/public client
    RequirePkce = true,

    // Enable refresh tokens
    AllowOfflineAccess = true,

    // One-time use — a new refresh token is issued on every refresh (rotation)
    RefreshTokenUsage = TokenUsage.OneTimeOnly,

    // Absolute cap: 7 days (in seconds)
    AbsoluteRefreshTokenLifetime = 604800,   // 7 * 24 * 60 * 60

    // Sliding window: 1 day (in seconds)
    SlidingRefreshTokenLifetime = 86400,     // 24 * 60 * 60
    RefreshTokenExpiration = TokenExpiration.Sliding,

    // Refresh the access token's claims on each refresh
    UpdateAccessTokenClaimsOnRefresh = true,

    RedirectUris = { "com.example.mobile://callback" },

    AllowedScopes =
    {
        IdentityServerConstants.StandardScopes.OpenId,
        IdentityServerConstants.StandardScopes.Profile,
        "api1"
    }
}
```

## Notes

- **`AllowOfflineAccess = true`** is what allows refresh tokens to be issued at all (the client must also request `offline_access`).
- **`RefreshTokenUsage = TokenUsage.OneTimeOnly`** rotates the refresh token: each refresh consumes the old handle and issues a new one. This is the recommended, more secure setting (the alternative is `ReUse`).
- **`AbsoluteRefreshTokenLifetime = 604800`** — the hard 7-day ceiling; after this the refresh token expires no matter how recently it was used.
- **`SlidingRefreshTokenLifetime = 86400` + `RefreshTokenExpiration = TokenExpiration.Sliding`** — the token stays valid as long as it's used within any 1-day window, but never beyond the 7-day absolute lifetime. Both the sliding value **and** setting the expiration mode to `Sliding` are required for the sliding window to take effect.
- **`UpdateAccessTokenClaimsOnRefresh = true`** — re-reads the user's claims from the profile service on each refresh so the new access token reflects current claim values.

> With `OneTimeOnly` rotation, the mobile client must always persist and use the newest refresh token returned from each token response; replaying a consumed token will fail (and can trigger reuse-detection).
