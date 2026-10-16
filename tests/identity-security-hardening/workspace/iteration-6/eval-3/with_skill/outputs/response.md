# Migrating `spa.legacy` and moving secrets to configuration

## 1. `spa.legacy`: implicit → authorization code + PKCE
Implicit flow is deprecated by RFC 9700 (tokens in URL fragments, browser history and referrers). A browser SPA is a public client, so it uses code flow with PKCE and no secret:

```csharp
new Client
{
    ClientId = "spa.legacy",
    ClientName = "Legacy SPA",

    AllowedGrantTypes = GrantTypes.Code,
    RequirePkce = true,              // the only protection a public client has
    RequireClientSecret = false,     // public client: cannot hold a secret
    AllowAccessTokensViaBrowser = false,

    RedirectUris = { "https://spa.example.com/callback" },
    PostLogoutRedirectUris = { "https://spa.example.com" },
    AllowedScopes = { "openid", "profile", "catalog.read" },

    // Exact origin: scheme+host+port, no trailing slash, no wildcard
    AllowedCorsOrigins = { "https://spa.example.com" },

    AccessTokenLifetime = 300
}
```
The SPA must switch to `response_type=code` with an S256 `code_challenge`, and redeem the code at the token endpoint (e.g. `oidc-client-ts` with `response_type: "code"`). Where possible, move to a BFF so tokens never reach the browser. Add refresh tokens only with `OneTimeOnly` rotation and an absolute lifetime.

## 2. Secrets from configuration
`appsettings.json` already has `ClientSecrets:WebApp`. Add `ClientSecrets:Worker` alongside it, and supply real values via environment variables (`ClientSecrets__Worker`), user-secrets or a vault, not committed JSON.

```csharp
string RequireSecret(string key) =>
    builder.Configuration[$"ClientSecrets:{key}"]
    ?? throw new InvalidOperationException($"Missing configuration value ClientSecrets:{key}");

var webAppSecret = RequireSecret("WebApp");
var workerSecret = RequireSecret("Worker");
var internalSecret = RequireSecret("InternalService");

// web.app
ClientSecrets = { new Secret(webAppSecret.Sha256()) },

// background.worker
ClientSecrets = { new Secret(workerSecret.Sha256()) },

// internal.api.consumer (same problem: "InternalSecret" literal)
ClientSecrets = { new Secret(internalSecret.Sha256()) },
```

## Notes
- The old literals (`SuperSecret123`, `WorkerSecret!`, `InternalSecret`) are in git history. **Rotate them**: register the new secret next to the old one, update the clients, then remove the old one.
- Strongly consider removing the placeholder values from `appsettings.json` and failing fast when missing (as above).
- For sensitive M2M clients (`background.worker`), prefer `private_key_jwt` or mTLS so no shared secret is transmitted.
- `web.app` still uses `CodeAndClientCredentials` and `RequirePkce = false`, which should be fixed too (separate task).
