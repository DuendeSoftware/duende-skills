# Enabling Refresh Tokens for web_app Client

To allow your `web_app` client to use refresh tokens, you need to update the client configuration to support offline access.

## Updated Configuration

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

    // Set refresh token lifetimes
    AbsoluteRefreshTokenLifetime = 2592000, // 30 days
    SlidingRefreshTokenLifetime = 86400,     // 1 day

    // Use sliding expiration
    RefreshTokenExpiration = TokenExpiration.Sliding,

    // ReUse mode — same token reused
    RefreshTokenUsage = TokenUsage.ReUse
}
```

## What This Does

- `AllowOfflineAccess = true` enables the server to issue refresh tokens for this client
- `offline_access` scope must be in the allowed scopes so the client can request it
- Sliding expiration means each use extends the token's lifetime by the sliding window
- The absolute lifetime of 30 days provides a hard cap
- `ReUse` keeps the same refresh token value across refreshes
