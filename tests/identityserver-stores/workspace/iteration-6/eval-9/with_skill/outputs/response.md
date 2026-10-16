Don't call `AddOperationalStore()`; register your stores directly:

```csharp
builder.Services.AddSingleton<IConnectionMultiplexer>(
    ConnectionMultiplexer.Connect(builder.Configuration["Redis:ConnectionString"]!));

builder.Services.AddIdentityServer()
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryIdentityResources(Config.IdentityResources);

builder.Services.AddTransient<IPersistedGrantStore, RedisPersistedGrantStore>();
builder.Services.AddTransient<IDeviceFlowStore, RedisDeviceFlowStore>();
```

Sketch (v8 signatures with `CancellationToken`; drop for v7):
```csharp
public sealed class RedisPersistedGrantStore : IPersistedGrantStore
{
    private readonly IDatabase _redis;
    public RedisPersistedGrantStore(IConnectionMultiplexer mux) => _redis = mux.GetDatabase();

    public async Task StoreAsync(PersistedGrant grant, CancellationToken ct = default)
    {
        var expiry = grant.Expiration.HasValue ? grant.Expiration.Value - DateTime.UtcNow : TimeSpan.FromDays(30);
        await _redis.StringSetAsync(grant.Key, JsonSerializer.Serialize(grant), expiry);
        // also add to subject/client/session index sets for filtered queries
    }

    public async Task<PersistedGrant?> GetAsync(string key, CancellationToken ct = default)
    {
        var v = await _redis.StringGetAsync(key);
        return v.IsNull ? null : JsonSerializer.Deserialize<PersistedGrant>(v!);
    }

    public Task<IEnumerable<PersistedGrant>> GetAllAsync(PersistedGrantFilter filter, CancellationToken ct = default)
        => throw new NotImplementedException("Implement with a subject-keyed index");

    public Task RemoveAsync(string key, CancellationToken ct = default) => _redis.KeyDeleteAsync(key);

    public Task RemoveAllAsync(PersistedGrantFilter filter, CancellationToken ct = default)
        => throw new NotImplementedException("Implement with a subject-keyed index");
}

public sealed class RedisDeviceFlowStore : IDeviceFlowStore
{
    // StoreDeviceAuthorizationAsync(deviceCode, data), FindByUserCodeAsync, FindByDeviceCodeAsync,
    // UpdateByUserCodeAsync, RemoveByDeviceCodeAsync — index by both user code and device code.
}
```
All interface methods must be implemented. Redis needs secondary indexes for filter queries; use key TTLs for expiry. Since you bypass the EF store, the built-in token cleanup doesn't apply. Signing keys (`ISigningKeyStore`) and server-side sessions also default elsewhere, so register stores for those if you need them shared across nodes. Data in grants is protected via Data Protection; share those keys across nodes.
