# Migrating to Automatic Key Management - Phase 1

Here's the updated `Program.cs` to enable automatic key management while keeping your static key active:

```csharp
// Program.cs
using Duende.IdentityServer.Models;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

var idsvrBuilder = builder.Services.AddIdentityServer()
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

// Keep the current static key for signing
var signingKey = GetSigningKeyFromVault();
idsvrBuilder.AddSigningCredential(signingKey, SecurityAlgorithms.RsaSha256);

// Also add the key for validation so existing tokens can still be verified
idsvrBuilder.AddValidationKey(signingKey, SecurityAlgorithms.RsaSha256);

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

Since automatic key management is enabled by default in Duende IdentityServer, you don't need to explicitly set it. The automatic key management system will start generating new keys while your static key continues to be used for signing.

Once all clients have refreshed their cached keys and picked up the new automatic keys (typically 24 hours), you can remove the static signing credential and let automatic key management take over completely.
