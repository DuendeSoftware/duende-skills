# Configuring Refresh Tokens for the web_app Client

To enable refresh tokens with a 30-day absolute lifetime, 1-day sliding window, and ReUse rotation, you need to update the `web_app` client configuration in `Program.cs`.

Here's the updated client:

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

    // Enable refresh tokens
    AllowOfflineAccess = true,

    // Sliding expiration with absolute cap
    RefreshTokenExpiration = TokenExpiration.Sliding,
    AbsoluteRefreshTokenLifetime = 2592000, // 30 days in seconds
    SlidingRefreshTokenLifetime = 86400,     // 1 day in seconds

    // ReUse rotation (default since v7.0)
    RefreshTokenUsage = TokenUsage.ReUse
}
```

## Key Changes

1. **`AllowOfflineAccess = true`** — This is required for the client to be able to request refresh tokens. Without this, no refresh token will be issued even if `offline_access` is requested.

2. **`"offline_access"` added to `AllowedScopes`** — The client must include this scope in the authorize request to receive a refresh token.

3. **`RefreshTokenExpiration = TokenExpiration.Sliding`** — Configures sliding expiration, meaning the refresh token lifetime extends each time it's used, up to the absolute limit.

4. **`AbsoluteRefreshTokenLifetime = 2592000`** — Sets the maximum lifetime to 30 days (30 × 24 × 60 × 60 = 2,592,000 seconds). Regardless of sliding window activity, the token expires after this period.

5. **`SlidingRefreshTokenLifetime = 86400`** — Sets the sliding window to 1 day (24 × 60 × 60 = 86,400 seconds). Each time the refresh token is used, its expiration extends by 1 day (up to the absolute limit).

6. **`RefreshTokenUsage = TokenUsage.ReUse`** — Keeps the default ReUse rotation mode. The same refresh token is reused across requests, which is robust to network failures and reduces database writes.
