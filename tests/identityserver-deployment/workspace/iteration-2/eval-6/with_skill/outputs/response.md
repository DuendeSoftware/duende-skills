# Distributed Caching for Multi-Instance IdentityServer

## Root Cause of Failing OIDC Flows

Your external OIDC login flows are failing intermittently because IdentityServer uses `IDistributedCache` internally for several features. The default `IDistributedCache` implementation is in-memory and per-instance. When a user starts an OIDC flow on instance A (which stores state data in the cache) and gets load-balanced to instance B for the callback, instance B cannot find the state data.

## Features That Require Distributed Cache

IdentityServer uses `IDistributedCache` for:

1. **OIDC state data formatter** — Stores external provider state server-side instead of in the URL. This is why your external OIDC logins fail intermittently.
2. **JWT replay cache** — Prevents JWT client credentials replay across instances.
3. **Device flow throttling** — Rate-limits polling across instances.
4. **Authorization parameter store (PAR)** — Stores Pushed Authorization Request data.

Without a shared cache, state created on one instance cannot be validated on another.

## Solution

Configure a distributed cache implementation like Redis:

```csharp
using Duende.IdentityServer;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

// Configure a shared distributed cache for multi-instance deployment
builder.Services.AddStackExchangeRedisCache(options =>
{
    options.Configuration = "redis-server:6379";
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

### Required NuGet Package

```xml
<PackageReference Include="Microsoft.Extensions.Caching.StackExchangeRedis" Version="8.0.0" />
```

## Key Points

- **Do NOT use the default in-memory `DistributedCache`** for multi-instance deployments. The default `MemoryDistributedCache` is per-process and not actually distributed.
- You can also use `AddSqlServerCache` or `AddCosmosCache` depending on your infrastructure.
- The OIDC state data formatter stores external provider state in `IDistributedCache`, and without a shared cache, state created on instance A cannot be validated on instance B — this is the direct cause of your intermittent external OIDC login failures.
