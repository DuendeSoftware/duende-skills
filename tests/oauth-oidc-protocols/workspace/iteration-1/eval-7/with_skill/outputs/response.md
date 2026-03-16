# Refresh Token Rotation with OneTimeOnly

## How Refresh Token Rotation Works

When a client uses a refresh token to obtain a new access token, the authorization server can issue a **new refresh token** along with the new access token. With refresh token rotation enabled (`OneTimeOnly`):

1. The client sends the current refresh token to the token endpoint
2. The server validates the refresh token and issues a new access token
3. The server also issues a **new refresh token** and **invalidates the old one**
4. If someone tries to use the old (invalidated) refresh token, the server rejects it

This is a critical security measure: if an attacker steals a refresh token, the legitimate client's next refresh will fail (because the stolen token was used first), alerting the system to the compromise. The attacker's use of the stolen token will also eventually fail when the legitimate client uses the newer token.

## Client Configuration

```csharp
using Duende.IdentityServer.Models;

new Client
{
    ClientId = "web.app",
    ClientName = "Web Application",
    AllowedGrantTypes = GrantTypes.Code,
    RequirePkce = true,

    ClientSecrets = { new Secret("secret".Sha256()) },

    RedirectUris = { "https://app.example.com/callback" },
    PostLogoutRedirectUris = { "https://app.example.com/" },

    // Enable offline_access scope so the client can request refresh tokens
    AllowOfflineAccess = true,

    // Refresh token rotation — each use returns a new refresh token
    // and invalidates the previous one
    RefreshTokenUsage = TokenUsage.OneTimeOnly,

    // Optional: configure refresh token lifetime
    RefreshTokenExpiration = TokenExpiration.Sliding,
    SlidingRefreshTokenLifetime = 1296000, // 15 days
    AbsoluteRefreshTokenLifetime = 2592000, // 30 days

    AllowedScopes =
    {
        "openid",
        "profile",
        "email",
        "api1",
        "offline_access"
    }
};
```

## Key Configuration Points

1. **`RefreshTokenUsage = TokenUsage.OneTimeOnly`** — This enables refresh token rotation. Each refresh token exchange returns a new refresh token and invalidates the old one. **Important**: the default changed to `ReUse` in IdentityServer v7.0, so `OneTimeOnly` must be set explicitly if you want rotation.

2. **`AllowOfflineAccess = true`** — This is required for the `offline_access` scope to be allowed. Without it, the client cannot request refresh tokens.

3. **`offline_access` in `AllowedScopes`** — The scope must be explicitly listed in the client's allowed scopes.

4. The client must request the `offline_access` scope during the authorization request:

```csharp
options.Scope.Add("offline_access");
```

## Protocol-Level Exchange

```
POST /connect/token
Content-Type: application/x-www-form-urlencoded

grant_type=refresh_token
&refresh_token=old_rt_value
&client_id=web.app
&client_secret=secret
```

Response:
```json
{
    "access_token": "new_at",
    "refresh_token": "new_rt",
    "token_type": "Bearer",
    "expires_in": 3600
}
```

The old `old_rt_value` is now invalidated and cannot be used again.
