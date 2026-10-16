Update the `web_app` client: enable offline access, add the `offline_access` scope, and set sliding refresh token expiration with `ReUse` usage.

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

    AllowOfflineAccess = true,                       // lets the client request refresh tokens
    RefreshTokenUsage = TokenUsage.ReUse,            // default: same handle reused
    RefreshTokenExpiration = TokenExpiration.Sliding,
    AbsoluteRefreshTokenLifetime = 30 * 24 * 60 * 60, // 2,592,000 s = 30 days hard cap
    SlidingRefreshTokenLifetime = 24 * 60 * 60        // 86,400 s = 1 day, extended on each use
}
```

Notes:
- `AllowOfflineAccess = true` and the `offline_access` scope are both required; the client must also request `offline_access` (in ASP.NET Core OIDC: `options.Scope.Add("offline_access"); options.SaveTokens = true;`).
- With sliding expiration, each refresh extends the lifetime by 1 day but never past the 30-day absolute limit.
- `ReUse` is the default; I set it explicitly for clarity. Be aware ReUse is less secure than `OneTimeOnly` (a stolen token stays usable until expiry), so keep the access token short-lived.
- Other clients are unchanged.
