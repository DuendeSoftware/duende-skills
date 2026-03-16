# Manual Key Rotation - Phase 2

Here's the updated `Program.cs` for Phase 2 where we switch to the new signing key:

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

// Sign with the new key
var newKey = LoadNewKey();
idsvrBuilder.AddSigningCredential(newKey, SecurityAlgorithms.RsaSha256);

// Keep the old key for validating existing tokens
var oldKey = LoadOldKey();
idsvrBuilder.AddValidationKey(oldKey, SecurityAlgorithms.RsaSha256);

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

This registers the new key from `LoadNewKey()` as the active signing credential using RS256, and keeps the old key from `LoadOldKey()` as a validation key so that tokens signed with the previous key can still be verified by clients and APIs.

Once all tokens signed with the old key have expired, you can remove the `AddValidationKey` call entirely.
