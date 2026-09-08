# Fixing `The key was not found in the key ring` in a Load-Balanced Deployment

## What's wrong

This is **not** an IdentityServer signing-key problem — it's an **ASP.NET Core Data Protection** problem. IdentityServer encrypts its signing keys at rest using Data Protection (`DataProtectKeys = true`). The error:

```
CryptographicException: The key {ID} was not found in the key ring
```

means one instance protected the signing keys with a **Data Protection key** that another instance doesn't have. By default, Data Protection writes its key ring to a **local, per-instance** location (the app's local folder / machine keys). Behind a load balancer each instance generates its **own** key ring, so instance B can read the signing-key row instance A wrote but **cannot decrypt it**.

Two things must be shared across all instances:

1. The **Data Protection key ring** (the keys that encrypt the signing keys) — must be persisted to shared storage with a stable application name.
2. The **signing keys** themselves — the default `keys` directory is local to each instance, so it must live in shared storage (or a database-backed store).

## The fix

### 1. Share the Data Protection key ring + pin the application name

```csharp
builder.Services.AddDataProtection()
    .PersistKeysToDbContext<MyDataProtectionDbContext>()   // shared DB key ring
    // or: .PersistKeysToFileSystem(new DirectoryInfo("/mnt/shared/dp-keys"))
    // or: .PersistKeysToAzureBlobStorage(blobUri)
    .SetApplicationName("My.IdentityServer");              // MUST be identical on every instance
```

`SetApplicationName` is critical: Data Protection isolates key rings by application name, so every instance (and every redeploy) must use the **same** string or they won't share keys.

### 2. Share the signing keys too (switch off default file storage)

The default `FileSystemKeyStore` writes to `{ContentRootPath}/keys`, which is local. Move it to shared storage — either a shared path or, preferably, the EF operational store:

```csharp
// Option A: shared file path
builder.Services.AddIdentityServer(options =>
{
    options.KeyManagement.KeyPath = "/mnt/shared/identity-keys";
});

// Option B (recommended): database-backed signing key store
builder.Services.AddIdentityServer()
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b => b.UseSqlServer(connectionString);
    });
```

## Full Program.cs

```csharp
using Duende.IdentityServer.Models;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.DataProtection.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

var connectionString = builder.Configuration.GetConnectionString("DefaultConnection")!;

builder.Services.AddDbContext<DataProtectionKeysContext>(o => o.UseSqlServer(connectionString));

builder.Services.AddIdentityServer()
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
    .AddInMemoryApiScopes(new List<ApiScope> { new ApiScope("api1", "My API") })
    .AddInMemoryIdentityResources(new List<IdentityResource>
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile()
    })
    // Share the signing keys across instances via the operational store
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b => b.UseSqlServer(connectionString);
    });

// Share the Data Protection key ring and fix the application name
builder.Services.AddDataProtection()
    .PersistKeysToDbContext<DataProtectionKeysContext>()
    .SetApplicationName("My.IdentityServer");

var app = builder.Build();
app.UseIdentityServer();
app.MapGet("/", () => "IdentityServer is running");
app.Run();

public class DataProtectionKeysContext : DbContext, IDataProtectionKeyContext
{
    public DataProtectionKeysContext(DbContextOptions<DataProtectionKeysContext> options) : base(options) { }
    public DbSet<DataProtectionKey> DataProtectionKeys { get; set; } = null!;
}
```

## Summary

| Symptom | Root cause | Fix |
| --- | --- | --- |
| `The key {ID} was not found in the key ring` | DP key ring is per-instance | `AddDataProtection().PersistKeysTo...().SetApplicationName(...)` |
| Works locally, fails when scaled out | Signing keys in local `keys` folder | Move to shared path or EF operational store |

After deploying, existing DP-protected keys that were written before the fix may still be unreadable — if you continue to see errors, let IdentityServer regenerate keys once the shared, consistent Data Protection configuration is in place.
