# Refresh Token Rotation with OneTimeOnly

## How Refresh Token Rotation Works

With `OneTimeOnly` refresh token usage:

1. Client obtains an initial refresh token during the authorization code flow
2. When the access token expires, client sends the refresh token to the token endpoint
3. IdentityServer returns a **new access token AND a new refresh token**
4. The **old refresh token is invalidated** — it can never be used again
5. The client must store and use the new refresh token for the next exchange

This rotation mechanism provides a security benefit: if a refresh token is stolen, the attacker can use it at most once. When either the legitimate client or the attacker uses the token, the other's copy becomes invalid. The next use attempt by the party holding the stale token will fail, signaling a potential compromise.

## Client Configuration

```csharp
new Client
{
    ClientId = "web.app",
    ClientName = "Web Application",
    AllowedGrantTypes = GrantTypes.Code,
    RequirePkce = true,

    // Enable refresh tokens
    AllowOfflineAccess = true,

    // Rotation: each refresh returns a new refresh token
    RefreshTokenUsage = TokenUsage.OneTimeOnly,

    // Optional: configure refresh token lifetime
    RefreshTokenExpiration = TokenExpiration.Sliding,
    SlidingRefreshTokenLifetime = 1296000, // 15 days
    AbsoluteRefreshTokenLifetime = 2592000, // 30 days

    ClientSecrets = { new Secret("secret".Sha256()) },
    RedirectUris = { "https://webapp.example.com/callback" },
    PostLogoutRedirectUris = { "https://webapp.example.com" },

    AllowedScopes =
    {
        "openid",
        "profile",
        "api1",
        "offline_access"  // Required for refresh tokens
    }
}
```

## Key Configuration Points

### `AllowOfflineAccess = true`
This allows the client to request the `offline_access` scope, which is required for the server to issue refresh tokens. Without this, no refresh token is returned even if `offline_access` is in `AllowedScopes`.

### `RefreshTokenUsage = TokenUsage.OneTimeOnly`
This enables rotation. Each time the refresh token is used, a new one is issued and the old one is invalidated.

**Important:** The default changed to `ReUse` in Duende IdentityServer v7.0. If you want rotation, you must explicitly set `OneTimeOnly`. In `ReUse` mode, the same refresh token can be used repeatedly without being replaced.

### `offline_access` in `AllowedScopes`
The client must include `offline_access` in its `AllowedScopes` to be able to request refresh tokens.

## The Token Exchange

```
POST /connect/token
Content-Type: application/x-www-form-urlencoded

grant_type=refresh_token
&refresh_token=old_refresh_token_value
&client_id=web.app
&client_secret=secret
```

Response:
```json
{
    "access_token": "new_access_token",
    "refresh_token": "new_refresh_token",  // New! Store this for next use
    "token_type": "Bearer",
    "expires_in": 3600
}
```

The client must update its stored refresh token with the new value from each response.
