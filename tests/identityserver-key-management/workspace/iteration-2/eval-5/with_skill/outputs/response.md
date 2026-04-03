# Phase 1: Enable Automatic Key Management While Keeping Static Signing Key

In Phase 1 of migrating from static to automatic key management, you enable automatic key management so it begins creating and announcing keys in discovery, while your existing static key remains the active signing credential (it takes precedence over automatic keys).

Update your `Program.cs`:

```csharp
using Duende.IdentityServer.Models;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

// Phase 1: Enable automatic key management, keep static key for signing
// The static signing credential takes precedence over automatic keys.
// Automatic key management will begin creating and announcing keys in discovery.
var idsvrBuilder = builder.Services.AddIdentityServer(options =>
    {
        // Automatic key management is enabled by default (Enabled = true),
        // but we set it explicitly for clarity during migration.
        options.KeyManagement.Enabled = true;
    })
    .AddInMemoryClients(new List<Client>
    {
        new Client
        {
            ClientId = "web-app",
            ClientSecrets = { new Secret("secret".Sha256()) },
            AllowedGrantTypes = GrantTypes.Code,
            RedirectUris = { "https://localhost:5002/signin-oidc" },
            AllowedScopes = { "openid", "profile", "api1" }
        },
        new Client
        {
            ClientId = "machine-client",
            ClientSecrets = { new Secret("secret".Sha256()) },
            AllowedGrantTypes = GrantTypes.ClientCredentials,
            AllowedScopes = { "api1" }
        }
    })
    .AddInMemoryApiScopes(new List<ApiScope>
    {
        new ApiScope("api1", "My API")
    })
    .AddInMemoryIdentityResources(new List<IdentityResource>
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile()
    });

// Keep the existing static key as the active signing credential
// This takes precedence over automatic keys during Phase 1
var staticKey = GetSigningKeyFromVault();
idsvrBuilder.AddSigningCredential(staticKey, SecurityAlgorithms.RsaSha256);

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## Migration Phases Overview

### Phase 1 (Current) — Announce Automatic Keys
- Automatic key management is enabled and begins creating keys.
- The static key from `GetSigningKeyFromVault()` is registered via `AddSigningCredential`, so it takes precedence and remains the active signing key.
- Both the static key and the new automatic keys appear in the discovery document (JWKS), allowing clients and APIs to cache the new keys.
- **Wait** until all clients and APIs have refreshed their caches with the new automatic keys (at least 24 hours, or whatever your longest cache duration is).

### Phase 2 — Switch to Automatic Signing
- Remove `AddSigningCredential` and instead register the static key via `AddValidationKey` so it's still published for validation of existing tokens.
- Automatic key management takes over signing.

### Phase 3 — Remove Static Key
- Remove the static key entirely. Automatic key management handles everything.
