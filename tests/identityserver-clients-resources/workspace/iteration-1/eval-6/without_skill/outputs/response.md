# Refresh Token Configuration for Mobile App

Here's how to configure refresh token behavior for a mobile app client:

```csharp
new Client
{
    ClientId = "mobile-app",
    ClientName = "Mobile Application",

    AllowedGrantTypes = GrantTypes.Code,
    RequireClientSecret = false,
    RequirePkce = true,

    RedirectUris = { "myapp://callback" },

    AllowOfflineAccess = true,

    RefreshTokenUsage = TokenUsage.OneTimeOnly,
    RefreshTokenExpiration = TokenExpiration.Sliding,
    AbsoluteRefreshTokenLifetime = 604800,    // 7 days
    SlidingRefreshTokenLifetime = 86400,       // 1 day

    UpdateAccessTokenClaimsOnRefresh = true,

    AllowedScopes = { "openid", "profile", "api1" }
}
```

## Explanation

- **AllowOfflineAccess = true**: Required to issue refresh tokens.
- **RefreshTokenUsage = OneTimeOnly**: The refresh token is rotated on each use — when a client uses a refresh token, a new one is issued and the old one is invalidated.
- **AbsoluteRefreshTokenLifetime = 604800**: 7 days maximum lifetime.
- **SlidingRefreshTokenLifetime = 86400**: 1 day sliding window, extended on each use.
- **RefreshTokenExpiration = Sliding**: Uses sliding expiration (each use extends the lifetime).
- **UpdateAccessTokenClaimsOnRefresh = true**: Ensures claims are refreshed from the user store on each token refresh.
