# Securing the `web.app` Client

Following the OAuth 2.0 Security Best Current Practice (RFC 9700), here are the fixes for the issues you listed. The main ideas are: always require PKCE for authorization-code clients, never use wildcard redirect URIs, keep access tokens short-lived, rotate refresh tokens, and don't mix grant types.

## Updated client configuration

```csharp
new Client
{
    ClientId = "web.app",
    ClientName = "Main Web Application",

    // Use authorization code flow only (was CodeAndClientCredentials).
    AllowedGrantTypes = GrantTypes.Code,

    // Enable PKCE (was false). This is required by RFC 9700 for code flow.
    RequirePkce = true,

    ClientSecrets = { new Secret("SuperSecret123".Sha256()) },

    // Exact redirect URIs, no wildcards.
    RedirectUris = { "https://app.example.com/signin-oidc" },
    PostLogoutRedirectUris = { "https://app.example.com/signout-callback-oidc" },

    AllowedScopes = { "openid", "profile", "email", "catalog.read", "catalog.write" },

    AllowOfflineAccess = true,

    // Short access token lifetime (was 8 hours).
    AccessTokenLifetime = 300, // 5 minutes

    // Rotate refresh tokens instead of reusing them.
    RefreshTokenUsage = TokenUsage.OneTimeOnly,
    RefreshTokenExpiration = TokenExpiration.Absolute,
    AbsoluteRefreshTokenLifetime = 86400 // 24 hours
}
```

## Summary of fixes

1. **PKCE** — set `RequirePkce = true`. PKCE protects the authorization code against interception, which is why RFC 9700 requires it even for confidential clients.
2. **Redirect URIs** — replaced `https://*.example.com/signin-oidc` with the exact `https://app.example.com/signin-oidc`. Wildcards are dangerous because an attacker controlling any subdomain (or tricking the matcher) could receive the authorization code.
3. **Grant type** — changed `CodeAndClientCredentials` to `GrantTypes.Code`. A browser-based user app should not also have client-credentials capability; if you need machine-to-machine access, create a separate client for it.
4. **Access token lifetime** — reduced from 28800 seconds (8 hours) to 300 seconds (5 minutes) to limit the damage from a leaked token.
5. **Refresh tokens** — switched `TokenUsage.ReUse` to `TokenUsage.OneTimeOnly` so each refresh issues a new token and old ones are invalidated, and set an absolute expiration to cap how long a refresh token can live.

You should also consider loading the client secret from configuration or a secrets manager instead of hardcoding it, and enabling detection/revocation if a rotated refresh token is replayed.
