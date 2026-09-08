# Migrate `spa.legacy` off Implicit Flow + Move Secrets to Configuration

Three fixes here: (1) migrate `spa.legacy` from the deprecated implicit flow to authorization code + PKCE, (2) load `background.worker`'s secret from configuration, and (3) do the same for `web.app`. Implicit flow is deprecated by RFC 9700 because it exposes tokens in the URL fragment, browser history, and referrer headers.

## 1. Read secrets from configuration

`appsettings.json` already exposes secret values under `ClientSecrets`. Bind configuration and read them (in production these come from environment variables / a secret store that overrides `appsettings.json`):

```csharp
var configuration = builder.Configuration;

var webAppSecret        = configuration["ClientSecrets:WebApp"]
    ?? throw new InvalidOperationException("Missing ClientSecrets:WebApp");
var backgroundWorkerSecret = configuration["ClientSecrets:BackgroundWorker"]
    ?? throw new InvalidOperationException("Missing ClientSecrets:BackgroundWorker");
```

Add the worker secret to configuration (keep real values out of source control — this is just the key shape):

```jsonc
// appsettings.json
"ClientSecrets": {
  "WebApp": "super-secret-value-from-config",
  "BackgroundWorker": "worker-secret-value-from-config",
  "InternalService": "internal-service-secret-value"
}
```

## 2. Migrate `spa.legacy` to code + PKCE

```csharp
// SPA client — migrated from implicit to authorization code + PKCE
new Client
{
    ClientId = "spa.legacy",
    ClientName = "Legacy SPA",

    // ✅ Authorization code + PKCE replaces implicit flow entirely
    AllowedGrantTypes = GrantTypes.Code,
    RequirePkce = true,

    // Public browser client — no secret it can protect
    RequireClientSecret = false,

    // ✅ AllowAccessTokensViaBrowser removed (was true) — implicit-flow artifact.
    //    Code flow returns tokens from the token endpoint, not the browser URL.

    RedirectUris = { "https://spa.example.com/callback" },
    PostLogoutRedirectUris = { "https://spa.example.com" },

    AllowedScopes = { "openid", "profile", "catalog.read" },
    AllowedCorsOrigins = { "https://spa.example.com" }
}
```

## 3. `web.app` and `background.worker` — secrets from configuration

```csharp
new Client
{
    ClientId = "web.app",
    // ... other settings ...
    // ✅ Load from configuration, not an inline literal
    ClientSecrets = { new Secret(webAppSecret.Sha256()) },
},

new Client
{
    ClientId = "background.worker",
    ClientName = "Background Processing Service",
    AllowedGrantTypes = GrantTypes.ClientCredentials,

    // ✅ Load from configuration, not "WorkerSecret!".Sha256()
    ClientSecrets = { new Secret(backgroundWorkerSecret.Sha256()) },

    AllowedScopes = { "internal-api", "orders.manage" },
    AccessTokenLifetime = 3600
}
```

## Why these changes

- **No implicit flow anywhere** — `spa.legacy` was the only implicit client; it now uses `GrantTypes.Code` with `RequirePkce = true`. A modern browser SPA should use code flow with PKCE (ideally behind a BFF).
- **`AllowAccessTokensViaBrowser` removed** — it only made sense for implicit flow; leaving it `true` would return tokens via the browser, defeating the purpose of the migration.
- **Secrets from configuration** — the values are still `.Sha256()`-hashed when registered as `Secret`s, but the *source* is now `builder.Configuration[...]` rather than a string literal committed to git history. Real values should be supplied via environment variables / vault, overriding the placeholder in `appsettings.json`.

> The `internal.api.consumer` secret is also a hardcoded literal; apply the same configuration-loading pattern to it when you touch that client.
