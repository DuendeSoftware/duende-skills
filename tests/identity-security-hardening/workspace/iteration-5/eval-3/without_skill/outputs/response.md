# Migrating `spa.legacy` and Externalizing Secrets

## Migrate the SPA to authorization code + PKCE

Implicit flow is deprecated and should not be used anymore because access tokens end up in the browser URL/history. Switch the SPA to authorization code flow with PKCE. Since it's a public client (a browser SPA), it won't use a secret.

```csharp
new Client
{
    ClientId = "spa.legacy",
    ClientName = "Legacy SPA",

    AllowedGrantTypes = GrantTypes.Code,
    RequirePkce = true,
    RequireClientSecret = false,

    // Removed AllowAccessTokensViaBrowser (was true) — not needed with code flow.

    RedirectUris = { "https://spa.example.com/callback" },
    PostLogoutRedirectUris = { "https://spa.example.com" },

    AllowedScopes = { "openid", "profile", "catalog.read" },
    AllowedCorsOrigins = { "https://spa.example.com" }
}
```

## Load client secrets from configuration

Instead of hardcoding the secrets in code, read them from `IConfiguration` (which pulls from `appsettings.json`, environment variables, or a secrets manager). Your `appsettings.json` already has a `ClientSecrets` section.

```csharp
var config = builder.Configuration;

// web.app
new Client
{
    ClientId = "web.app",
    // ...
    ClientSecrets = { new Secret(config["ClientSecrets:WebApp"]!.Sha256()) },
};

// background.worker
new Client
{
    ClientId = "background.worker",
    ClientName = "Background Processing Service",
    AllowedGrantTypes = GrantTypes.ClientCredentials,
    ClientSecrets = { new Secret(config["ClientSecrets:BackgroundWorker"]!.Sha256()) },
    AllowedScopes = { "internal-api", "orders.manage" },
    AccessTokenLifetime = 3600
};
```

You'll need to add a `BackgroundWorker` entry to the `ClientSecrets` section in `appsettings.json` (the file currently only has `WebApp` and `InternalService`):

```json
"ClientSecrets": {
  "WebApp": "super-secret-value-from-config",
  "BackgroundWorker": "worker-secret-value-from-config",
  "InternalService": "internal-service-secret-value"
}
```

## Summary

- No client uses implicit flow anymore — `spa.legacy` now uses code + PKCE.
- `AllowAccessTokensViaBrowser` was removed since it's an implicit-flow setting.
- Secrets for `web.app` and `background.worker` are read from configuration via `builder.Configuration[...]` and still hashed with `.Sha256()`, rather than being hardcoded string literals. For real deployments, keep the actual values in environment variables or a secret store rather than in `appsettings.json`.
