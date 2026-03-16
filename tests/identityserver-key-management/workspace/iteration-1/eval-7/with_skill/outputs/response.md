# Fixing CryptographicException in Load-Balanced IdentityServer

## The Problem

The `CryptographicException: The key was not found in the key ring` error occurs because **ASP.NET Core Data Protection keys are not shared across your load-balanced instances**.

Here's what's happening:

1. IdentityServer encrypts signing keys at rest using ASP.NET Core Data Protection (`DataProtectKeys = true` by default).
2. Each instance generates its own data protection keys and stores them locally (by default in `{ContentRootPath}/keys` on the file system).
3. When Instance A creates and encrypts a signing key, Instance B cannot decrypt it because it has different data protection keys.
4. Instance B then throws `CryptographicException` when it tries to load the signing key encrypted by Instance A.

## The Fix

You need to:
1. Share data protection keys across all instances
2. Share the signing key storage across all instances

Here's the updated `Program.cs`:

```csharp
// Program.cs
using Duende.IdentityServer.Models;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");

// 1. Configure shared Data Protection across all instances
builder.Services.AddDataProtection()
    .PersistKeysToDbContext<DataProtectionDbContext>()
    .SetApplicationName("IdentityServer");

// 2. Configure IdentityServer with EF operational store for shared key storage
builder.Services.AddIdentityServer()
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString);
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

## What This Fixes

### Data Protection (`AddDataProtection`)

- **`PersistKeysToDbContext`** stores data protection keys in the database so all instances share the same encryption keys. You can also use `PersistKeysToAzureBlobStorage`, `PersistKeysToStackExchangeRedis`, or `PersistKeysToFileSystem` with a shared network path.
- **`SetApplicationName("IdentityServer")`** ensures all instances use the same application discriminator. Without this, each instance may use its own discriminator (derived from the content root path), causing data protection keys to be isolated per instance.

### Signing Key Storage (`AddOperationalStore`)

The default `FileSystemKeyStore` stores signing keys at `{ContentRootPath}/keys`. In a load-balanced deployment, each instance has its own local directory, so keys are not shared.

Switching to the **EF operational store** stores signing keys in the database, making them accessible to all instances. Alternatively, you could configure a shared file system path:

```csharp
options.KeyManagement.KeyPath = "/shared-mount/identity-keys";
```

But the database approach is generally more reliable for production deployments.

### Common Pitfall

These are **two separate concerns** that are often confused:
- **Data protection keys** = symmetric encryption keys used to encrypt signing keys at rest
- **Signing keys** = asymmetric keys used to sign tokens

Both must be shared across instances for a load-balanced deployment to work correctly.
