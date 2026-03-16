# Redis Distributed Cache for IdentityServer Configuration Store

To use Redis as a distributed cache across all 4 nodes, you need to:

1. Register `AddStackExchangeRedisCache` with the Redis connection string
2. Replace the default `ICache<T>` with `DistributedCache<T>` so all nodes share the same cache
3. Enable configuration store caching with expiration settings

Here's the updated `Program.cs`:

```csharp
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Services;

var builder = WebApplication.CreateBuilder(args);

var migrationsAssembly = typeof(Program).Assembly.GetName().Name;
var connectionString = builder.Configuration.GetConnectionString("IdentityServer");

// Register Redis as the distributed cache
builder.Services.AddStackExchangeRedisCache(options =>
{
    options.Configuration = builder.Configuration["Redis:ConnectionString"];
});

// Replace the default ICache<T> with a distributed implementation
builder.Services.AddSingleton(typeof(ICache<>), typeof(DistributedCache<>));

builder.Services.AddIdentityServer(options =>
{
    options.Caching.ClientStoreExpiration = TimeSpan.FromMinutes(10);
    options.Caching.ResourceStoreExpiration = TimeSpan.FromMinutes(10);
    options.Caching.CorsExpiration = TimeSpan.FromMinutes(10);
})
    .AddConfigurationStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString, sql =>
                sql.MigrationsAssembly(migrationsAssembly));
    })
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString, sql =>
                sql.MigrationsAssembly(migrationsAssembly));
        options.EnableTokenCleanup = true;
    })
    .AddConfigurationStoreCache(); // Wraps EF config stores with ICache<T>

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

**Key points:**

- `AddStackExchangeRedisCache` registers `IDistributedCache` backed by Redis, so all 4 nodes share the same cache entries.
- `AddSingleton(typeof(ICache<>), typeof(DistributedCache<>))` replaces the default in-memory `ICache<T>` with a distributed implementation that uses `IDistributedCache` under the hood. This is critical — without this, each node would cache independently in local memory.
- `AddConfigurationStoreCache()` wraps the EF configuration store with caching decorators that use the registered `ICache<T>`.
- Cache expirations are set to 10 minutes via `IdentityServerOptions.Caching`. After a client or resource update, all nodes will pick up the change within 10 minutes.

> **Note:** There is no built-in cache invalidation webhook. After updating a client or resource, either explicitly evict the cache entry or wait for the 10-minute expiration.
