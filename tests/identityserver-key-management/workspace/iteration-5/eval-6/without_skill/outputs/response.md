# Phase 2 Manual Key Rotation: Sign with the New Key, Validate the Old

Since caches have already refreshed with the newly announced key, you can now promote it to the active signing key while still accepting tokens that were signed with the old key. In Duende IdentityServer this means registering the new key with `AddSigningCredential` and the old key with `AddValidationKey`. Automatic key management stays off because you're rotating keys manually.

## Program.cs

```csharp
using Duende.IdentityServer.Models;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

var idsvrBuilder = builder.Services.AddIdentityServer(options =>
    {
        // Manual rotation - keep automatic key management disabled
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

var oldKey = LoadOldKey();
var newKey = LoadNewKey();

// Sign new tokens with the new key
idsvrBuilder.AddSigningCredential(newKey, SecurityAlgorithms.RsaSha256);

// Keep the old key available so previously issued tokens still validate
idsvrBuilder.AddValidationKey(oldKey, SecurityAlgorithms.RsaSha256);

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## Next step (Phase 3)

Once every token signed with the old key has expired (typically after the access token lifetime, around an hour), remove the `AddValidationKey(oldKey, ...)` line so only the new key remains in use.
