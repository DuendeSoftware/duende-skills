# Configuring Refresh Tokens for the `web_app` Client

To get refresh tokens from IdentityServer for an authorization-code client, you need to enable offline access, request the `offline_access` scope, and configure the refresh token lifetimes. Here's how to set it up.

## Requirements for refresh tokens

1. `AllowOfflineAccess = true` on the client
2. The `offline_access` scope must be in `AllowedScopes` (so it can be requested)
3. Configure the lifetime/rotation properties

## Updated client

```csharp
new Client
{
    ClientId = "web_app",
    ClientName = "Web Application",
    AllowedGrantTypes = GrantTypes.Code,
    ClientSecrets = { new Secret("secret".Sha256()) },
    RedirectUris = { "https://localhost:5002/signin-oidc" },
    PostLogoutRedirectUris = { "https://localhost:5002/signout-callback-oidc" },

    AllowOfflineAccess = true,
    AllowedScopes = { "openid", "profile", "api1", "offline_access" },

    // 30-day absolute lifetime, 1-day sliding window
    RefreshTokenExpiration = TokenExpiration.Sliding,
    AbsoluteRefreshTokenLifetime = 2592000, // 30 * 24 * 60 * 60
    SlidingRefreshTokenLifetime = 86400,    // 24 * 60 * 60

    // Keep the default ReUse rotation
    RefreshTokenUsage = TokenUsage.ReUse,

    AccessTokenLifetime = 3600
}
```

## Notes

- `RefreshTokenExpiration = TokenExpiration.Sliding` means the token's lifetime is extended each time it's used, but capped by `AbsoluteRefreshTokenLifetime`.
- `AbsoluteRefreshTokenLifetime = 2592000` gives the 30-day hard cap.
- `SlidingRefreshTokenLifetime = 86400` gives the 1-day sliding window.
- `RefreshTokenUsage = TokenUsage.ReUse` keeps the same refresh token across requests (the default), as opposed to `OneTimeOnly` which rotates the token on every use.

Make sure your OIDC client on the web app side actually requests the `offline_access` scope, otherwise no refresh token will be returned even with this configuration.
