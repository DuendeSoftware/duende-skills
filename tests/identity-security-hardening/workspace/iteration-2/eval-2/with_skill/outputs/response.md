# Harden the web.app Client

The `web.app` client has multiple security issues that need to be fixed per OAuth 2.0 Security BCP (RFC 9700):

1. **PKCE disabled** (`RequirePkce = false`) — authorization code interception is trivially exploitable
2. **Wildcard redirect URIs** — open redirector allowing attacker-controlled redirects
3. **8-hour access token lifetime** — huge replay window for stolen tokens
4. **Refresh token reuse** — stolen refresh tokens can be used indefinitely
5. **CodeAndClientCredentials grant** — combines user and M2M flows unnecessarily

Here's the hardened `web.app` client in your `Program.cs`:

```csharp
// Interactive web application — hardened per RFC 9700
new Client
{
    ClientId = "web.app",
    ClientName = "Main Web Application",
    AllowedGrantTypes = GrantTypes.Code,   // Only authorization code — no M2M
    RequirePkce = true,                     // PKCE is non-negotiable

    ClientSecrets = { new Secret("SuperSecret123".Sha256()) },

    // Exact-match URIs only — no wildcards
    RedirectUris = { "https://app.example.com/signin-oidc" },
    PostLogoutRedirectUris = { "https://app.example.com/signout-callback-oidc" },

    AllowedScopes = { "openid", "profile", "email", "catalog.read", "catalog.write" },

    AllowOfflineAccess = true,

    // Short access token — reduces replay window (5 minutes)
    AccessTokenLifetime = 300,

    // Refresh tokens rotate on every use — each use issues a new token
    RefreshTokenUsage = TokenUsage.OneTimeOnly,

    // Absolute expiration — session cannot be extended indefinitely
    RefreshTokenExpiration = TokenExpiration.Absolute,
    AbsoluteRefreshTokenLifetime = 86400, // 24 hours

    // Revoke refresh tokens when the user's session ends
    CoordinateLifetimeWithUserSession = true,

    AllowedCorsOrigins = { "https://app.example.com" }
},
```

## Changes Made

| Issue | Before | After | Why |
|-------|--------|-------|-----|
| Grant type | `GrantTypes.CodeAndClientCredentials` | `GrantTypes.Code` | Principle of least grant — web apps should only use authorization code flow |
| PKCE | `RequirePkce = false` | `RequirePkce = true` | PKCE prevents authorization code interception; required by RFC 9700 |
| Redirect URIs | `https://*.example.com/signin-oidc` | `https://app.example.com/signin-oidc` | Wildcards are open redirectors; exact-match URIs only |
| Access token lifetime | `28800` (8 hours) | `300` (5 minutes) | Short-lived tokens reduce the replay window for stolen tokens |
| Refresh token usage | `TokenUsage.ReUse` | `TokenUsage.OneTimeOnly` | One-time-only tokens detect and prevent refresh token theft |
| Refresh token expiration | `Sliding` / 30 days | `Absolute` / 24 hours | Absolute expiration prevents indefinitely-extended sessions |
| Session coordination | Not set | `CoordinateLifetimeWithUserSession = true` | Revokes refresh tokens when the user's session ends |
| CORS origins | Empty | `https://app.example.com` | Required for the SPA/browser to make cross-origin requests |
