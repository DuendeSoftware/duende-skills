```csharp
new Client
{
    ClientId = "mobile.app",
    ClientName = "Mobile App",

    AllowedGrantTypes = GrantTypes.Code,
    RequirePkce = true,
    RequireClientSecret = false,   // native public client
    RedirectUris = { "com.example.mobile:/callback" },

    AllowOfflineAccess = true,     // needed to issue refresh tokens

    AllowedScopes = { "openid", "profile", "api1" },

    // Rotation: new handle each use
    RefreshTokenUsage = TokenUsage.OneTimeOnly,

    // Sliding window capped by an absolute lifetime
    RefreshTokenExpiration = TokenExpiration.Sliding,
    AbsoluteRefreshTokenLifetime = 604800,  // 7 days
    SlidingRefreshTokenLifetime  = 86400,   // 1 day

    // Re-run profile service for fresh claims on each refresh
    UpdateAccessTokenClaimsOnRefresh = true
}
```
- Defaults for reference: `RefreshTokenUsage = ReUse`, `RefreshTokenExpiration = Absolute`, absolute 30 days, sliding 15 days; so all four need to be set explicitly.
- With sliding expiration the token's life extends by up to 1 day on each use, but never beyond 7 days from issue.
- `OneTimeOnly` means the client must store the new refresh token each time.
- `AllowOfflineAccess` must be true and the app must request `offline_access`.
