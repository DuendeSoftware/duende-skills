# Hardening the web.app Client

## Issues

The web.app client has several security issues that need fixing per OAuth 2.0 Security Best Practices.

## Fixed Configuration

```csharp
new Client
{
    ClientId = "web.app",
    ClientName = "Main Web Application",
    AllowedGrantTypes = GrantTypes.Code,
    RequirePkce = true,

    ClientSecrets = { new Secret("SuperSecret123".Sha256()) },

    RedirectUris = { "https://app.example.com/signin-oidc" },
    PostLogoutRedirectUris = { "https://app.example.com/signout-callback-oidc" },

    AllowedScopes = { "openid", "profile", "email", "catalog.read", "catalog.write" },

    AllowOfflineAccess = true,
    AccessTokenLifetime = 600, // 10 minutes
    RefreshTokenUsage = TokenUsage.OneTimeOnly,
    RefreshTokenExpiration = TokenExpiration.Absolute,
    AbsoluteRefreshTokenLifetime = 86400,

    AllowedCorsOrigins = { "https://app.example.com" }
}
```

## Changes Made

- Changed `AllowedGrantTypes` from `CodeAndClientCredentials` to `Code`
- Set `RequirePkce = true`
- Replaced wildcard redirect URIs with exact URIs
- Reduced `AccessTokenLifetime` from 8 hours to 10 minutes
- Changed `RefreshTokenUsage` to `OneTimeOnly`
