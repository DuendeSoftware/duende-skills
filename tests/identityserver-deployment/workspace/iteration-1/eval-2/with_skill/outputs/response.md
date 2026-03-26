# Fixing CryptographicException in Multi-Instance Kubernetes Deployment

## Root Cause

The intermittent `CryptographicException` errors occur because **Data Protection keys are not shared across your 3 Kubernetes replicas**. By default, ASP.NET Core generates Data Protection keys per instance and stores them in a local directory. When user A authenticates on instance 1 (which encrypts the cookie with instance 1's keys), and a subsequent request is routed to instance 2, that instance cannot decrypt the cookie because it has different keys.

## Solution: Configure Shared Data Protection

```csharp
using Microsoft.AspNetCore.DataProtection;
using StackExchange.Redis;

var builder = WebApplication.CreateBuilder(args);

// Configure Data Protection with shared storage
var redis = ConnectionMultiplexer.Connect("redis-service:6379");

builder.Services.AddDataProtection()
    // Persist keys to a shared Redis instance
    .PersistKeysToStackExchangeRedis(redis, "DataProtection-Keys")
    // Set a consistent application name across ALL instances
    .SetApplicationName("IdentityServer")
    // Optionally protect keys at rest with a certificate
    .ProtectKeysWithCertificate(/* your X509Certificate2 */);

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## Key Configuration Points

### 1. Shared Key Persistence (`PersistKeysTo*`)

You **must** persist Data Protection keys to a shared store accessible by all replicas. Options include:

- **`PersistKeysToStackExchangeRedis`** — Recommended for Kubernetes; fast and commonly available
- **`PersistKeysToDbContext`** — Uses Entity Framework; good if you already have a shared database
- **`PersistKeysToAzureBlobStorage`** — For Azure deployments
- **`PersistKeysToAWSSystemsManager`** — For AWS deployments

**Important**: If using Redis, ensure Redis itself has persistence configured (RDB snapshots or AOF). Without Redis persistence, a Redis restart loses all Data Protection keys.

### 2. Consistent Application Name (`SetApplicationName`)

`SetApplicationName("IdentityServer")` ensures all instances use the same key ring. Without this, .NET may isolate keys by application path, meaning different pods with different filesystem paths can't share keys.

### 3. Signing Key Store Must Also Be Shared

Data Protection keys and IdentityServer signing keys are **separate**:

| Aspect | Data Protection Keys | IdentityServer Signing Keys |
|--------|--------------------|-----------------------------|
| Purpose | Encrypt cookies, grants, sessions | Sign JWT tokens |
| Storage | `PersistKeysTo*()` | `ISigningKeyStore` |

For multi-instance deployments, the **signing key store must also be shared**. The default file-system signing key store is per-instance and won't work. Use the **Entity Framework operational store** which includes `ISigningKeyStore`:

```csharp
builder.Services.AddIdentityServer()
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString);
    });
```

Or implement a custom `ISigningKeyStore` backed by shared storage.

### 4. Do NOT Use Default Keys

The default Data Protection configuration uses ephemeral or file-system-based keys that are local to each container. These keys are lost when pods restart and cannot be read by other instances. **Never use the default in a multi-instance deployment.**

## Symptoms of Data Protection Failure

- `CryptographicException`: "The key {id} was not found in the key ring"
- "Error unprotecting key with kid {Signing Key ID}"
- Intermittent authentication failures after login
- Session cookies becoming invalid when hitting a different pod
