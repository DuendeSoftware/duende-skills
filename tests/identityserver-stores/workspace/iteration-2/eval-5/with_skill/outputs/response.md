# Redis-Backed Distributed Cache for Configuration Store

## Updated Program.cs

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

// Replace the default ICache<T> (in-memory) with a distributed cache implementation
builder.Services.AddSingleton(typeof(ICache<>), typeof(DistributedCache<>));

builder.Services.AddIdentityServer(options =>
{
    // Cache expiration: 10 minutes for clients and resources
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

var app = builder.Build();

app.UseIdentityServer();
app.MapGet("/", () => "IdentityServer is running");
app.Run();
```

## Key Points

- **`AddStackExchangeRedisCache`** — registers Redis as the `IDistributedCache` implementation so all nodes share the same cache
- **`AddSingleton(typeof(ICache<>), typeof(DistributedCache<>))`** — replaces the default in-memory `ICache<T>` with a distributed cache wrapper that uses `IDistributedCache` (Redis)
- **`AddConfigurationStoreCache()`** — wraps the EF configuration store with the caching decorator
- **`ClientStoreExpiration` and `ResourceStoreExpiration`** — both set to 10 minutes
- This ensures all 4 nodes see the same cached data, avoiding stale configuration issues
