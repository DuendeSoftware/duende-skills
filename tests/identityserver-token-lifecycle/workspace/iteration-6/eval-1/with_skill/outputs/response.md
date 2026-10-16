Update `web_app`:

```csharp
new Client
{
    ClientId = "web_app",
    ClientName = "Web Application",
    AllowedGrantTypes = GrantTypes.Code,
    ClientSecrets = { new Secret("secret".Sha256()) },
    RedirectUris = { "https://localhost:5002/signin-oidc" },
    PostLogoutRedirectUris = { "https://localhost:5002/signout-callback-oidc" },
    AllowedScopes = { "openid", "profile", "api1", "offline_access" },
    AccessTokenLifetime = 3600,

    AllowOfflineAccess = true,
    RefreshTokenUsage = TokenUsage.ReUse,              // default since v7, set explicitly
    RefreshTokenExpiration = TokenExpiration.Sliding,
    AbsoluteRefreshTokenLifetime = 2592000,            // 30 days
    SlidingRefreshTokenLifetime = 86400                // 1 day
}
```

Key points:
- Two things are needed to get refresh tokens: `AllowOfflineAccess = true` on the client **and** the client requesting the `offline_access` scope (`options.Scope.Add("offline_access")` in the OIDC handler). Forgetting either means no refresh token is issued.
- `Sliding` extends the token's life by 1 day on each use, capped by the 30-day absolute lifetime.
- `ReUse` is robust to network failures (a lost response doesn't strand the client) and avoids extra persisted-grant writes.
- Consider also shortening `AccessTokenLifetime` (5–15 min for JWTs) since refresh tokens now provide longevity.
- If you use the EF operational store, enable `EnableTokenCleanup` so expired refresh tokens don't accumulate.
