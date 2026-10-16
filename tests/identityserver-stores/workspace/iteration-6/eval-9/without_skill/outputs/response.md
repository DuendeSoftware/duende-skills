```csharp
using Duende.IdentityServer.Stores;

public class RedisPersistedGrantStore : IPersistedGrantStore
{
    // Implement: StoreAsync, GetAsync(key), GetAllAsync(filter), RemoveAsync(key), RemoveAllAsync(filter)
}

public class RedisDeviceFlowStore : IDeviceFlowStore
{
    // Implement: StoreDeviceAuthorizationAsync, FindByUserCodeAsync, FindByDeviceCodeAsync,
    // UpdateByUserCodeAsync, RemoveByDeviceCodeAsync
}
```

Registration (don't call `AddOperationalStore`):
```csharp
builder.Services.AddSingleton<IConnectionMultiplexer>(
    ConnectionMultiplexer.Connect(builder.Configuration["Redis:ConnectionString"]!));

builder.Services.AddIdentityServer()
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddPersistedGrantStore<RedisPersistedGrantStore>()
    .AddDeviceFlowStore<RedisDeviceFlowStore>();
```
Redis should use key TTLs from `Expiration` to expire entries rather than a cleanup job, and `GetAllAsync`/`RemoveAllAsync` need secondary indexes (e.g. sets per subject/client/session).
