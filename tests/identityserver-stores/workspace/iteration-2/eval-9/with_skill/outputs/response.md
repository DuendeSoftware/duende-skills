# Custom Redis-Backed Operational Stores

## Registration — Replace EF Operational Store

When using custom store implementations, you do **not** call `AddOperationalStore()` (which registers the EF Core implementations). Instead, register your custom stores directly in DI.

```csharp
// Program.cs
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

// Core IdentityServer setup (without EF operational store)
builder.Services.AddIdentityServer()
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryIdentityResources(Config.IdentityResources);

// Register custom Redis stores directly
builder.Services.AddTransient<IPersistedGrantStore, RedisPersistedGrantStore>();
builder.Services.AddTransient<IDeviceFlowStore, RedisDeviceFlowStore>();

var app = builder.Build();

app.UseIdentityServer();
app.MapGet("/", () => "IdentityServer is running");
app.Run();
```

## Key Points

- **`AddIdentityServer()`** is still called for core IdentityServer registration
- **`AddOperationalStore()`** is NOT called — it would register the EF Core implementations which would conflict with the custom Redis stores
- **`RedisPersistedGrantStore`** is registered as `IPersistedGrantStore` using `AddTransient`
- **`RedisDeviceFlowStore`** is registered as `IDeviceFlowStore` using `AddTransient`
- For custom operational stores, register directly via `builder.Services.AddTransient<>()` instead of using builder helper methods
