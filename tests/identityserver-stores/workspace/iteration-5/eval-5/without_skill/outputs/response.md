To share the configuration store cache across all 4 nodes, back IdentityServer's cache with Redis (a distributed cache) instead of the default in-memory cache. IdentityServer's configuration store caching goes through the `ICache<T>` abstraction; you replace the default in-memory implementation with the built-in `DistributedCache<T>`, which reads/writes through `IDistributedCache` (Redis).

## Program.cs

```csharp
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Services;

var builder = WebApplication.CreateBuilder(args);

var connectionString = builder.Configuration.GetConnectionString("IdentityServer");
var migrationsAssembly = typeof(Program).Assembly.GetName().Name;

// 1. Register Redis as the distributed cache.
builder.Services.AddStackExchangeRedisCache(options =>
{
    options.Configuration = builder.Configuration["Redis:ConnectionString"];
});

// 2. Replace the default in-memory ICache<> with the distributed cache implementation,
//    so all nodes share the same cached configuration data.
builder.Services.AddSingleton(typeof(ICache<>), typeof(DistributedCache<>));

builder.Services.AddIdentityServer(options =>
    {
        // 3. 10-minute expiration for clients and resources.
        options.Caching.ClientStoreExpiration = TimeSpan.FromMinutes(10);
        options.Caching.ResourceStoreExpiration = TimeSpan.FromMinutes(10);
    })
    .AddConfigurationStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString, sql =>
                sql.MigrationsAssembly(migrationsAssembly));
    })
    .AddConfigurationStoreCache(); // enable caching for the EF configuration store

var app = builder.Build();

app.UseIdentityServer();
app.MapGet("/", () => "IdentityServer is running");
app.Run();
```

### How it works

1. **`AddStackExchangeRedisCache`** registers Redis as the `IDistributedCache`, using the connection string from `Redis:ConnectionString` in `appsettings.json`.
2. **`AddSingleton(typeof(ICache<>), typeof(DistributedCache<>))`** swaps IdentityServer's default node-local `ICache<T>` for `DistributedCache<T>`, which stores cached entries in Redis. This is the key step that makes all 4 nodes see the same cached values, so a client update on one node isn't stale on the others.
3. **`AddConfigurationStoreCache()`** turns on caching for the EF configuration store (clients, resources, CORS).
4. **`ClientStoreExpiration` / `ResourceStoreExpiration = TimeSpan.FromMinutes(10)`** sets the 10-minute cache lifetime for clients and resources.
