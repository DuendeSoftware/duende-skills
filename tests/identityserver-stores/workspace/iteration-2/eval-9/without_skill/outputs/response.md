# Custom Redis Stores

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer()
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddOperationalStore(options =>
    {
        // Still need operational store configuration
        options.ConfigureDbContext = b => b.UseSqlServer(connectionString);
    });

// Override with custom implementations
builder.Services.AddTransient<IPersistedGrantStore, RedisPersistedGrantStore>();
builder.Services.AddTransient<IDeviceFlowStore, RedisDeviceFlowStore>();

var app = builder.Build();
app.UseIdentityServer();
app.Run();
```

Register your custom stores after the operational store to override the EF implementations.
