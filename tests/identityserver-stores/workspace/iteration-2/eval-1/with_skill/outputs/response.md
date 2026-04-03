# Setting Up EF Core Configuration and Operational Stores

## Updated Program.cs

```csharp
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

var migrationsAssembly = typeof(Program).Assembly.GetName().Name;
var connectionString = builder.Configuration.GetConnectionString("IdentityServer");

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

        // Enable token cleanup every 30 minutes (1800 seconds)
        options.EnableTokenCleanup = true;
        options.TokenCleanupInterval = 1800;
    });

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## Key Points

- **`AddConfigurationStore`** registers the EF Core-backed configuration store (`IClientStore`, `IResourceStore`, `ICorsPolicyService`, `IIdentityProviderStore`)
- **`AddOperationalStore`** registers the EF Core-backed operational store (`IPersistedGrantStore`, `IDeviceFlowStore`, `ISigningKeyStore`, `IServerSideSessionStore`)
- **`MigrationsAssembly`** must be set to the host project assembly so EF Core can find the migrations. Without this, `dotnet ef migrations add` will fail.
- **`EnableTokenCleanup = true`** enables a background service that periodically removes expired grants
- **`TokenCleanupInterval = 1800`** sets the cleanup interval to 30 minutes (1800 seconds)
- The connection string is read from `appsettings.json` via `builder.Configuration.GetConnectionString("IdentityServer")`
