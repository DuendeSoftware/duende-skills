# Manual Key Rotation - Phase 2

Now that the new key has been announced and clients have updated their caches, switch to signing with the new key and keep the old one for validation.

Updated `Program.cs`:

```csharp
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

var idsvrBuilder = builder.Services.AddIdentityServer(options =>
    {
        options.KeyManagement.Enabled = false;
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

// Use the new key for signing
var newKey = LoadNewKey();
idsvrBuilder.AddSigningCredential(newKey, "RS256");

// Keep old key around for validating existing tokens
var oldKey = LoadOldKey();
idsvrBuilder.AddValidationKey(oldKey, "RS256");

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

The new key signs all new tokens. The old key remains published in the discovery document so that tokens issued with it can still be validated until they expire.
