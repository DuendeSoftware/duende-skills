When you back operational data with Redis, you replace the EF operational store entirely. The custom `IPersistedGrantStore` and `IDeviceFlowStore` implementations are registered **directly in the DI container** (not through an IdentityServer builder helper), and you simply omit `AddOperationalStore()`.

## Program.cs

```csharp
using Duende.IdentityServer.Stores;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer()
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryIdentityResources(Config.IdentityResources);
    // NOTE: no AddOperationalStore(...) — Redis stores replace it.

// Register the custom Redis-backed operational stores directly.
builder.Services.AddTransient<IPersistedGrantStore, RedisPersistedGrantStore>();
builder.Services.AddTransient<IDeviceFlowStore, RedisDeviceFlowStore>();

var app = builder.Build();

app.UseIdentityServer();
app.MapGet("/", () => "IdentityServer is running");
app.Run();
```

### Why it's done this way

- **Custom operational stores are registered on `builder.Services` directly** with `AddTransient` (or `AddScoped`), overriding the defaults. There is no `AddPersistedGrantStore<T>()` builder helper the way there is for client/resource stores — you register the interface-to-implementation mapping yourself.
- **`AddOperationalStore()` is removed.** It would register the EF-backed `IPersistedGrantStore`, `IDeviceFlowStore`, `ISigningKeyStore`, and `IServerSideSessionStore` against `PersistedGrantDbContext`, which you don't want when Redis owns that data.
- **`AddIdentityServer()` is still called** — it registers the core IdentityServer services and the configuration stores. Only the operational persistence is swapped out.

> Two things to keep in mind when going fully Redis for operational data:
> - **Signing keys:** `AddOperationalStore()` normally also provides the EF `ISigningKeyStore`. Without it, automatic key management falls back to the file-system store (single-node only). For multi-node, implement a custom `ISigningKeyStore` (e.g., Redis) and register it via `.AddSigningKeyStore<RedisSigningKeyStore>()`.
> - **Filtered queries:** `IPersistedGrantStore.GetAllAsync`/`RemoveAllAsync` take a `PersistedGrantFilter`. Redis needs a secondary index (e.g., a SET keyed by `subjectId`) to satisfy those, since it can't query by arbitrary fields.
