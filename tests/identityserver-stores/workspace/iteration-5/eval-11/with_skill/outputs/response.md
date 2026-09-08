Here the two stores point at separate databases (`ConfigDb` and `OpsDb`), each in its own schema (`config` and `ops`), with a custom migration history table per schema.

## appsettings.json

```json
{
  "ConnectionStrings": {
    "ConfigDb": "Server=localhost;Database=IdentityServerConfig;Trusted_Connection=True;MultipleActiveResultSets=true;TrustServerCertificate=True",
    "OpsDb": "Server=localhost;Database=IdentityServerOps;Trusted_Connection=True;MultipleActiveResultSets=true;TrustServerCertificate=True"
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

### How it fits together

- **Separate connection strings** — `GetConnectionString("ConfigDb")` and `GetConnectionString("OpsDb")` resolve to two distinct databases, so configuration and operational data live in different SQL Server databases.
- **`DefaultSchema`** — `config` for the configuration tables and `ops` for the operational tables, keeping object names tidy within each database.
- **`MigrationsHistoryTable(name, schema)`** — each context tracks its migration history in its own schema (`__ConfigMigrationsHistory` in `config`, `__OpsMigrationsHistory` in `ops`) instead of the default `dbo.__EFMigrationsHistory`.
- **`MigrationsAssembly`** — both contexts resolve migrations from this host project.

### Migrations (each context targets its own database)

```shell
dotnet ef migrations add InitialConfig -c ConfigurationDbContext -o Data/Migrations/Config
dotnet ef migrations add InitialOps    -c PersistedGrantDbContext -o Data/Migrations/Ops

dotnet ef database update -c ConfigurationDbContext
dotnet ef database update -c PersistedGrantDbContext
```
