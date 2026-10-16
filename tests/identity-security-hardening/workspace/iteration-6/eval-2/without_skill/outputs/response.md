# Hardened `web.app` client (RFC 9700)

```csharp
new Client
{
    ClientId = "web.app",
    ClientName = "Main Web Application",

    // Interactive user login only; no client_credentials mixed in
    AllowedGrantTypes = GrantTypes.Code,
    RequirePkce = true,
    AllowPlainTextPkce = false,

    RequireClientSecret = true,
    ClientSecrets = { new Secret(builder.Configuration["ClientSecrets:WebApp"]!.Sha256()) },

    // Exact-match URIs only, no wildcards
    RedirectUris = { "https://app.example.com/signin-oidc" },
    PostLogoutRedirectUris = { "https://app.example.com/signout-callback-oidc" },

    AllowedScopes = { "openid", "profile", "email", "catalog.read", "catalog.write" },

    // Short-lived access tokens
    AccessTokenLifetime = 300, // 5 minutes

    // Refresh tokens: rotate each use, absolute lifetime
    AllowOfflineAccess = true,
    RefreshTokenUsage = TokenUsage.OneTimeOnly,
    RefreshTokenExpiration = TokenExpiration.Absolute,
    AbsoluteRefreshTokenLifetime = 28800 // 8h
}
```

## What changed and why
| Issue | Fix |
|---|---|
| PKCE disabled | `RequirePkce = true` (RFC 9700 §2.1.1 – PKCE for all code flows, even confidential clients). |
| Wildcard redirect URIs | Exact string matching (§2.1) prevents open-redirect/code theft. |
| 8h access token | 5 min (300s) limits impact of a leaked token. |
| `ReUse` refresh tokens | `OneTimeOnly` rotation with reuse detection (§4.14); absolute expiry, not sliding. |
| `CodeAndClientCredentials` | A user-facing client shouldn't also be able to act as a machine client with its own identity. Use `GrantTypes.Code`; create a separate client for M2M. |

Also: move the secret out of source (configuration/secret store) and consider using `PrivateKeyJwt` or mTLS client authentication for stronger secrets. If you rely on `client_credentials` for web.app today, add a separate client such as `web.app.m2m`, and restrict scopes to what's needed.
