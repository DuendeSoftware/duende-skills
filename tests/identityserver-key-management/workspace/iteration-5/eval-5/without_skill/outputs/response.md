# Phase 1: Enable Automatic Key Management While Keeping the Static Key

For Phase 1 of your migration, you want automatic key management running (so it can start generating and publishing its own keys), while your existing static key from Key Vault continues to be the one actually signing tokens. In Duende IdentityServer a manually added signing credential takes priority over the automatically managed keys, so keeping `AddSigningCredential` in place means your static key stays the active signer.

## Program.cs

```csharp
using Duende.IdentityServer.Models;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

// Phase 1 of static -> automatic key management migration.
// Automatic key management is enabled (this is the default) so it starts
// creating and announcing keys, but the static Key Vault key remains the
// active signing credential until the new keys have propagated.
var idsvrBuilder = builder.Services.AddIdentityServer(options =>
    {
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

// Keep the static key as the active signing credential during Phase 1.
var staticKey = GetSigningKeyFromVault();
idsvrBuilder.AddSigningCredential(staticKey, SecurityAlgorithms.RsaSha256);

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## Next steps

- Let this run long enough for all clients and APIs to refresh their JWKS caches so they know about the newly generated automatic keys.
- In a later phase you'll stop signing with the static key (letting automatic keys take over) and register the static key as a validation key so tokens already issued remain valid.
- Finally, once no tokens signed by the static key remain, you can remove it entirely.

Note that in Phase 1 you should **not** register the static key as a validation key yet — it's still the active signing key, and its public key is already available for validation.
