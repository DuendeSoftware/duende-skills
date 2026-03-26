# Custom Redis Operational Stores

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer()
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryIdentityResources(Config.IdentityResources);

// Register custom Redis stores — replaces AddOperationalStore()
builder.Services.AddTransient<IPersistedGrantStore, RedisPersistedGrantStore>();
builder.Services.AddTransient<IDeviceFlowStore, RedisDeviceFlowStore>();

var app = builder.Build();
app.UseIdentityServer();
app.Run();
```

Do NOT call `AddOperationalStore()` since that would register EF Core-backed implementations that conflict with your custom Redis stores. Register the custom stores directly in the DI container.