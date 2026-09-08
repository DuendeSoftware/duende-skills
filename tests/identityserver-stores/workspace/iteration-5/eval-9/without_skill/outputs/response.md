To use your Redis-backed operational stores instead of the EF Core operational store, register the custom implementations against the IdentityServer store interfaces in DI and drop `AddOperationalStore()`.

## Program.cs

```csharp
using Duende.IdentityServer.Stores;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer()
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryIdentityResources(Config.IdentityResources);

// Custom Redis operational stores replace the EF operational store.
builder.Services.AddTransient<IPersistedGrantStore, RedisPersistedGrantStore>();
builder.Services.AddTransient<IDeviceFlowStore, RedisDeviceFlowStore>();

var app = builder.Build();

app.UseIdentityServer();
app.MapGet("/", () => "IdentityServer is running");
app.Run();
```

### Explanation

- **`AddTransient<IPersistedGrantStore, RedisPersistedGrantStore>()`** and **`AddTransient<IDeviceFlowStore, RedisDeviceFlowStore>()`** register your Redis implementations. Because these are added after `AddIdentityServer()`, they take precedence over any defaults for those interfaces.
- **No `AddOperationalStore()`** call is present — the EF Core operational store is intentionally not registered, since Redis now handles persisted grants and device flow codes.
- **`AddIdentityServer()`** is still called to register the core services and (here) the in-memory configuration stores. You're only swapping the operational persistence layer.

Keep in mind that `AddOperationalStore()` also provides the signing-key store and server-side session store. If you rely on automatic key management across multiple nodes, you'll also need a shared `ISigningKeyStore` implementation (e.g., Redis) registered the same way.
