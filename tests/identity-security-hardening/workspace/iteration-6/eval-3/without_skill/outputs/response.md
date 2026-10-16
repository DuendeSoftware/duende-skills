# Migrating `spa.legacy` and removing hardcoded secrets

## 1. SPA: implicit → authorization code + PKCE
Implicit flow is deprecated (RFC 9700) as tokens are exposed in the URL fragment. A SPA is a public client, so use code flow with PKCE and no secret. Even better is a BFF, but this is the direct migration:

```csharp
new Client
{
    ClientId = "spa.legacy",
    ClientName = "Legacy SPA",
    AllowedGrantTypes = GrantTypes.Code,
    RequirePkce = true,
    RequireClientSecret = false,
    AllowAccessTokensViaBrowser = false,

    RedirectUris = { "https://spa.example.com/callback" },
    PostLogoutRedirectUris = { "https://spa.example.com" },
    AllowedScopes = { "openid", "profile", "catalog.read" },
    AllowedCorsOrigins = { "https://spa.example.com" },

    AccessTokenLifetime = 300,
    AllowOfflineAccess = false // or use OneTimeOnly rotating refresh tokens if needed
}
```
The SPA must be updated to use `response_type=code` with `code_challenge` (S256) and exchange the code at the token endpoint (e.g. oidc-client-ts with `response_type: "code"`).

## 2. Secrets from configuration
Existing `appsettings.json` already has `ClientSecrets:WebApp` and `ClientSecrets:InternalService`. Add a key for the worker:

```json
"ClientSecrets": {
  "WebApp": "...",
  "Worker": "...",
  "InternalService": "..."
}
```
In production, supply them via environment variables (`ClientSecrets__Worker`), user-secrets, or Key Vault/Secrets Manager, not committed JSON.

```csharp
var webAppSecret = builder.Configuration["ClientSecrets:WebApp"]
    ?? throw new InvalidOperationException("ClientSecrets:WebApp missing");
var workerSecret = builder.Configuration["ClientSecrets:Worker"]
    ?? throw new InvalidOperationException("ClientSecrets:Worker missing");

// web.app
ClientSecrets = { new Secret(webAppSecret.Sha256()) },

// background.worker
ClientSecrets = { new Secret(workerSecret.Sha256()) },
```

Notes: rotate the old values since they live in git history; use long random secrets (32+ bytes); and the other client (`internal.api.consumer`) has the same hardcoded problem, so it should use `ClientSecrets:InternalService` too.
