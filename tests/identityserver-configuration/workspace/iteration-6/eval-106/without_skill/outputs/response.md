```csharp
new Client
{
    ClientId = "mobile",
    AllowedGrantTypes = GrantTypes.Code,
    RequireClientSecret = false,
    RedirectUris = { "com.example.app:/callback" },
    AllowedScopes = { "openid", "profile", "api1" },
    AllowOfflineAccess = true,

    RefreshTokenUsage = TokenUsage.OneTimeOnly,
    RefreshTokenExpiration = TokenExpiration.Sliding,
    AbsoluteRefreshTokenLifetime = 604800, // 7 days
    SlidingRefreshTokenLifetime = 86400,   // 1 day
    UpdateAccessTokenClaimsOnRefresh = true
}
```
`OneTimeOnly` rotates the token on each use; sliding with an absolute cap gives the 1-day window up to 7 days. `UpdateAccessTokenClaimsOnRefresh` re-runs the profile service for fresh claims. Register with `AddInMemoryClients` and call `UseIdentityServer()`.
