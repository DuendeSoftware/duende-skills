# Hardening the web.app Client — OAuth 2.0 Security BCP (RFC 9700)

The `web.app` client has multiple security issues per RFC 9700. Here's the hardened configuration:

## Issues Found and Fixes

1. **PKCE disabled** (`RequirePkce = false`) — Must be `true` for all authorization code clients
2. **Wildcard redirect URIs** (`https://*.example.com/signin-oidc`) — Must use exact-match fully-qualified URIs
3. **Wrong grant type** (`GrantTypes.CodeAndClientCredentials`) — Interactive clients should use `GrantTypes.Code` only
4. **8-hour access token** (`AccessTokenLifetime = 28800`) — Must be reduced to ≤ 5 minutes (300 seconds)
5. **Refresh token reuse** (`TokenUsage.ReUse`) — Must use `TokenUsage.OneTimeOnly` to prevent replay
6. **Sliding refresh expiration** — Should use `Absolute` with a reasonable lifetime

## Hardened web.app Client

```csharp
new Client
{
    ClientId = "web.app",
    ClientName = "Main Web Application",
    
    // ✅ Authorization code only — never combine with client credentials
    AllowedGrantTypes = GrantTypes.Code,
    
    // ✅ PKCE is non-negotiable for all authorization code clients
    RequirePkce = true,

    // Secret loaded from configuration, not hardcoded
    ClientSecrets = { new Secret(builder.Configuration["ClientSecrets:WebApp"].Sha256()) },

    // ✅ Exact-match fully-qualified HTTPS URIs — no wildcards
    RedirectUris = { "https://app.example.com/signin-oidc" },
    PostLogoutRedirectUris = { "https://app.example.com/signout-callback-oidc" },

    AllowedScopes = { "openid", "profile", "email", "catalog.read", "catalog.write" },

    AllowOfflineAccess = true,
    
    // ✅ Short access token — 5 minutes reduces replay window
    AccessTokenLifetime = 300,
    
    // ✅ Refresh tokens rotate on every use — each use issues a new token
    RefreshTokenUsage = TokenUsage.OneTimeOnly,
    
    // ✅ Absolute expiration — prevents indefinitely-extended sessions
    RefreshTokenExpiration = TokenExpiration.Absolute,
    AbsoluteRefreshTokenLifetime = 86400, // 24 hours
    
    // ✅ Revoke refresh tokens when the user's session ends
    CoordinateLifetimeWithUserSession = true,

    AllowedCorsOrigins = { "https://app.example.com" }
}
```

## Summary of Changes

| Setting | Before (Insecure) | After (Hardened) |
|---------|-------------------|-----------------|
| `AllowedGrantTypes` | `CodeAndClientCredentials` | `Code` |
| `RequirePkce` | `false` | `true` |
| `RedirectUris` | `https://*.example.com/signin-oidc` | `https://app.example.com/signin-oidc` |
| `AccessTokenLifetime` | `28800` (8 hours) | `300` (5 minutes) |
| `RefreshTokenUsage` | `ReUse` | `OneTimeOnly` |
| `RefreshTokenExpiration` | `Sliding` | `Absolute` |
| `AbsoluteRefreshTokenLifetime` | `2592000` (30 days) | `86400` (24 hours) |
| `CoordinateLifetimeWithUserSession` | not set | `true` |
