# Refresh Token Configuration for Mobile App

Here's the client configuration with the specified refresh token behavior.

```csharp
new Client
{
    ClientId = "mobile-app",
    ClientName = "Mobile Application",

    AllowedGrantTypes = GrantTypes.Code,
    RequireClientSecret = false,  // Mobile apps are public clients
    RequirePkce = true,

    RedirectUris = { "myapp://callback" },

    // Enable refresh tokens
    AllowOfflineAccess = true,

    // Refresh token rotation — new token issued on each use, old one invalidated
    RefreshTokenUsage = TokenUsage.OneTimeOnly,

    // Sliding expiration with absolute cap
    RefreshTokenExpiration = TokenExpiration.Sliding,
    AbsoluteRefreshTokenLifetime = 604800,    // 7 days (7 * 24 * 60 * 60)
    SlidingRefreshTokenLifetime = 86400,       // 1 day  (24 * 60 * 60)

    // Update claims in new access tokens on each refresh
    UpdateAccessTokenClaimsOnRefresh = true,

    AllowedScopes =
    {
        IdentityServerConstants.StandardScopes.OpenId,
        IdentityServerConstants.StandardScopes.Profile,
        "api1"
    }
}
```

## Configuration Breakdown

| Property | Value | Purpose |
|----------|-------|---------|
| `AllowOfflineAccess` | `true` | Enables refresh token issuance. Without this, no refresh token is returned. |
| `RefreshTokenUsage` | `TokenUsage.OneTimeOnly` | Each time the refresh token is used, a new one is issued and the old one is invalidated. This prevents replay attacks. |
| `RefreshTokenExpiration` | `TokenExpiration.Sliding` | The refresh token's expiration slides forward on each use. |
| `AbsoluteRefreshTokenLifetime` | `604800` (7 days) | Maximum lifetime regardless of sliding. After 7 days, the user must re-authenticate. |
| `SlidingRefreshTokenLifetime` | `86400` (1 day) | Each use extends the expiration by 1 day, up to the absolute limit. |
| `UpdateAccessTokenClaimsOnRefresh` | `true` | When a refresh token is used, the new access token gets fresh claims from `IProfileService`. This ensures role changes, permission updates, etc. are reflected without requiring re-authentication. |

## Security Considerations

- **`OneTimeOnly`** rotation is recommended for mobile apps because if a refresh token is leaked, the attacker can only use it once before it's invalidated.
- The **sliding window** ensures active users stay authenticated while inactive users are logged out after 1 day of inactivity.
- The **absolute lifetime** of 7 days provides a hard cap, forcing re-authentication regardless of activity.
