# Phase 1: Migrating from Static to Automatic Key Management

In Phase 1, you enable automatic key management while keeping the existing static key as the active signing credential. This allows automatic keys to be announced in discovery while the static key continues signing.

## Updated Program.cs

```csharp
using Duende.IdentityServer.Models;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

// Phase 1: Enable automatic key management, keep static key for signing
// The static signing credential takes precedence over automatic keys.
// Automatic key management begins creating and announcing keys in discovery.
var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    // Automatic key management is enabled (this is the default, shown for clarity)
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

// Phase 1: Static key remains as the SIGNING credential
// It takes precedence over automatic keys for signing
var staticKey = GetSigningKeyFromVault();
idsvrBuilder.AddSigningCredential(staticKey, SecurityAlgorithms.RsaSha256);

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## Migration Phases Overview

- **Phase 1 (current)**: Automatic key management enabled + static key as `AddSigningCredential`. Static key signs tokens. Automatic keys are announced in discovery.
- **Phase 2 (next)**: Remove `AddSigningCredential`, change to `AddValidationKey` for the static key. Automatic keys now sign tokens.
- **Phase 3 (final)**: Remove the static key entirely. Fully automatic key management.

Wait until all APIs and clients have refreshed their caches before moving to Phase 2.
