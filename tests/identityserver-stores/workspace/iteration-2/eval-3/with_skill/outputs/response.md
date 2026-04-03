# Separate Database Schemas for EF Core Stores

## Updated Program.cs

```csharp
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

var migrationsAssembly = typeof(Program).Assembly.GetName().Name;
var connectionString = builder.Configuration.GetConnectionString("IdentityServer");

builder.Services.AddIdentityServer()
    .AddConfigurationStore(options =>
    {
        options.DefaultSchema = "idscfg";
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString, sql =>
            {
                sql.MigrationsAssembly(migrationsAssembly);
                sql.MigrationsHistoryTable("__ConfigMigrationsHistory", "idscfg");
            });
    })
    .AddOperationalStore(options =>
    {
        options.DefaultSchema = "idsop";
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString, sql =>
            {
                sql.MigrationsAssembly(migrationsAssembly);
                sql.MigrationsHistoryTable("__OperationalMigrationsHistory", "idsop");
            });
    });

var app = builder.Build();

app.UseIdentityServer();
app.MapGet("/", () => "IdentityServer is running");
app.Run();
```

## Key Points

- **`DefaultSchema = "idscfg"`** — all configuration tables (Clients, ApiScopes, etc.) are created in the `idscfg` schema
- **`DefaultSchema = "idsop"`** — all operational tables (PersistedGrants, DeviceCodes, etc.) are created in the `idsop` schema
- **`MigrationsHistoryTable`** — places the EF migration history table in the respective schema, keeping everything isolated
- **`MigrationsAssembly`** — must point to the host project for migrations to work
