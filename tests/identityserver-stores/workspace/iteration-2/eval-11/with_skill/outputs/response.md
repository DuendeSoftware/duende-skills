# Separate Databases for Configuration and Operational Stores

## Updated Program.cs

```csharp
using Duende.IdentityServer.Models;

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
                sql.MigrationsHistoryTable("__OpsMigrationsHistory", "ops");
            });
    });

var app = builder.Build();

app.UseIdentityServer();
app.MapGet("/", () => "IdentityServer is running");
app.Run();
```

## Updated appsettings.json

```json
{
  "ConnectionStrings": {
    "ConfigDb": "Server=localhost;Database=IdentityServer_Config;Trusted_Connection=True;TrustServerCertificate=True",
    "OpsDb": "Server=localhost;Database=IdentityServer_Ops;Trusted_Connection=True;TrustServerCertificate=True"
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

## Key Points

- **Separate databases** — configuration and operational data use different connection strings (`ConfigDb` and `OpsDb`)
- **Custom schemas** — `config` schema for configuration tables, `ops` schema for operational tables
- **Separate migration history tables** — each in its respective schema to avoid conflicts
- **Both stores** use `MigrationsAssembly` pointing to the host project for EF migrations
