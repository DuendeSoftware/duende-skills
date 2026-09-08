# Hardening the `web.app` Client (RFC 9700)

The current `web.app` client violates several OAuth 2.0 Security BCP controls: PKCE disabled, wildcard redirect URIs, an 8-hour access token, refresh-token reuse, and a mixed user+M2M grant type. Here is the hardened configuration with each fix explained.

## Hardened client

```csharp
new Client
{
    ClientId = "web.app",
    ClientName = "Main Web Application",

    // ✅ Principle of least grant — authorization code ONLY.
    // CodeAndClientCredentials mixed an interactive user flow with an M2M flow;
    // if web.app needs M2M, register a SEPARATE client for it.
    AllowedGrantTypes = GrantTypes.Code,

    // ✅ PKCE is non-negotiable for every authorization code client.
    // RequirePkce = true is the default; it must never be set to false.
    RequirePkce = true,

    ClientSecrets = { new Secret("SuperSecret123".Sha256()) },

    // ✅ Exact-match, fully-qualified HTTPS URIs — no wildcards.
    // Wildcards are an open-redirector attack surface (authorization code injection).
    RedirectUris = { "https://app.example.com/signin-oidc" },
    PostLogoutRedirectUris = { "https://app.example.com/signout-callback-oidc" },

    AllowedScopes = { "openid", "profile", "email", "catalog.read", "catalog.write" },

    AllowOfflineAccess = true,

    // ✅ Short access token — shrinks the replay window (was 28800 = 8h).
    AccessTokenLifetime = 300,   // 5 minutes

    // ✅ Refresh tokens rotate on every use; a replayed old token is detected/revoked.
    RefreshTokenUsage = TokenUsage.OneTimeOnly,

    // ✅ Absolute expiration bounds the maximum refresh-token lifetime.
    RefreshTokenExpiration = TokenExpiration.Absolute,
    AbsoluteRefreshTokenLifetime = 86400,   // 24 hours (was 30 days sliding)
    SlidingRefreshTokenLifetime = 3600,     // 1 hour sliding window

    // ✅ Revoke refresh tokens when the user's server-side session ends.
    CoordinateLifetimeWithUserSession = true,

    AllowedCorsOrigins = { }
}
```

## What changed and why

| Issue | Before | After | Rationale |
|-------|--------|-------|-----------|
| PKCE | `RequirePkce = false` | `RequirePkce = true` | Prevents authorization code interception; mandatory for all code clients. |
| Redirect URIs | `https://*.example.com/...` | `https://app.example.com/signin-oidc` | Wildcards let an attacker steer the code to a malicious host. Exact match only. |
| Grant type | `CodeAndClientCredentials` | `GrantTypes.Code` | Never combine an interactive user flow with M2M. Split into two clients if both are truly needed. |
| Access token | `28800` (8h) | `300` (5m) | Reduces the window in which a stolen token is usable. |
| Refresh reuse | `TokenUsage.ReUse` | `TokenUsage.OneTimeOnly` | Enables refresh-token rotation and replay detection. |
| Refresh expiration | `Sliding`, 30-day absolute | `Absolute`, 24h | Bounds the refresh-token lifetime; sliding-only can extend indefinitely. |
| Session coupling | (none) | `CoordinateLifetimeWithUserSession = true` | Ties token validity to the user session so logout revokes tokens. |

> **Follow-up:** The secret is still a hardcoded literal (`"SuperSecret123".Sha256()`). That should be loaded from configuration/secret store — see the client-secret-management pattern — but it is outside the scope of this specific request.
