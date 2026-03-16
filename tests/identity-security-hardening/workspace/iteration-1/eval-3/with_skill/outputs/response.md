# Migrating spa.legacy from Implicit to Code+PKCE & Fixing Hardcoded Secrets

## 1. Migrate spa.legacy from Implicit to Authorization Code + PKCE

The implicit flow is deprecated by RFC 9700. It exposes tokens in URL fragments, browser history, and referrer headers. Migrate to authorization code flow with PKCE:

```csharp
// ✅ Migrated from GrantTypes.Implicit to GrantTypes.Code + PKCE
new Client
{
    ClientId = "spa.legacy",
    ClientName = "Legacy SPA",
    AllowedGrantTypes = GrantTypes.Code,
    RequirePkce = true,
    RequireClientSecret = false, // SPA is a public client

    // AllowAccessTokensViaBrowser removed — no longer needed with code flow

    RedirectUris = { "https://spa.example.com/callback" },
    PostLogoutRedirectUris = { "https://spa.example.com" },

    AllowedScopes = { "openid", "profile", "catalog.read" },
    AllowedCorsOrigins = { "https://spa.example.com" }
}
```

Key changes:
- `GrantTypes.Implicit` → `GrantTypes.Code`
- `RequirePkce = true` — mandatory for all code flow clients
- `AllowAccessTokensViaBrowser = true` removed (defaults to `false`)
- `RequireClientSecret = false` — SPAs are public clients

## 2. Fix Hardcoded Secrets — Load from Configuration

Client secrets for `web.app` and `background.worker` are hardcoded as string literals. Load them from `appsettings.json` (or a vault) instead.

### appsettings.json (already has the structure):

```json
{
  "ClientSecrets": {
    "WebApp": "super-secret-value-from-config",
    "BackgroundWorker": "worker-secret-value-from-config"
  }
}
```

### Updated Client Configurations:

```csharp
// ✅ web.app — secret loaded from configuration
new Client
{
    ClientId = "web.app",
    ClientName = "Main Web Application",
    AllowedGrantTypes = GrantTypes.Code,
    RequirePkce = true,

    // Secret loaded from configuration, hashed with Sha256
    ClientSecrets = { new Secret(builder.Configuration["ClientSecrets:WebApp"].Sha256()) },

    RedirectUris = { "https://app.example.com/signin-oidc" },
    PostLogoutRedirectUris = { "https://app.example.com/signout-callback-oidc" },
    AllowedScopes = { "openid", "profile", "email", "catalog.read", "catalog.write" },
    AllowOfflineAccess = true,
    AccessTokenLifetime = 300,
    RefreshTokenUsage = TokenUsage.OneTimeOnly,
    RefreshTokenExpiration = TokenExpiration.Absolute,
    AbsoluteRefreshTokenLifetime = 86400,
    CoordinateLifetimeWithUserSession = true,
    AllowedCorsOrigins = { "https://app.example.com" }
}

// ✅ background.worker — secret loaded from configuration
new Client
{
    ClientId = "background.worker",
    ClientName = "Background Processing Service",
    AllowedGrantTypes = GrantTypes.ClientCredentials,

    // Secret loaded from configuration, not hardcoded
    ClientSecrets = { new Secret(builder.Configuration["ClientSecrets:BackgroundWorker"].Sha256()) },
    AllowedScopes = { "internal-api", "orders.manage" },
    AccessTokenLifetime = 300
}
```

## Summary

| Client | Issue | Fix |
|--------|-------|-----|
| `spa.legacy` | `GrantTypes.Implicit` | → `GrantTypes.Code` + `RequirePkce = true` |
| `spa.legacy` | `AllowAccessTokensViaBrowser = true` | Removed (defaults to `false`) |
| `web.app` | `"SuperSecret123".Sha256()` hardcoded | → `builder.Configuration["ClientSecrets:WebApp"].Sha256()` |
| `background.worker` | `"WorkerSecret!".Sha256()` hardcoded | → `builder.Configuration["ClientSecrets:BackgroundWorker"].Sha256()` |
