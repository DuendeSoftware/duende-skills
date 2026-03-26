# Hardening the web.app Client — OAuth 2.0 Security BCP (RFC 9700)

## Issues Found

1. **PKCE disabled** (`RequirePkce = false`) — authorization code interception attack
2. **Wildcard redirect URIs** (`https://*.example.com/...`) — open redirector
3. **Mixed grant types** (`GrantTypes.CodeAndClientCredentials`) — violates least privilege
4. **8-hour access tokens** (`AccessTokenLifetime = 28800`) — massive replay window
5. **Refresh token reuse** (`TokenUsage.ReUse`) — stolen refresh tokens remain valid

## Hardened Client Configuration

```csharp
new Client
{
    ClientId = "web.app",
    ClientName = "Main Web Application",

    // Use authorization code only — no client credentials mixed in
    AllowedGrantTypes = GrantTypes.Code,

    // PKCE is mandatory for all authorization code clients (RFC 9700)
    RequirePkce = true,

    ClientSecrets = { new Secret(builder.Configuration["ClientSecrets:WebApp"].Sha256()) },

    // Exact-match redirect URIs — no wildcards
    RedirectUris = { "https://app.example.com/signin-oidc" },
    PostLogoutRedirectUris = { "https://app.example.com/signout-callback-oidc" },

    AllowedScopes = { "openid", "profile", "email", "catalog.read", "catalog.write" },

    AllowOfflineAccess = true,

    // Short access token — 5 minutes reduces replay window
    AccessTokenLifetime = 300,

    // One-time refresh tokens — each use issues a new token
    RefreshTokenUsage = TokenUsage.OneTimeOnly,

    // Absolute expiration — session cannot extend indefinitely
    RefreshTokenExpiration = TokenExpiration.Absolute,
    AbsoluteRefreshTokenLifetime = 86400, // 24 hours

    // Revoke tokens when user session ends
    CoordinateLifetimeWithUserSession = true,

    AllowedCorsOrigins = { "https://app.example.com" }
}
```

## Changes Summary

| Setting | Before | After | RFC 9700 Requirement |
|---------|--------|-------|---------------------|
| `RequirePkce` | `false` | `true` | Section 2.1.1 — PKCE required |
| `RedirectUris` | `https://*.example.com/...` | `https://app.example.com/signin-oidc` | Section 2.3 — exact match |
| `AllowedGrantTypes` | `CodeAndClientCredentials` | `Code` | Least privilege |
| `AccessTokenLifetime` | `28800` (8h) | `300` (5min) | Section 2.2 — short-lived |
| `RefreshTokenUsage` | `ReUse` | `OneTimeOnly` | Section 2.2.2 — rotation |
| `RefreshTokenExpiration` | `Sliding` | `Absolute` | Prevents indefinite sessions |
