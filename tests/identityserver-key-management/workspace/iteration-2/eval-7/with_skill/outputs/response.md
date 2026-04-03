# Fixing CryptographicException in Load-Balanced IdentityServer

## The Problem

The error `CryptographicException: The key was not found in the key ring` occurs because **ASP.NET Core Data Protection keys are not shared across your load-balanced instances**.

Here's what's happening:
1. IdentityServer's automatic key management stores signing keys encrypted using ASP.NET Core Data Protection (`DataProtectKeys = true` by default).
2. By default, Data Protection stores its encryption keys on the local file system with machine-specific protection.
3. When Instance A creates a signing key, it encrypts it with Instance A's Data Protection key.
4. When Instance B tries to load that signing key, it can't decrypt it because it has a different Data Protection key — resulting in the `CryptographicException`.

## The Fix

You need to configure **shared Data Protection key persistence** so all instances use the same encryption keys. Additionally, switching from the default file-based signing key store to a shared database store is recommended.

Update your `Program.cs`:

```csharp
using Duende.IdentityServer.Models;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");

// Fix: Configure shared Data Protection across all instances
builder.Services.AddDataProtection()
    .PersistKeysToDbContext<Duende.IdentityServer.EntityFramework.DbContexts.PersistedGrantDbContext>()
    .SetApplicationName("MyIdentityServer");

builder.Services.AddIdentityServer()
    // Use EF operational store for shared signing key storage
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

## What Changed and Why

### 1. Shared Data Protection (`AddDataProtection`)
- `PersistKeysToDbContext<PersistedGrantDbContext>()` stores Data Protection keys in the database instead of the local file system. All instances read from the same key ring.
- `SetApplicationName("MyIdentityServer")` ensures all instances use the same application name. Without this, each instance may isolate its keys under a different app name, even with shared persistence.

### 2. Shared Signing Key Storage (`AddOperationalStore`)
- Replaces the default file-based signing key store (`FileSystemKeyStore` writing to `{ContentRootPath}/keys`) with a database-backed store.
- All instances read and write signing keys to the same SQL Server database.
- This eliminates the need for a shared file system mount and is the recommended approach for load-balanced deployments.

### Additional Recommendations
- After making these changes, you may need to **clear old signing keys** from the default `keys` directory on each instance to avoid confusion.
- Run EF migrations to ensure the database tables exist:
  ```bash
  dotnet ef migrations add InitialIdentityServer -c PersistedGrantDbContext
  dotnet ef database update -c PersistedGrantDbContext
  ```
- Consider adding `ProtectKeysWithCertificate()` for additional encryption of Data Protection keys at rest in the database.
