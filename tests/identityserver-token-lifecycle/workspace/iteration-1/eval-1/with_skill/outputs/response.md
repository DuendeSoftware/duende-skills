# Configuring Refresh Tokens for the web_app Client

To enable refresh tokens for your `web_app` client with a 30-day absolute lifetime and 1-day sliding window, you need to modify the client configuration in `Program.cs`.

## Updated Client Configuration

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

    // Refresh token lifetime settings
    RefreshTokenExpiration = TokenExpiration.Sliding,
    AbsoluteRefreshTokenLifetime = 2592000, // 30 days in seconds
    SlidingRefreshTokenLifetime = 86400,     // 1 day in seconds

    // Keep ReUse rotation as requested
    RefreshTokenUsage = TokenUsage.ReUse
}
```

## Key Changes Explained

1. **`AllowOfflineAccess = true`** — This is the primary switch that enables the client to request refresh tokens. Without this, the token endpoint will not issue refresh tokens regardless of scope requests.

2. **`offline_access` in `AllowedScopes`** — The client must include this scope in its authorization request. Adding it to `AllowedScopes` ensures the client is permitted to request it.

3. **`RefreshTokenExpiration = TokenExpiration.Sliding`** — With sliding expiration, each time the refresh token is used, its lifetime is extended by the sliding window duration (up to the absolute maximum).

4. **`AbsoluteRefreshTokenLifetime = 2592000`** — This is the hard cap: 30 days × 24 hours × 60 minutes × 60 seconds = 2,592,000 seconds. After 30 days from issuance, the refresh token expires no matter how recently it was used.

5. **`SlidingRefreshTokenLifetime = 86400`** — Each time the refresh token is used, it remains valid for another 24 hours (86,400 seconds), but never beyond the absolute lifetime.

6. **`RefreshTokenUsage = TokenUsage.ReUse`** — The same refresh token value is reused on each refresh. This is the default in Duende IdentityServer v7.0+ and is more resilient to network failures than `OneTime` rotation. With `ReUse`, if a network interruption occurs during token refresh, the client can simply retry with the same refresh token.

## How It Works in Practice

- User authenticates → client receives access token + refresh token
- Access token expires after 1 hour (3600s)
- Client uses refresh token to get a new access token
- Sliding window extends: refresh token valid for another 24 hours
- After 30 days from original issuance, user must re-authenticate regardless of activity
