# Distributed Caching for Multi-Instance IdentityServer

## Why Your OIDC External Login Flows Are Failing

The intermittent failures in external OIDC login flows are caused by the **OIDC state data formatter** storing state data in `IDistributedCache`. Here's what happens:

1. User clicks "Login with Google" on **instance A**
2. Instance A generates a state parameter and stores the corresponding state data in its **local in-memory cache**
3. After Google authenticates the user, the callback hits **instance B**
4. Instance B tries to read the state data from its **local in-memory cache** — but it's not there
5. The OIDC authentication fails with a correlation error

The default `IDistributedCache` implementation in ASP.NET Core is `MemoryDistributedCache`, which is **in-process only** and not actually distributed. For multi-instance deployments, you must replace it with a truly distributed implementation.

## Solution: Configure Redis Distributed Cache

```csharp
using Duende.IdentityServer;

var builder = WebApplication.CreateBuilder(args);

// Configure a REAL distributed cache (not the default in-memory)
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

## Features That Require Distributed Cache

IdentityServer uses `IDistributedCache` for several features. All of these will fail or behave incorrectly in a multi-instance deployment without a shared cache:

| Feature | Why It Needs Distributed Cache |
|---------|-------------------------------|
| **OIDC state data formatter** | Stores external provider state server-side instead of in the URL. State created on instance A can't be validated on instance B without shared cache. |
| **JWT replay cache** | Prevents JWT client credential replay attacks. Without shared cache, a replayed JWT might hit a different instance that hasn't seen it. |
| **Device flow throttling** | Rate-limits polling across instances. Without shared cache, each instance tracks polling independently. |
| **PAR authorization parameter store** | Stores Pushed Authorization Request data. Without shared cache, the authorization endpoint on instance B can't find PAR data created on instance A. |

## Important: Do NOT Use MemoryDistributedCache

The default `MemoryDistributedCache` is **not suitable for multi-instance deployments**. It stores data in the local process memory of each instance. You must use a shared implementation:

- **`AddStackExchangeRedisCache`** — Redis (recommended for most deployments)
- **`AddSqlServerCache`** — SQL Server
- **`AddCosmosCache`** — Azure Cosmos DB
- **`AddNMemoryCache`** — NCache

Ensure the cache storage itself is durable (e.g., Redis with persistence enabled).
