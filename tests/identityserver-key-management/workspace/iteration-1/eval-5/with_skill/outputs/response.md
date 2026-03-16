# Phase 1: Migrating from Static to Automatic Key Management

Here's the updated `Program.cs` for Phase 1 of the migration — enabling automatic key management while keeping your existing static key as the active signing credential:

```csharp
// Program.cs
using Duende.IdentityServer.Models;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

// ============================================================
// Phase 1: Migration from static to automatic key management
// - Automatic key management is enabled (creates and announces new keys)
// - Static key from vault remains the active signing credential
// - Once all clients/APIs have cached the new automatic keys,
//   proceed to Phase 2 (remove AddSigningCredential, use AddValidationKey)
// ============================================================

var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    // Enable automatic key management (this is the default, but explicit for clarity)
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

// Keep the static key as the active signing credential.
// AddSigningCredential takes precedence over automatic keys.
// Automatic key management will create and announce its keys in discovery,
// but the static key continues to be used for signing.
var signingKey = GetSigningKeyFromVault();
idsvrBuilder.AddSigningCredential(signingKey, SecurityAlgorithms.RsaSha256);

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## How Phase 1 Works

1. **`KeyManagement.Enabled = true`** enables automatic key management. IdentityServer starts creating and rotating keys automatically.

2. **`AddSigningCredential`** registers the static key from Azure Key Vault as the active signing credential. When both static signing credentials and automatic keys exist, the static credential takes precedence for signing.

3. The automatic keys are announced in the discovery document (JWKS endpoint), so clients and APIs begin caching them alongside the static key.

## Next Steps

After all clients and APIs have refreshed their key caches (wait at least as long as the longest cache duration — default is 24 hours), proceed to **Phase 2**:

- Remove `AddSigningCredential` 
- Add `AddValidationKey` for the old static key
- Automatic keys now handle signing
- The static key remains in discovery for validation of existing tokens

Phase 3 (after tokens signed with the static key expire): Remove `AddValidationKey` entirely.
