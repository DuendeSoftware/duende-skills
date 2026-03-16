# Fixing CryptographicException in Kubernetes IdentityServer Deployment

## The Problem

When you deploy IdentityServer to Kubernetes with multiple replicas, each pod generates its own Data Protection keys. These keys are used to encrypt cookies, anti-forgery tokens, and other sensitive data. When a request hits a different pod than the one that encrypted the data, it can't decrypt it — causing `CryptographicException`.

## Solution: Share Data Protection Keys

You need to persist Data Protection keys to a shared store that all replicas can access.

### Step 1: Add Required Packages

```bash
dotnet add package Microsoft.AspNetCore.DataProtection.StackExchangeRedis
dotnet add package StackExchange.Redis
```

### Step 2: Configure Shared Data Protection

```csharp
using Duende.IdentityServer;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.EntityFrameworkCore;
using StackExchange.Redis;

var builder = WebApplication.CreateBuilder(args);

var redis = ConnectionMultiplexer.Connect("redis-service:6379");

builder.Services.AddDataProtection()
    .PersistKeysToStackExchangeRedis(redis, "DataProtection-Keys")
    .SetApplicationName("IdentityServer");

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## Key Points

1. **`PersistKeysToStackExchangeRedis()`** stores the keys in Redis where all pods can reach them. You can also use `PersistKeysToDbContext()` with a database, or `PersistKeysToAzureBlobStorage()` for Azure.

2. **`SetApplicationName("IdentityServer")`** ensures all instances use the same application discriminator. Without this, each container may derive a different name from its file path, preventing key sharing.

3. **Don't use the default key storage** — The default stores keys on the local file system or in memory, which doesn't work across multiple pods.

4. Optionally, protect keys at rest with a certificate:
   ```csharp
   .ProtectKeysWithCertificate(cert)
   ```

## Verification

After deploying, check that all pods can read the shared keys by examining the Redis key `DataProtection-Keys`. You should see XML key entries that are consistent across all pods.

Try logging in from multiple browser sessions and verify that you no longer get intermittent `CryptographicException` errors when requests hit different pods.
