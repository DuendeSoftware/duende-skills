# Setting Up Redis Distributed Cache for IdentityServer

To share cached configuration data across your 4 load-balanced nodes, you should use Redis as a distributed cache. Here's how to set it up:

First, install the Redis caching NuGet package:

```bash
dotnet add package Microsoft.Extensions.Caching.StackExchangeRedis
```

Then update `Program.cs`:

```csharp
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

var migrationsAssembly = typeof(Program).Assembly.GetName().Name;
var connectionString = builder.Configuration.GetConnectionString("IdentityServer");

// Add Redis distributed cache
builder.Services.AddStackExchangeRedisCache(options =>
{
    options.Configuration = builder.Configuration["Redis:ConnectionString"];
});

builder.Services.AddIdentityServer()
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
    .AddConfigurationStoreCache();

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

This sets up Redis as the distributed cache backend and enables configuration store caching so that client and resource lookups are cached. The `AddConfigurationStoreCache()` method wraps the EF Core stores with a caching layer.

All nodes will share the same Redis-backed cache, so when a client is loaded on one node, other nodes will also benefit from the cached data.
