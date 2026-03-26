# Setting Up EF Core Configuration and Operational Stores

## Updated Program.cs

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

// Config class unchanged...
```

## Key Points

- **`AddConfigurationStore`** — Stores clients, API scopes, identity resources, and CORS policies in SQL Server via `ConfigurationDbContext`
- **`AddOperationalStore`** — Stores persisted grants (tokens, codes, consent), device codes, signing keys, and sessions via `PersistedGrantDbContext`
- **`MigrationsAssembly`** — Must be set to the host project assembly since that's where EF migrations will live. Without this, EF Core looks for migrations in the `Duende.IdentityServer.EntityFramework` assembly and fails.
- **Token cleanup** — `EnableTokenCleanup = true` with `TokenCleanupInterval = 1800` runs cleanup every 30 minutes

## Next Steps

Create migrations:
```bash
dotnet ef migrations add InitConfig -c ConfigurationDbContext -o Data/Migrations/ConfigurationDb
dotnet ef migrations add InitOps -c PersistedGrantDbContext -o Data/Migrations/OperationalDb
dotnet ef database update -c ConfigurationDbContext
dotnet ef database update -c PersistedGrantDbContext
```