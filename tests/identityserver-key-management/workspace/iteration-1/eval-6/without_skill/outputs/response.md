# Key Rotation Phase 2: Signing with New Key

Now that the new key has been announced, switch signing to it while keeping the old key for validation:

```csharp
using Duende.IdentityServer.Models;
using Microsoft.IdentityModel.Tokens;

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

// Sign with new key
var newKey = LoadNewKey();
idsvrBuilder.AddSigningCredential(newKey, SecurityAlgorithms.RsaSha256);

// Keep old key for validation
var oldKey = LoadOldKey();
idsvrBuilder.AddValidationKey(oldKey, SecurityAlgorithms.RsaSha256);

var app = builder.Build();
app.UseIdentityServer();
app.MapGet("/", () => "IdentityServer is running");
app.Run();
```

The new key handles all new token signing. The old key stays in JWKS so existing tokens can still be validated until they expire.
