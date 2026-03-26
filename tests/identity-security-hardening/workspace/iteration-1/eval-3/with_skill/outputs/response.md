# Migrating Implicit Flow and Fixing Hardcoded Secrets

## 1. Migrate spa.legacy from Implicit to Code + PKCE

The `spa.legacy` client uses `GrantTypes.Implicit` with `AllowAccessTokensViaBrowser = true`. This exposes tokens in the URL fragment, browser history, and referrer headers. RFC 9700 deprecates implicit flow entirely.

### Before
```csharp
new Client
{
    ClientId = "spa.legacy",
    AllowedGrantTypes = GrantTypes.Implicit,
    AllowAccessTokensViaBrowser = true,
    ...
}
```

### After
```csharp
new Client
{
    ClientId = "spa.legacy",
    ClientName = "Legacy SPA",
    AllowedGrantTypes = GrantTypes.Code,
    RequirePkce = true,
    RequireClientSecret = false, // Public client (SPA)

    // AllowAccessTokensViaBrowser removed — not needed with code flow

    RedirectUris = { "https://spa.example.com/callback" },
    PostLogoutRedirectUris = { "https://spa.example.com" },

    AllowedScopes = { "openid", "profile", "catalog.read" },
    AllowedCorsOrigins = { "https://spa.example.com" }
}
```

## 2. Load Client Secrets from Configuration

Hardcoded secrets in source code are committed to git history and visible to anyone with access to the repository. Load them from `IConfiguration` instead.

### appsettings.json (or better: Azure Key Vault, AWS Secrets Manager)
```json
{
    "ClientSecrets": {
        "WebApp": "super-secret-value-from-config",
        "BackgroundWorker": "worker-secret-value-from-config"
    }
}
```

### web.app client
```csharp
new Client
{
    ClientId = "web.app",
    ClientSecrets = { new Secret(builder.Configuration["ClientSecrets:WebApp"].Sha256()) },
    ...
}
```

### background.worker client
```csharp
new Client
{
    ClientId = "background.worker",
    ClientSecrets = { new Secret(builder.Configuration["ClientSecrets:BackgroundWorker"].Sha256()) },
    ...
}
```

## Summary

| Change | Before | After |
|--------|--------|-------|
| spa.legacy grant type | `GrantTypes.Implicit` | `GrantTypes.Code` with `RequirePkce = true` |
| spa.legacy token via browser | `AllowAccessTokensViaBrowser = true` | Removed |
| web.app secret | `"SuperSecret123".Sha256()` | `builder.Configuration["ClientSecrets:WebApp"].Sha256()` |
| background.worker secret | `"WorkerSecret!".Sha256()` | `builder.Configuration["ClientSecrets:BackgroundWorker"].Sha256()` |
