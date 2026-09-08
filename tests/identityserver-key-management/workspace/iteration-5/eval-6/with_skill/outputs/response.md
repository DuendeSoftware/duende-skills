# Manual Key Rotation — Phase 2: Start Signing with the New Key

In **Phase 1** you announced the new key (signed with the old key, published the new key as a validation key) and waited for client/API caches to refresh. Now in **Phase 2** you **swap** the roles:

- **New key** becomes the active **signing** credential (`AddSigningCredential`).
- **Old key** stays registered as a **validation** key (`AddValidationKey`) so tokens already issued with it still validate.

Automatic key management stays **disabled** since you're managing keys yourself.

## Program.cs

```csharp
using Duende.IdentityServer.Models;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

// === MANUAL ROTATION PHASE 2: sign with the NEW key, validate the OLD key ===
var idsvrBuilder = builder.Services.AddIdentityServer(options =>
    {
        // Static key management: we control the keys, so turn automatic management off.
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

// Phase 2: the NEW key is now the active signing credential...
idsvrBuilder.AddSigningCredential(newKey, SecurityAlgorithms.RsaSha256);

// ...and the OLD key is kept only for validating tokens signed before the swap.
idsvrBuilder.AddValidationKey(oldKey, SecurityAlgorithms.RsaSha256);

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## What happens next

- New tokens are now signed with the **new** key; both keys remain published in JWKS so consumers accept tokens signed by either.
- **Wait** until all tokens signed with the **old** key have expired (default access token lifetime is ~1 hour).
- **Phase 3:** Remove `AddValidationKey(oldKey, ...)` so only the new key remains.

Double-check the direction of the swap: `AddSigningCredential` gets the **new** key, `AddValidationKey` gets the **old** key. Getting these backwards would sign with a key clients haven't cached (or would drop validation for in-flight tokens).
