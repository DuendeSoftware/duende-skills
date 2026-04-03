# Data Protection for Kubernetes IdentityServer Deployment

## Problem

The `CryptographicException` errors you're seeing are because each Kubernetes pod has its own Data Protection keys. When a request that was started on one pod gets routed to a different pod, that pod can't decrypt the data.

## Solution

You need to configure ASP.NET Core Data Protection to use a shared store.

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddDataProtection()
    .PersistKeysToStackExchangeRedis(
        ConnectionMultiplexer.Connect("redis-server:6379"),
        "DataProtection-Keys")
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

## Explanation

- **PersistKeysToStackExchangeRedis**: Stores Data Protection keys in Redis so all pods can access them. You could also use SQL Server or Azure Blob Storage.
- **SetApplicationName**: Ensures all instances use the same application name so they can read each other's keys.
- Make sure your Redis instance is accessible from all pods and configured for persistence.
