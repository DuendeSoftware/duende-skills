# Configuring Refresh Tokens for the web_app Client

To enable refresh tokens for the web_app client, you'll need to configure the client to support offline access. Here's how to update the configuration:

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
    
    // Enable offline access for refresh tokens
    AllowOfflineAccess = true,
    
    // Set refresh token lifetimes
    RefreshTokenLifetime = 2592000, // 30 days
    SlidingRefreshTokenLifetime = 86400, // 1 day
    
    // Use sliding expiration
    UseSlidingExpiration = true
}
```

## Changes Made

1. **`AllowOfflineAccess = true`** — Enables the client to receive refresh tokens.

2. **Added `"offline_access"` to `AllowedScopes`** — The client needs to request this scope to get a refresh token.

3. **`RefreshTokenLifetime = 2592000`** — Sets the absolute maximum lifetime to 30 days (30 × 24 × 60 × 60).

4. **`SlidingRefreshTokenLifetime = 86400`** — Sets the sliding window to 1 day.

5. **`UseSlidingExpiration = true`** — Enables sliding expiration, where the token lifetime extends each time it's used.

The ReUse rotation mode should be the default, so you don't need to explicitly set it.
