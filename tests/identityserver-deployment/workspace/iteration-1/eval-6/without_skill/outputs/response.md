# Setting Up Distributed Caching for Multi-Instance IdentityServer

## The Problem

In a multi-instance deployment, each instance has its own in-memory cache by default. When OIDC login flows involve external providers, state data may be created on one instance but the callback may hit a different instance. If the cache isn't shared, that state data is lost.

## Solution: Use Redis as Distributed Cache

### Step 1: Install the Package

```bash
dotnet add package Microsoft.Extensions.Caching.StackExchangeRedis
```

### Step 2: Configure Redis

```csharp
using Duende.IdentityServer;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddStackExchangeRedisCache(options =>
{
    options.Configuration = "redis-service:6379";
    options.InstanceName = "IdentityServer:";
});

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## Why This Matters

IdentityServer uses `IDistributedCache` for several things:
- Storing state for OIDC flows with external providers
- Caching certain data during authentication workflows

Without a shared cache, requests that start on one instance and complete on another will fail because the second instance can't find the state data from the first.

Do not use `AddDistributedMemoryCache()` in a multi-instance deployment — it only caches locally within each process and doesn't share across instances.

## Alternatives

If Redis isn't available, you can use SQL Server:

```csharp
builder.Services.AddDistributedSqlServerCache(options =>
{
    options.ConnectionString = connectionString;
    options.SchemaName = "dbo";
    options.TableName = "Cache";
});
```
