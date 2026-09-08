# Configuring Refresh Tokens for `web_app`

To issue refresh tokens the client must (1) have `AllowOfflineAccess = true` and (2) request the `offline_access` scope — so `offline_access` needs to be in `AllowedScopes` too. You then set the sliding/absolute lifetimes and keep the default `ReUse` rotation.

## What each setting does

| Setting | Value | Meaning |
| --- | --- | --- |
| `AllowOfflineAccess` | `true` | Permits the client to receive refresh tokens |
| `AllowedScopes` += `offline_access` | — | The scope that actually requests the refresh token |
| `RefreshTokenExpiration` | `TokenExpiration.Sliding` | Life extends on each use up to the absolute cap |
| `AbsoluteRefreshTokenLifetime` | `2592000` | 30 days (30 × 24 × 60 × 60) — hard ceiling regardless of activity |
| `SlidingRefreshTokenLifetime` | `86400` | 1 day (24 × 60 × 60) — window that renews on each use |
| `RefreshTokenUsage` | `TokenUsage.ReUse` | Default since v7.0 — same token reused, robust to network failures |

`ReUse` is already the default, but setting it explicitly documents intent.

## Updated `web_app` client

```csharp
new Client
{
    ClientId = "web_app",
    ClientName = "Web Application",
    AllowedGrantTypes = GrantTypes.Code,
    ClientSecrets = { new Secret("secret".Sha256()) },
    RedirectUris = { "https://localhost:5002/signin-oidc" },
    PostLogoutRedirectUris = { "https://localhost:5002/signout-callback-oidc" },

    // Refresh token configuration
    AllowOfflineAccess = true,
    AllowedScopes = { "openid", "profile", "api1", "offline_access" },

    RefreshTokenExpiration = TokenExpiration.Sliding,
    AbsoluteRefreshTokenLifetime = 2592000, // 30 days in seconds
    SlidingRefreshTokenLifetime = 86400,    // 1 day in seconds
    RefreshTokenUsage = TokenUsage.ReUse,   // default (v7.0+), stated explicitly

    AccessTokenLifetime = 3600
}
```

## How the sliding + absolute cap interacts

With `Sliding` expiration, every successful refresh extends the token's life by another `SlidingRefreshTokenLifetime` (1 day), but it can never live past `AbsoluteRefreshTokenLifetime` (30 days) from initial issuance. So an active user stays signed in indefinitely up to the 30-day ceiling, while a user who goes idle for more than a day is forced to re-authenticate.

> Common pitfall: forgetting `offline_access` in `AllowedScopes` — `AllowOfflineAccess = true` alone is not enough; the scope must be both allowed and requested for a refresh token to be issued.
