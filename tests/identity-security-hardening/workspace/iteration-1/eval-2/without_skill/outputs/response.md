# Hardening the web.app Client

There are several security issues with the `web.app` client. Let me fix them:

## Updated web.app Client

```csharp
new Client
{
    ClientId = "web.app",
    ClientName = "Main Web Application",
    
    // Use authorization code flow only
    AllowedGrantTypes = GrantTypes.Code,
    RequirePkce = true,

    ClientSecrets = { new Secret("SuperSecret123".Sha256()) },

    // Use specific redirect URIs
    RedirectUris = { "https://app.example.com/signin-oidc" },
    PostLogoutRedirectUris = { "https://app.example.com/signout-callback-oidc" },

    AllowedScopes = { "openid", "profile", "email", "catalog.read", "catalog.write" },

    AllowOfflineAccess = true,
    
    // Reduce access token lifetime to 1 hour
    AccessTokenLifetime = 3600,
    
    // Use one-time refresh tokens
    RefreshTokenUsage = TokenUsage.OneTimeOnly,
    RefreshTokenExpiration = TokenExpiration.Absolute,
    AbsoluteRefreshTokenLifetime = 2592000,

    AllowedCorsOrigins = { "https://app.example.com" }
}
```

## Changes Made

- Changed `AllowedGrantTypes` from `CodeAndClientCredentials` to `Code`
- Enabled PKCE (`RequirePkce = true`)
- Replaced wildcard redirect URIs with exact URIs
- Reduced access token lifetime from 8 hours to 1 hour
- Changed refresh token usage to one-time-only
