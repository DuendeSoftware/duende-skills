# Mobile App Refresh Token Configuration

```csharp
new Client
{
    ClientId = "mobile-app",
    AllowedGrantTypes = GrantTypes.Code,
    RequireClientSecret = false,
    RequirePkce = true,
    RedirectUris = { "myapp://callback" },
    AllowOfflineAccess = true,
    RefreshTokenUsage = TokenUsage.OneTimeOnly,
    AbsoluteRefreshTokenLifetime = 604800,
    SlidingRefreshTokenLifetime = 86400,
    RefreshTokenExpiration = TokenExpiration.Sliding,
    UpdateAccessTokenClaimsOnRefresh = true,
    AllowedScopes = { "openid", "profile", "api1" }
}
```

This configures one-time-use refresh tokens with a 7-day absolute lifetime and 1-day sliding window. Claims are refreshed on each token renewal.
