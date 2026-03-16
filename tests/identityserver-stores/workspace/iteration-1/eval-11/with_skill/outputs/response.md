# Separate Databases for Configuration and Operational Stores

Here's how to configure each store to use its own database, schema, and migration history table.

## Updated appsettings.json

```json
{
  "ConnectionStrings": {
    "IdentityServer": "Server=localhost;Database=IdentityServerDb;Trusted_Connection=True;MultipleActiveResultSets=true;TrustServerCertificate=True",
    "ConfigDb": "Server=localhost;Database=IdentityServer_Config;Trusted_Connection=True;MultipleActiveResultSets=true;TrustServerCertificate=True",
    "OpsDb": "Server=localhost;Database=IdentityServer_Operational;Trusted_Connection=True;MultipleActiveResultSets=true;TrustServerCertificate=True"
  },
  "Redis": {
    "ConnectionString": "localhost:6379"
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "AllowedHosts": "*"
}
```

## Updated Program.cs

```csharp
using Duende.IdentityServer.Models;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

var migrationsAssembly = typeof(Program).Assembly.GetName().Name;

var configConnectionString = builder.Configuration.GetConnectionString("ConfigDb");
var opsConnectionString = builder.Configuration.GetConnectionString("OpsDb");

builder.Services.AddIdentityServer()
    .AddConfigurationStore(options =>
    {
        options.DefaultSchema = "config";
        options.ConfigureDbContext = b =>
            b.UseSqlServer(configConnectionString, sql =>
            {
                sql.MigrationsAssembly(migrationsAssembly);
                sql.MigrationsHistoryTable("__ConfigMigrationsHistory", "config");
            });
    })
    .AddOperationalStore(options =>
    {
        options.DefaultSchema = "ops";
        options.ConfigureDbContext = b =>
            b.UseSqlServer(opsConnectionString, sql =>
            {
                sql.MigrationsAssembly(migrationsAssembly);
                sql.MigrationsHistoryTable("__OperationalMigrationsHistory", "ops");
            });
        options.EnableTokenCleanup = true;
    });

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

**Key points:**

- **Separate connection strings**: `ConfigDb` for configuration data, `OpsDb` for operational data. Each points to a different database.
- **Custom schemas**: `config` for configuration tables, `ops` for operational tables. This provides clear namespace separation even though they're in different databases.
- **Migration history tables**: Each store gets its own migration history table in its respective schema — `__ConfigMigrationsHistory` in `config` and `__OperationalMigrationsHistory` in `ops`. This prevents any migration tracking collisions.
- **MigrationsAssembly**: Both stores point to the host project assembly so EF Core can find the migrations.

To create the initial migrations, run:

```shell
dotnet ef migrations add InitialConfig \
  --context ConfigurationDbContext \
  --output-dir Data/Migrations/ConfigurationDb

dotnet ef migrations add InitialOps \
  --context PersistedGrantDbContext \
  --output-dir Data/Migrations/OperationalDb
```
