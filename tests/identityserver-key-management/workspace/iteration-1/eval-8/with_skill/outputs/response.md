# Custom Key Storage Path, Cache Duration, and RSA Key Size

Here's the updated `Program.cs` that configures a shared file system path for signing keys, a 1-hour key cache duration, and 4096-bit RSA keys:

```csharp
// Program.cs
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    // Store signing keys on a shared file system
    options.KeyManagement.KeyPath = "/mnt/shared/identity-keys";

    // Cache keys for 1 hour instead of the default 24 hours
    options.KeyManagement.KeyCacheDuration = TimeSpan.FromHours(1);

    // Use 4096-bit RSA keys instead of the default 2048-bit
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

### `KeyPath = "/mnt/shared/identity-keys"`

Overrides the default key storage path (`{ContentRootPath}/keys`) to a shared file system. This is useful in load-balanced deployments where all instances need access to the same signing keys. Ensure all instances have read/write access to this directory.

### `KeyCacheDuration = TimeSpan.FromHours(1)`

Reduces the key cache duration from the default 24 hours to 1 hour. This means IdentityServer will re-read keys from the store every hour. A shorter cache duration means key changes propagate faster across instances, but increases storage reads.

### `RsaKeySize = 4096`

Increases RSA key size from the default 2048 bits to 4096 bits. This provides stronger cryptographic security at the cost of slightly larger tokens and slower signing/verification operations. Consider the performance tradeoff — 2048-bit RSA is still considered secure for most use cases.

### Automatic Key Management

Automatic key management remains enabled (the default). Keys are created, rotated, and retired automatically with the standard lifecycle (90-day rotation, 14-day propagation, 14-day retention).

### Important: Data Protection

Since `DataProtectKeys` is `true` by default, signing keys stored at `/mnt/shared/identity-keys` are encrypted using ASP.NET Core Data Protection. Make sure data protection is also configured for shared access in a multi-instance deployment:

```csharp
builder.Services.AddDataProtection()
    .PersistKeysToFileSystem(new DirectoryInfo("/mnt/shared/dataprotection-keys"))
    .SetApplicationName("IdentityServer");
```
