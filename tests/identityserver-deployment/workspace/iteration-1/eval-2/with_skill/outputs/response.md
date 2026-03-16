# Fixing CryptographicException in Multi-Instance IdentityServer on Kubernetes

## Root Cause

The `CryptographicException` errors are caused by **ASP.NET Core Data Protection keys not being shared across your 3 Kubernetes replicas**. Each instance generates its own set of Data Protection keys on startup. When a user's request is load-balanced to a different instance than the one that encrypted the data (cookies, state parameters, etc.), the receiving instance doesn't have the key to decrypt it — resulting in `CryptographicException`.

Typical error messages you'll see:
- `CryptographicException: The key {GUID} was not found in the key ring`
- `Error unprotecting key with kid {Signing Key ID}`

## Solution: Shared Data Protection Configuration

### Step 1: Add Redis for Key Storage

First, add the Redis Data Protection NuGet package:

```bash
dotnet add package Microsoft.AspNetCore.DataProtection.StackExchangeRedis
dotnet add package StackExchange.Redis
```

### Step 2: Configure Data Protection in Program.cs

```csharp
using Duende.IdentityServer;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.EntityFrameworkCore;
using StackExchange.Redis;

var builder = WebApplication.CreateBuilder(args);

// Connect to Redis
var redis = ConnectionMultiplexer.Connect("redis-service:6379");

// Configure Data Protection for multi-instance
builder.Services.AddDataProtection()
    .PersistKeysToStackExchangeRedis(redis, "DataProtection-Keys")
    .SetApplicationName("IdentityServer");  // MUST be consistent across all instances

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

### Key Configuration Points

1. **`PersistKeysToStackExchangeRedis()`** — Stores Data Protection keys in Redis, which is accessible to all replicas. Alternatives include:
   - `PersistKeysToDbContext<T>()` — EF Core database
   - `PersistKeysToAzureBlobStorage()` — Azure Blob Storage
   - `PersistKeysToAWSSystemsManager()` — AWS Systems Manager

2. **`SetApplicationName("IdentityServer")`** — This is **critical**. Without an explicit application name, ASP.NET Core derives one from the content root path, which differs across container instances. All instances must use the same application name to share the same key ring.

3. **Optional: Protect keys at rest** — For additional security, encrypt the keys with a certificate or key vault:
   ```csharp
   .ProtectKeysWithCertificate(certificate)
   // or
   .ProtectKeysWithAzureKeyVault(keyIdentifier, tokenCredential)
   ```

## Don't Forget: Signing Keys Must Also Be Shared

Data Protection is only half the story. **IdentityServer's signing keys** (used to sign JWTs — id_tokens, access tokens) must also be shared across instances. The default file-system key store writes keys to a local `~/keys` directory, which is per-instance in containers.

For multi-instance deployments, use the **EF Core operational store** which includes `ISigningKeyStore`:

```csharp
builder.Services.AddIdentityServer()
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection"));
    })
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);
```

Or implement a custom `ISigningKeyStore` backed by shared storage.

## What NOT to Do

- **Do NOT use the default ephemeral/file-system Data Protection keys** — They are local to each container and lost on restart.
- **Do NOT use in-memory or file-based signing key storage** in multi-instance deployments — Each instance will generate different signing keys, causing token validation failures.
- **Do NOT skip `SetApplicationName()`** — Without it, key isolation between instances causes the same symptoms as not sharing keys at all.

## Redis Persistence Note

If using Redis for Data Protection keys, ensure Redis itself is configured with persistence (RDB snapshots or AOF). Otherwise, a Redis restart will lose all keys, causing widespread `CryptographicException` errors until new keys propagate.
