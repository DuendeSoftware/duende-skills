# Refresh Token Rotation with OneTimeOnly

## How Refresh Token Rotation Works

When a client uses a refresh token to obtain a new access token, the server can either:
- **ReUse** — Return the same refresh token (it stays valid until it expires)
- **OneTimeOnly** — Return a **new** refresh token and invalidate the old one

With `OneTimeOnly` (rotation), each refresh token exchange works like this:

1. Client sends `refresh_token=RT_1` to the token endpoint
2. IdentityServer validates `RT_1`, invalidates it, and issues a new `access_token` + `refresh_token=RT_2`
3. Next time, the client sends `refresh_token=RT_2`, gets `RT_3`, and so on
4. If an attacker steals and uses `RT_1` after it's been consumed, IdentityServer detects the reuse and can revoke the entire token family

This is a critical security measure: if a refresh token is compromised, the rotation ensures the compromise is detected when either the attacker or the legitimate client tries to use an already-consumed token.

## Client Configuration

```csharp
using Duende.IdentityServer.Models;

new Client
{
    ClientId = "web.app",
    ClientName = "Web Application",
    
    AllowedGrantTypes = GrantTypes.Code,
    RequirePkce = true,
    
    ClientSecrets = { new Secret("webapp-secret".Sha256()) },
    
    // Enable offline access so the client can request the offline_access scope
    AllowOfflineAccess = true,
    
    // Enable refresh token rotation - each refresh returns a new token
    // IMPORTANT: The default changed to ReUse in IdentityServer v7.0,
    // so you must set OneTimeOnly explicitly for rotation
    RefreshTokenUsage = TokenUsage.OneTimeOnly,
    
    // Optional: configure refresh token lifetime
    RefreshTokenExpiration = TokenExpiration.Sliding,
    SlidingRefreshTokenLifetime = 1296000, // 15 days in seconds
    AbsoluteRefreshTokenLifetime = 2592000, // 30 days in seconds
    
    // Allowed scopes - include offline_access for refresh tokens
    AllowedScopes =
    {
        "openid",
        "profile",
        "api1",
        "offline_access"
    },
    
    RedirectUris = { "https://myapp.example.com/signin-oidc" },
    PostLogoutRedirectUris = { "https://myapp.example.com/signout-callback-oidc" }
}
```

## Key Configuration Properties

| Property | Value | Purpose |
|----------|-------|---------|
| `AllowOfflineAccess` | `true` | Allows the client to request the `offline_access` scope, which triggers refresh token issuance |
| `RefreshTokenUsage` | `TokenUsage.OneTimeOnly` | Each refresh returns a new refresh token; the old one is invalidated |
| `AllowedScopes` | includes `"offline_access"` | The scope must be in the allowed list for the client to request it |
| `AllowedGrantTypes` | `GrantTypes.Code` | Authorization code flow (required for interactive user login) |

## Important Note on v7.0 Default Change

In Duende IdentityServer v7.0, the default value of `RefreshTokenUsage` changed from `OneTimeOnly` to `ReUse`. This means if you upgrade to v7.0+ and don't explicitly set `RefreshTokenUsage`, your refresh tokens will **not** be rotated. You must set `RefreshTokenUsage = TokenUsage.OneTimeOnly` explicitly if you want rotation.

## Client-Side Usage

On the client side, request the `offline_access` scope in the OIDC configuration:

```csharp
builder.Services.AddAuthentication(options =>
{
    options.DefaultScheme = "Cookies";
    options.DefaultChallengeScheme = "oidc";
})
.AddCookie("Cookies")
.AddOpenIdConnect("oidc", options =>
{
    options.Authority = "https://identity.example.com";
    options.ClientId = "web.app";
    options.ClientSecret = "webapp-secret";
    options.ResponseType = "code";
    options.Scope.Add("offline_access");
    options.SaveTokens = true;
});
```

When `SaveTokens = true`, the refresh token is stored in the authentication cookie. Use `Duende.AccessTokenManagement` to automatically handle refresh token exchange when the access token expires.
