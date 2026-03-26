# Migrating Implicit Flow and Fixing Secrets

## Migrate spa.legacy to Code Flow

The implicit flow is deprecated. Switch to authorization code flow with PKCE:

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

## Fix Hardcoded Secrets

Move secrets to configuration:

```csharp
// web.app
ClientSecrets = { new Secret(builder.Configuration["ClientSecrets:WebApp"].Sha256()) },

// background.worker
ClientSecrets = { new Secret(builder.Configuration["ClientSecrets:BackgroundWorker"].Sha256()) },
```

Make sure you have the values in appsettings.json or your secrets manager.
