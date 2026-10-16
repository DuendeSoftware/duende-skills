```csharp
using Duende.IdentityServer.Models;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

var connectionString = builder.Configuration.GetConnectionString("IdentityServer");
var migrationsAssembly = typeof(Program).Assembly.GetName().Name;

builder.Services.AddIdentityServer()
    .AddConfigurationStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString, sql => sql.MigrationsAssembly(migrationsAssembly));
    })
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString, sql => sql.MigrationsAssembly(migrationsAssembly));

        options.EnableTokenCleanup = true;
        options.TokenCleanupInterval = 1800; // seconds = 30 minutes
    });

var app = builder.Build();
app.UseIdentityServer();
app.MapGet("/", () => "IdentityServer is running");
app.Run();
```

**Why migrations work:** `MigrationsAssembly` points at the host project. Without it EF looks in `Duende.IdentityServer.EntityFramework.dll` and fails to find migrations. Generate them in the host:

```shell
dotnet ef migrations add InitialIdentityServerConfigurationDb \
  --context ConfigurationDbContext --output-dir Data/Migrations/IdentityServer/ConfigurationDb
dotnet ef migrations add InitialIdentityServerOperationalDb \
  --context PersistedGrantDbContext --output-dir Data/Migrations/IdentityServer/OperationalDb
```

**Cleanup:** `TokenCleanupInterval` is in seconds (default 3600), so 1800 = 30 minutes. `FuzzTokenCleanupStart` defaults to true, which helps with multi-node races. Apply migrations through a deployment step rather than at app startup in multi-node production. (On 8.1 preview, `AddConfigurationStore`/`AddOperationalStore` are obsolete in favor of `AddEntityFrameworkConfigurationStore`/`AddEntityFrameworkOperationalStore`.)
