# Distributed Redis Cache for Configuration Store

```csharp
var connectionString = builder.Configuration.GetConnectionString("IdentityServer");
var migrationsAssembly = typeof(Program).Assembly.GetName().Name;

// Register Redis as the distributed cache
builder.Services.AddStackExchangeRedisCache(options =>
{
    options.Configuration = builder.Configuration["Redis:ConnectionString"];
});

// Replace the default in-memory ICache<T> with distributed cache
builder.Services.AddSingleton(typeof(Duende.IdentityServer.Services.ICache<>),
    typeof(Duende.IdentityServer.Services.DistributedCache<>));

builder.Services.AddIdentityServer(options =>
{
    options.Caching.ClientStoreExpiration = TimeSpan.FromMinutes(10);
    options.Caching.ResourceStoreExpiration = TimeSpan.FromMinutes(10);
})
    .AddConfigurationStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString, sql =>
                sql.MigrationsAssembly(migrationsAssembly));
    })
    .AddConfigurationStoreCache()
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString, sql =>
                sql.MigrationsAssembly(migrationsAssembly));
    });
```

All 4 nodes will share the same Redis-backed cache, ensuring consistent client/resource data.