Here's how to split the configuration and operational stores across two databases (`ConfigDb` and `OpsDb`), each using its own schema and custom migration history table.

## appsettings.json

Add both connection strings under `ConnectionStrings`:

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

## Program.cs

```csharp
var builder = WebApplication.CreateBuilder(args);

var migrationsAssembly = typeof(Program).Assembly.GetName().Name;
var configDb = builder.Configuration.GetConnectionString("ConfigDb");
var opsDb = builder.Configuration.GetConnectionString("OpsDb");

builder.Services.AddIdentityServer()
    .AddConfigurationStore(options =>
    {
        options.DefaultSchema = "config";
        options.ConfigureDbContext = b =>
            b.UseSqlServer(configDb, sql =>
            {
                sql.MigrationsAssembly(migrationsAssembly);
                sql.MigrationsHistoryTable("__ConfigMigrationsHistory", "config");
            });
    })
    .AddOperationalStore(options =>
    {
        options.DefaultSchema = "ops";
        options.ConfigureDbContext = b =>
            b.UseSqlServer(opsDb, sql =>
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

### Notes

- The configuration store uses the **`ConfigDb`** connection string and the operational store uses **`OpsDb`**, so they target two separate databases.
- **`DefaultSchema`** is `config` for configuration tables and `ops` for operational tables.
- **`MigrationsHistoryTable(name, schema)`** gives each context a dedicated history table in its own schema.
- Generate migrations per context (`-c ConfigurationDbContext` and `-c PersistedGrantDbContext`) and run `database update` for each against its database.
