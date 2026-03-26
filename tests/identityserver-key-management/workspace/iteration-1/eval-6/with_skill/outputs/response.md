# Phase 2: Manual Key Rotation — Switch Signing to New Key

In Phase 2, the new key has been announced and caches have refreshed. Now we switch signing to the new key and keep the old key for validation of existing tokens.

## Updated Program.cs

```csharp
using Duende.IdentityServer.Models;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

// Phase 2: New key signs, old key validates
var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    // Disable automatic key management — using static keys
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

// NEW key is now the signing credential
var newKey = LoadNewKey();
idsvrBuilder.AddSigningCredential(newKey, SecurityAlgorithms.RsaSha256);

// OLD key is kept for validation of existing tokens
var oldKey = LoadOldKey();
idsvrBuilder.AddValidationKey(oldKey, SecurityAlgorithms.RsaSha256);

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## Phase 2 Key Points

- `AddSigningCredential(newKey, ...)` — the NEW key now signs all new tokens
- `AddValidationKey(oldKey, ...)` — the OLD key remains in the JWKS discovery document for token validation
- Wait until all tokens signed with the old key have expired before moving to Phase 3 (removing the old key entirely)
- The default access token lifetime is 1 hour, so wait at least that long after Phase 2
