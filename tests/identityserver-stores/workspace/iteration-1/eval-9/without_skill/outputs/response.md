# Custom Redis Stores

```csharp
builder.Services.AddIdentityServer()
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryIdentityResources(Config.IdentityResources);

builder.Services.AddScoped<IPersistedGrantStore, RedisPersistedGrantStore>();
builder.Services.AddScoped<IDeviceFlowStore, RedisDeviceFlowStore>();
```

Register the custom stores directly instead of using AddOperationalStore with EF Core.