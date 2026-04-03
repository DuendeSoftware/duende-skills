# Migrate to Automatic Key Management - Phase 1

For Phase 1, you want to enable automatic key management while keeping your existing static signing key active. The static key will continue to be used for signing while the automatic key management system creates and publishes new keys.

Updated `Program.cs`:

```csharp
using Duende.IdentityServer.Models;

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

// Keep existing static key for signing during transition
var signingKey = GetSigningKeyFromVault();
idsvrBuilder.AddSigningCredential(signingKey, "RS256");

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

Since automatic key management is enabled by default, you don't need to explicitly set it. The `AddSigningCredential` call registers your static key. As the automatic keys get created and announced, clients will begin caching them. Once you're confident all clients have the new keys, you can move to Phase 2.
