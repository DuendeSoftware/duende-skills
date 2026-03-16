# Configuring EF Operational Store and Data Protection for Multi-Instance Deployment

Here's the updated `Program.cs` that configures database-backed key storage via the EF operational store and shared data protection for a load-balanced deployment:

```csharp
// Program.cs
using Duende.IdentityServer.Models;
using Duende.IdentityServer.EntityFramework.DbContexts;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");

// Configure Data Protection for multi-instance deployment
builder.Services.AddDataProtection()
    .PersistKeysToDbContext<PersistedGrantDbContext>()
    .SetApplicationName("IdentityServer");

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

## What This Does

### EF Operational Store for Signing Keys

`AddOperationalStore` configures the Entity Framework operational store, which stores signing keys (among other operational data like persisted grants) in the database. This replaces the default `FileSystemKeyStore` that writes keys to the local `{ContentRootPath}/keys` directory.

With the operational store:
- All IdentityServer instances share the same signing keys via SQL Server
- Automatic key management (enabled by default) creates, rotates, and retires keys in the database
- No shared file system required between instances

### Data Protection Configuration

Data protection is critical for multi-instance deployments because IdentityServer encrypts signing keys at rest using ASP.NET Core Data Protection (`DataProtectKeys = true` by default). Without shared data protection:
- Keys encrypted by one instance can't be decrypted by another
- You'll see `CryptographicException: The key was not found in the key ring`

The configuration:
- **`PersistKeysToDbContext`** stores data protection keys in the database (you can also use `PersistKeysToAzureBlobStorage` or other providers)
- **`SetApplicationName("IdentityServer")`** ensures all instances use the same application discriminator, so data protection keys are shared across instances

### Automatic Key Management

Automatic key management remains enabled (the default). Keys rotate every 90 days with 14-day propagation and 14-day retention. The EF operational store handles the persistence transparently.
