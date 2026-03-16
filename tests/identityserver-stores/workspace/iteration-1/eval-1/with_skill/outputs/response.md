# EF Core Configuration and Operational Stores with SQL Server

```csharp
using Duende.IdentityServer.Models;
using Microsoft.EntityFrameworkCore;

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

        options.EnableTokenCleanup = true;
        options.TokenCleanupInterval = 1800; // 30 minutes in seconds
    });

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();

public partial class Program { }
```

**Key points:**
- `AddConfigurationStore` and `AddOperationalStore` both use `UseSqlServer` with the connection string.
- `MigrationsAssembly` is set to the host project assembly (`typeof(Program).Assembly.GetName().Name`) so EF Core knows where to find migrations.
- `EnableTokenCleanup = true` enables automatic cleanup of expired grants.
- `TokenCleanupInterval = 1800` sets cleanup to run every 30 minutes (1800 seconds).
- The connection string is read from `builder.Configuration.GetConnectionString("IdentityServer")`.
