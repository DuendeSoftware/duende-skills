# Hardened `web.app` client (RFC 9700)

```csharp
new Client
{
    ClientId = "web.app",
    ClientName = "Main Web Application",

    // ✅ Interactive user flow only: authorization code. Never mix user + M2M flows.
    AllowedGrantTypes = GrantTypes.Code,

    // ✅ PKCE is non-negotiable (even for confidential clients)
    RequirePkce = true,

    // ✅ Secret loaded from configuration, not a literal
    ClientSecrets = { new Secret(builder.Configuration["ClientSecrets:WebApp"]!.Sha256()) },

    // ✅ Exact-match, fully qualified URIs; no wildcards
    RedirectUris = { "https://app.example.com/signin-oidc" },
    PostLogoutRedirectUris = { "https://app.example.com/signout-callback-oidc" },

    AllowedScopes = { "openid", "profile", "email", "catalog.read", "catalog.write" },

    // ✅ Short access tokens
    AccessTokenLifetime = 300,           // 5 min (was 8h)
    IdentityTokenLifetime = 300,

    // ✅ Rotating refresh tokens with absolute expiry
    AllowOfflineAccess = true,
    RefreshTokenUsage = TokenUsage.OneTimeOnly,          // was ReUse
    RefreshTokenExpiration = TokenExpiration.Absolute,   // was Sliding
    AbsoluteRefreshTokenLifetime = 86400,                // 24h (was 30 days)

    // ✅ Revoke refresh tokens when the user's session ends
    CoordinateLifetimeWithUserSession = true,

    AllowedCorsOrigins = { }
}
```

## What was wrong and what changed
| Issue | Risk | Fix |
|---|---|---|
| `RequirePkce = false` | Authorization code interception | `RequirePkce = true` (RFC 9700 requires PKCE for all code-flow clients) |
| `https://*.example.com/...` | Open redirect/code theft via any subdomain | Exact, fully-qualified URIs for redirect and post-logout |
| 8h access token (`28800`) | Huge replay window | 300s; use refresh tokens for longer sessions |
| `TokenUsage.ReUse` | A stolen refresh token works indefinitely | `OneTimeOnly` rotation; absolute 24h lifetime instead of 30-day sliding |
| `CodeAndClientCredentials` | The interactive app can also authenticate as itself, expanding attack surface | `GrantTypes.Code` only |

## Notes
- If `web.app` really does need machine-to-machine calls, register a **separate** client (e.g. `web.app.m2m` with `GrantTypes.ClientCredentials`) with its own secret and minimal scopes.
- The hardcoded `SuperSecret123` hash is in git history; rotate it. For higher assurance consider `private_key_jwt` or mTLS client authentication; to rotate shared secrets, register the new secret next to the old one, deploy the client, and then remove the old secret.
- Pair this with server-side sessions so `CoordinateLifetimeWithUserSession` has an effect, and make sure the API side validates audience.
