# Shared Key Path, Cache Duration, and Larger RSA Keys

All three of these are `KeyManagementOptions` on the automatic key manager, so keep automatic key management enabled and just set the options:

| Requirement | Option | Value |
| --- | --- | --- |
| Store keys on shared file system | `KeyPath` | `"/mnt/shared/identity-keys"` |
| Cache keys for 1 hour | `KeyCacheDuration` | `TimeSpan.FromHours(1)` |
| 4096-bit RSA keys | `RsaKeySize` | `4096` |

## Program.cs

```csharp
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
    {
        // Store signing keys on the shared file system so all instances see them
        options.KeyManagement.KeyPath = "/mnt/shared/identity-keys";

        // Cache keys from the store for 1 hour (default is 24 hours)
        options.KeyManagement.KeyCacheDuration = TimeSpan.FromHours(1);

        // Generate 4096-bit RSA signing keys (default is 2048)
        options.KeyManagement.RsaKeySize = 4096;
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

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## Notes

- **Automatic key management stays enabled** — these options only tune where keys live, how long they're cached, and their RSA size.
- **Shared path:** `/mnt/shared/identity-keys` must be readable/writable by every instance. Exclude it from source control. Also ensure Data Protection is configured for shared persistence so the keys written there can be decrypted by all instances (the `KeyPath` only shares the key *files*, not the Data Protection key ring that encrypts them).
- **Cache duration:** A shorter `KeyCacheDuration` (1 hour) means instances pick up newly created/rotated keys sooner, at the cost of more frequent store reads. Make sure your `PropagationTime` still comfortably exceeds this cache window.
- **Key size:** 4096-bit RSA keys are stronger but slightly slower to generate and sign with; this applies to newly created keys.
