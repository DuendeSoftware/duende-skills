# Mobile App Refresh Token Configuration

Here's the client configuration with one-time-use refresh tokens, absolute and sliding lifetimes, and claims refresh:

```csharp
new Client
{
    ClientId = "mobile-app",
    ClientName = "Mobile Application",

    AllowedGrantTypes = GrantTypes.Code,
    RequirePkce = true,
    RequireClientSecret = false, // Public client (mobile)

    RedirectUris = { "myapp://callback" },

    // Enable refresh tokens
    AllowOfflineAccess = true,

    // Refresh token rotation - new token issued on each use
    RefreshTokenUsage = TokenUsage.OneTimeOnly,

    // Sliding expiration with absolute maximum
    RefreshTokenExpiration = TokenExpiration.Sliding,
    AbsoluteRefreshTokenLifetime = 604800,  // 7 days in seconds
    SlidingRefreshTokenLifetime = 86400,     // 1 day in seconds

    // Update claims on each refresh
    UpdateAccessTokenClaimsOnRefresh = true,

    AllowedScopes =
    {
        IdentityServerConstants.StandardScopes.OpenId,
        IdentityServerConstants.StandardScopes.Profile,
        "api1"
    }
}
```

## Configuration Details

### RefreshTokenUsage = TokenUsage.OneTimeOnly

Each time the client uses a refresh token, a new refresh token is issued and the old one is invalidated. This is critical for mobile apps because:
- If a refresh token is stolen, the legitimate client's next refresh attempt will fail (the stolen token was already used), alerting you to the compromise.
- It limits the window of attack for stolen tokens.

### Lifetime Settings

| Setting | Value | Purpose |
|---------|-------|---------|
| `AbsoluteRefreshTokenLifetime` | 604800 (7 days) | Maximum lifetime regardless of activity |
| `SlidingRefreshTokenLifetime` | 86400 (1 day) | Token expires after 1 day of inactivity |
| `RefreshTokenExpiration` | `Sliding` | The 1-day window resets on each use |

With sliding expiration, an active user can keep refreshing indefinitely up to the 7-day absolute maximum. An inactive user's token expires after 1 day.

### UpdateAccessTokenClaimsOnRefresh = true

When the client refreshes its access token, the claims are re-evaluated from the user store. This means if a user's role changes or their account is disabled, the new access token reflects the updated state immediately on next refresh.
