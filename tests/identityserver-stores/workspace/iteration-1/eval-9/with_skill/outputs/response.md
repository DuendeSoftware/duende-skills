# Registering Custom Redis Operational Stores

When using custom `IPersistedGrantStore` and `IDeviceFlowStore` implementations backed by Redis, you register them directly via the DI container instead of using `AddOperationalStore()`. The EF Core operational store is not needed.

## Updated Program.cs

```csharp
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Stores;

var builder = WebApplication.CreateBuilder(args);

var migrationsAssembly = typeof(Program).Assembly.GetName().Name;
var connectionString = builder.Configuration.GetConnectionString("IdentityServer");

// Register IdentityServer core services — no AddOperationalStore needed
builder.Services.AddIdentityServer()
    .AddConfigurationStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString, sql =>
                sql.MigrationsAssembly(migrationsAssembly));
    });

// Register custom operational stores directly via DI
builder.Services.AddTransient<IPersistedGrantStore, RedisPersistedGrantStore>();
builder.Services.AddTransient<IDeviceFlowStore, RedisDeviceFlowStore>();

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

**Key points:**

- `AddIdentityServer()` is still called to register the core IdentityServer services.
- `AddOperationalStore()` is **not** called because we're replacing the EF Core operational stores with custom Redis-backed implementations.
- `RedisPersistedGrantStore` is registered as `IPersistedGrantStore` via `AddTransient`.
- `RedisDeviceFlowStore` is registered as `IDeviceFlowStore` via `AddTransient`.
- Custom operational stores are registered directly through `builder.Services`, not through IdentityServer builder helper methods. The builder helpers (`AddOperationalStore`) specifically set up the EF Core implementation.
- You may also need to register `ISigningKeyStore` and `IServerSideSessionStore` if you need those operational capabilities without the EF store. If automatic key management or server-side sessions are needed, provide custom implementations for those interfaces as well.
