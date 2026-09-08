Since you're on IdentityServer v8, the configuration store cache is backed by Microsoft's `HybridCache` rather than the legacy `ICache<T>`. To make the cache shared across all 4 nodes, give `HybridCache` a distributed (Redis) L2 backend via `AddStackExchangeRedisCache`, then enable the configuration store cache and set the client/resource expirations to 10 minutes through `IdentityServerOptions.Caching`.

## Program.cs

```csharp
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

var migrationsAssembly = typeof(Program).Assembly.GetName().Name;
var connectionString = builder.Configuration.GetConnectionString("IdentityServer");

// Distributed backend for HybridCache so all 4 nodes share cached config data.
builder.Services.AddHybridCache();
builder.Services.AddStackExchangeRedisCache(options =>
    options.Configuration = builder.Configuration["Redis:ConnectionString"]);

builder.Services.AddIdentityServer(options =>
    {
        // 10-minute cache windows for clients and resources.
        options.Caching.ClientStoreExpiration = TimeSpan.FromMinutes(10);
        options.Caching.ResourceStoreExpiration = TimeSpan.FromMinutes(10);
    })
    .AddConfigurationStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString, sql =>
                sql.MigrationsAssembly(migrationsAssembly));
    })
    .AddConfigurationStoreCache(); // wraps the EF config stores with HybridCache

var app = builder.Build();

app.UseIdentityServer();
app.MapGet("/", () => "IdentityServer is running");
app.Run();
```

### Why this achieves a shared cache across nodes

- **`AddConfigurationStoreCache()`** wraps the EF `IClientStore`/`IResourceStore`/CORS stores with a caching decorator. In v8 that decorator is backed by `HybridCache`.
- **`AddHybridCache()` + `AddStackExchangeRedisCache(...)`** gives `HybridCache` a distributed L2 layer. Redis is populated from `Redis:ConnectionString` in `appsettings.json`. Because the L2 is Redis, every node reads from and writes to the same cache — a client update no longer leaves stale entries on the other three nodes the way a purely node-local `IMemoryCache` would.
- **`options.Caching.ClientStoreExpiration` / `ResourceStoreExpiration = TimeSpan.FromMinutes(10)`** controls the cache lifetime for clients and resources.

> There is no built-in cache-invalidation webhook. After a client or resource change, either evict the entry explicitly or accept eventual consistency bounded by the 10-minute expiration.

> **Version note:** On IdentityServer v7 or earlier there was no `HybridCache`; the distributed-cache recipe there swapped the legacy `ICache<T>` registration for a distributed decorator. On v8 (your target) the `HybridCache` + Redis L2 approach shown above is the correct mechanism and supersedes that older pattern.
