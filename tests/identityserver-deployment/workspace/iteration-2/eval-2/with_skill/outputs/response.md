# Data Protection Configuration for Kubernetes Multi-Instance IdentityServer

## Root Cause

The `CryptographicException` errors occur because **ASP.NET Core Data Protection keys are not shared across your 3 Kubernetes replicas**. By default, each instance generates its own Data Protection keys stored locally. When a user's request is load-balanced to a different instance, that instance cannot decrypt cookies, state parameters, or other protected data created by another instance.

> **Cross-cutting concern:** Data protection is critical for all Duende products — both IdentityServer and BFF. See [ASP.NET Core Data Protection](https://docs.duendesoftware.com/general/data-protection/) for comprehensive guidance covering all Duende SDKs.

## Solution

Configure Data Protection with shared, persistent storage and an explicit application name. Additionally, ensure the **signing key store** is also shared across instances.

### Updated Program.cs

```csharp
using Duende.IdentityServer;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

// Configure Data Protection for multi-instance deployment
builder.Services.AddDataProtection()
    .PersistKeysToStackExchangeRedis(
        ConnectionMultiplexer.Connect("redis-server:6379"),
        "DataProtection-Keys")
    .SetApplicationName("My.IdentityServer");  // Must be the same across all instances

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients)
    // Use EF operational store for shared signing key storage
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection"));
    });

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

### Required NuGet packages

```xml
<PackageReference Include="Microsoft.AspNetCore.DataProtection.StackExchangeRedis" Version="8.0.0" />
```

## Key Points

1. **`PersistKeysToStackExchangeRedis`** (or `PersistKeysToDbContext`, `PersistKeysToAzureBlobStorage`, etc.) stores Data Protection keys in a shared durable store accessible by all instances.

2. **`SetApplicationName("My.IdentityServer")`** must be identical across all instances. Without this, each instance may isolate its keys under a different application name.

3. **The signing key store must also be shared.** The default file-system signing key store (`{ContentRootPath}/keys`) is per-instance. Use the EF operational store (`AddOperationalStore`) which includes `ISigningKeyStore`, or configure a custom shared store. Without this, each instance generates different signing keys.

4. **Never use default ephemeral or file-system-based Data Protection keys** for multi-instance deployments. The default file-based storage uses ephemeral paths in containers that don't persist across restarts and aren't shared across pods.

5. If using Redis for Data Protection key persistence, **configure Redis with persistence** (RDB snapshots or AOF) to survive Redis restarts.
