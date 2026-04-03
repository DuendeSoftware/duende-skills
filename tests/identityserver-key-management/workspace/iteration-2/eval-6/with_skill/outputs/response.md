# Phase 2: Switch Signing to New Key, Keep Old Key for Validation

In Phase 2 of manual key rotation, the new key has been announced and all clients/APIs have refreshed their caches. Now you switch to signing with the new key and keep the old key as a validation key so existing tokens can still be validated.

Update your `Program.cs`:

```csharp
using Duende.IdentityServer.Models;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

// Phase 2: Sign with the new key, keep old key for validation
var idsvrBuilder = builder.Services.AddIdentityServer(options =>
    {
        // Disable automatic key management - using static keys
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

// Sign with the NEW key
var newKey = LoadNewKey();
idsvrBuilder.AddSigningCredential(newKey, SecurityAlgorithms.RsaSha256);

// Keep the OLD key for validation of existing tokens
var oldKey = LoadOldKey();
idsvrBuilder.AddValidationKey(oldKey, SecurityAlgorithms.RsaSha256);

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## Manual Key Rotation Phases

### Phase 1 (Completed) — Announce the New Key
- Old key was the signing credential, new key was added as a validation key.
- Clients and APIs cached the new key from the JWKS endpoint.

### Phase 2 (Current) — Sign with the New Key
- `AddSigningCredential` now uses the **new** key from `LoadNewKey()` — all new tokens are signed with this key.
- `AddValidationKey` registers the **old** key from `LoadOldKey()` — it remains in the discovery document so tokens signed with the old key can still be validated.
- Both keys appear in the JWKS endpoint.
- **Wait** until all tokens signed with the old key have expired (default access token lifetime is 1 hour, but consider any longer-lived tokens).

### Phase 3 — Remove the Old Key
- Remove the `AddValidationKey` call. Only the new key remains.
- The old key is no longer published in discovery.

## Important Notes
- `KeyManagement.Enabled = false` is required since we're managing keys manually.
- The order matters: `AddSigningCredential` is called with the **new** key (active signer), and `AddValidationKey` is called with the **old** key (passive validation only).
- Both keys use `SecurityAlgorithms.RsaSha256` (RS256) to maintain algorithm consistency.
