# Migrating spa.legacy and Fixing Secrets

## 1. Migrate spa.legacy from Implicit to Authorization Code

Implicit flow is considered less secure as tokens are exposed in the URL. Let's switch to authorization code flow:

```csharp
new Client
{
    ClientId = "spa.legacy",
    ClientName = "Legacy SPA",
    AllowedGrantTypes = GrantTypes.Code,
    RequirePkce = true,
    RequireClientSecret = false,

    RedirectUris = { "https://spa.example.com/callback" },
    PostLogoutRedirectUris = { "https://spa.example.com" },

    AllowedScopes = { "openid", "profile", "catalog.read" },
    AllowedCorsOrigins = { "https://spa.example.com" }
}
```

## 2. Fix Hardcoded Secrets

Load secrets from environment variables or configuration:

```csharp
// web.app
new Client
{
    ClientId = "web.app",
    ClientName = "Main Web Application",
    AllowedGrantTypes = GrantTypes.Code,
    RequirePkce = true,
    ClientSecrets = { new Secret(builder.Configuration["ClientSecrets:WebApp"].Sha256()) },
    RedirectUris = { "https://app.example.com/signin-oidc" },
    PostLogoutRedirectUris = { "https://app.example.com/signout-callback-oidc" },
    AllowedScopes = { "openid", "profile", "email", "catalog.read", "catalog.write" },
    AllowOfflineAccess = true,
    AccessTokenLifetime = 3600,
    RefreshTokenUsage = TokenUsage.OneTimeOnly,
    AllowedCorsOrigins = { "https://app.example.com" }
}

// background.worker
new Client
{
    ClientId = "background.worker",
    ClientName = "Background Processing Service",
    AllowedGrantTypes = GrantTypes.ClientCredentials,
    ClientSecrets = { new Secret(builder.Configuration["ClientSecrets:BackgroundWorker"].Sha256()) },
    AllowedScopes = { "internal-api", "orders.manage" },
    AccessTokenLifetime = 3600
}
```

The secrets should be stored in `appsettings.json` (or preferably Azure Key Vault / AWS Secrets Manager):

```json
{
  "ClientSecrets": {
    "WebApp": "super-secret-value-from-config",
    "BackgroundWorker": "worker-secret-value"
  }
}
```
