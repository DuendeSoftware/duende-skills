# Fixing CryptographicException in Kubernetes

The issue is that each pod generates its own Data Protection keys. When requests hit different pods, they can't decrypt each other's data.

## Fix: Share Data Protection Keys

```csharp
using Microsoft.AspNetCore.DataProtection;
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
app.Run();
```

This persists the keys in Redis so all 3 replicas can share them. Make sure `SetApplicationName` is the same string on all instances.
