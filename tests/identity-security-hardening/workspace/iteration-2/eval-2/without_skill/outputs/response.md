# Harden the web.app Client

Looking at the `web.app` client, there are several security issues to fix:

## Updated Client Configuration

```csharp
// Interactive web application — hardened
new Client
{
    ClientId = "web.app",
    ClientName = "Main Web Application",
    AllowedGrantTypes = GrantTypes.Code,    // Changed from CodeAndClientCredentials
    RequirePkce = true,                      // Enable PKCE

    ClientSecrets = { new Secret("SuperSecret123".Sha256()) },

    // Use specific URIs instead of wildcards
    RedirectUris = { "https://app.example.com/signin-oidc" },
    PostLogoutRedirectUris = { "https://app.example.com/signout-callback-oidc" },

    AllowedScopes = { "openid", "profile", "email", "catalog.read", "catalog.write" },

    AllowOfflineAccess = true,

    // Reduce token lifetime to 1 hour
    AccessTokenLifetime = 3600,

    // Use one-time refresh tokens
    RefreshTokenUsage = TokenUsage.OneTimeOnly,

    // Switch to absolute expiration
    RefreshTokenExpiration = TokenExpiration.Absolute,
    AbsoluteRefreshTokenLifetime = 86400, // 24 hours

    AllowedCorsOrigins = { "https://app.example.com" }
},
```

## Changes Made

| Issue | Before | After |
|-------|--------|-------|
| Grant type | `CodeAndClientCredentials` | `Code` — web app doesn't need client credentials |
| PKCE | `false` | `true` — protects authorization code exchange |
| Redirect URIs | Wildcards `https://*.example.com/...` | Exact match `https://app.example.com/...` |
| Access token lifetime | 28800 (8 hours) | 3600 (1 hour) |
| Refresh token usage | `ReUse` | `OneTimeOnly` — rotate tokens on each use |
| Refresh token expiration | Sliding / 30 days | Absolute / 24 hours |
