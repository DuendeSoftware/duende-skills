# Configure Shared Key Path, Cache Duration, and RSA Key Size

Update your `Program.cs` to configure the signing key storage path, cache duration, and RSA key size:

```csharp
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
    {
        // Store signing keys on a shared file system accessible by all instances
        options.KeyManagement.KeyPath = "/mnt/shared/identity-keys";

        // Cache keys for 1 hour instead of the default 24 hours
        options.KeyManagement.KeyCacheDuration = TimeSpan.FromHours(1);

        // Use 4096-bit RSA keys instead of the default 2048
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

## Configuration Details

### `KeyPath` — Shared File System Storage
- `options.KeyManagement.KeyPath = "/mnt/shared/identity-keys"` overrides the default path (`{ContentRootPath}/keys`).
- The `FileSystemKeyStore` writes signing keys to this directory. In a multi-instance deployment, this path should point to a shared volume (NFS mount, Azure File Share, etc.) so all instances read and write the same keys.
- Ensure all instances have read/write access to this directory.

### `KeyCacheDuration` — Reduced Cache Time
- `options.KeyManagement.KeyCacheDuration = TimeSpan.FromHours(1)` reduces the key cache duration from the default 24 hours to 1 hour.
- This means each instance re-reads keys from the store every hour. Useful when you want faster propagation of new keys across instances, at the cost of slightly more I/O.
- Note: If you reduce this, ensure your `PropagationTime` still exceeds the cache duration of your downstream clients and APIs.

### `RsaKeySize` — Larger RSA Keys
- `options.KeyManagement.RsaKeySize = 4096` increases the RSA key size from the default 2048 bits to 4096 bits.
- This provides stronger cryptographic security at the cost of slightly larger tokens and slower signing/verification operations.
- Only applies to RSA-based algorithms (RS256, RS384, RS512, PS256, PS384, PS512). ECDSA key sizes are determined by the algorithm (e.g., ES256 always uses P-256).

### Automatic Key Management Remains Enabled
Automatic key management is enabled by default (`Enabled = true`), so keys will be automatically created, rotated, and retired according to the default schedule (90-day rotation, 14-day propagation, 14-day retention).
