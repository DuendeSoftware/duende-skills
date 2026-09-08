# Migration Phase 1: Enable Automatic Key Management, Keep Signing with the Static Key

Migrating from static keys to Automatic Key Management is a **three-phase** process. In **Phase 1** you turn on automatic key management but continue signing with your existing static key. This is safe because a **manually registered signing credential takes precedence** over automatically managed keys — so tokens are still signed with your vault key while IdentityServer quietly starts creating and *announcing* its own keys in discovery (JWKS).

The critical rule for Phase 1:

- ✅ Enable automatic key management (`Enabled = true`, which is also the default).
- ✅ Keep the static key registered with `AddSigningCredential(...)` so it stays the active signer.
- ❌ Do **not** add the static key as a validation key yet — that's Phase 2, after the automatic keys have propagated to all clients/APIs.

## Program.cs

```csharp
using Duende.IdentityServer.Models;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

// === MIGRATION PHASE 1: static -> automatic key management ===
// Automatic key management is ENABLED so IdentityServer begins creating and
// announcing managed keys in discovery. The static key from the vault remains
// the active signing credential (manual credentials take precedence), so tokens
// are still signed with it while the new automatic keys propagate.
var idsvrBuilder = builder.Services.AddIdentityServer(options =>
    {
        options.KeyManagement.Enabled = true; // default is true; explicit for clarity during migration
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

// Keep the existing static key from Azure Key Vault as the ACTIVE signing credential.
// It takes precedence over the automatically managed keys during Phase 1.
var staticKey = GetSigningKeyFromVault();
idsvrBuilder.AddSigningCredential(staticKey, SecurityAlgorithms.RsaSha256);

// NOTE: Do NOT call AddValidationKey for the static key here.
// Registering it for validation is Phase 2, once the automatic keys have
// been announced and all client/API caches have refreshed.

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## What happens next

- **Wait** until every API and client has refreshed its key cache and picked up the announced automatic keys (respect `PropagationTime` / cache durations — often 24 hours or more).
- **Phase 2:** Remove the static `AddSigningCredential` and instead register the static key with `AddValidationKey(...)`. IdentityServer then signs with an automatic key while old tokens signed by the static key still validate.
- **Phase 3:** Once all tokens signed by the static key have expired, remove the static key entirely and rely solely on automatic key management.
