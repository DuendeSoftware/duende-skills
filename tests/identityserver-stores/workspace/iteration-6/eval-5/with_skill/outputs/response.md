In v8, `ICache<T>` is replaced by Microsoft **HybridCache**, which `AddConfigurationStoreCache()` uses. Back it with Redis via `IDistributedCache` so all 4 nodes share the cache:

```csharp
var connectionString = builder.Configuration.GetConnectionString("IdentityServer");
var migrationsAssembly = typeof(Program).Assembly.GetName().Name;

builder.Services.AddHybridCache();
builder.Services.AddStackExchangeRedisCache(options =>
    options.Configuration = builder.Configuration["Redis:ConnectionString"]);

builder.Services.AddIdentityServer(options =>
    {
        options.Caching.ClientStoreExpiration = TimeSpan.FromMinutes(10);
        options.Caching.ResourceStoreExpiration = TimeSpan.FromMinutes(10);
    })
    .AddConfigurationStore(options =>
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString, sql => sql.MigrationsAssembly(migrationsAssembly)))
    .AddConfigurationStoreCache();
```

Add `Microsoft.Extensions.Caching.StackExchangeRedis` and `Microsoft.Extensions.Caching.Hybrid` packages. Notes:
- No custom `ICache<T>` is needed; if you have one from v7, migrate to HybridCache (keyed service `ServiceProviderKeys.ConfigurationStoreCache`).
- There's no built-in invalidation: after changing a client/resource, evict the entry or wait up to 10 minutes.
- Optionally set `options.Caching.CorsExpiration` too.
