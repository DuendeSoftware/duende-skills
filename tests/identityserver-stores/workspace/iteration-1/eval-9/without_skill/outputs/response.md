# Custom Redis Stores for IdentityServer

To use your custom Redis-backed stores, you need to register them with IdentityServer. Here's how:

```csharp
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Stores;

var builder = WebApplication.CreateBuilder(args);

var connectionString = builder.Configuration.GetConnectionString("IdentityServer");
var migrationsAssembly = typeof(Program).Assembly.GetName().Name;

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
    });

// Override with custom Redis stores
builder.Services.AddTransient<IPersistedGrantStore, RedisPersistedGrantStore>();
builder.Services.AddTransient<IDeviceFlowStore, RedisDeviceFlowStore>();

var app = builder.Build();

app.UseIdentityServer();
app.MapGet("/", () => "IdentityServer is running");
app.Run();
```

By registering your custom stores after the default registrations, the DI container will resolve your Redis implementations instead of the EF Core ones. The `AddTransient` registrations override the ones set up by `AddOperationalStore`.
