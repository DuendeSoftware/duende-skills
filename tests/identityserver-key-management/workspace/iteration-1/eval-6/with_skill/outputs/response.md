# Phase 2: Manual Key Rotation — Switch Signing to New Key

Here's the updated `Program.cs` for Phase 2 of manual key rotation — the new key has been announced and caches have refreshed, so we swap signing to the new key and keep the old key for validation:

```csharp
// Program.cs
using Duende.IdentityServer.Models;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

// ============================================================
// Phase 2: Manual Key Rotation
// - New key is now the active signing credential
// - Old key remains as validation key for existing tokens
// - After all tokens signed with the old key expire (default: 1 hour),
//   proceed to Phase 3 (remove the old validation key entirely)
// ============================================================

var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    // Disable automatic key management — we're managing keys manually
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

// NEW key is now the active signing credential
var newKey = LoadNewKey();
idsvrBuilder.AddSigningCredential(newKey, SecurityAlgorithms.RsaSha256);

// OLD key remains for validation of existing tokens
var oldKey = LoadOldKey();
idsvrBuilder.AddValidationKey(oldKey, SecurityAlgorithms.RsaSha256);

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## What Changed from Phase 1

In Phase 1, the **old key** was the signing credential and the **new key** was the validation key (announced for caching). Now in Phase 2:

- **`AddSigningCredential(newKey, ...)`** — The new key is now the active signing credential. All new tokens are signed with this key.
- **`AddValidationKey(oldKey, ...)`** — The old key remains in the discovery document so clients and APIs can still validate tokens that were signed with it.

## Next Steps (Phase 3)

After all tokens signed with the old key have expired (the default access token lifetime is 1 hour, but consider refresh tokens and longer-lived tokens), remove the old validation key:

```csharp
// Phase 3: Only the new key remains
idsvrBuilder.AddSigningCredential(newKey, SecurityAlgorithms.RsaSha256);
// No more AddValidationKey for oldKey
```
