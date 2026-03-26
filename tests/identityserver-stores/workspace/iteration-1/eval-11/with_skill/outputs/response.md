# Separate Databases with Custom Schemas

## Updated Program.cs

```csharp
var configConnectionString = builder.Configuration.GetConnectionString("ConfigDb");
var opsConnectionString = builder.Configuration.GetConnectionString("OpsDb");
var migrationsAssembly = typeof(Program).Assembly.GetName().Name;

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
```

## Updated appsettings.json

```json
{
  "ConnectionStrings": {
    "IdentityServer": "Server=localhost;Database=IdentityServerDb;Trusted_Connection=True;MultipleActiveResultSets=true;TrustServerCertificate=True",
    "ConfigDb": "Server=localhost;Database=IdentityServer_Config;Trusted_Connection=True;TrustServerCertificate=True",
    "OpsDb": "Server=localhost;Database=IdentityServer_Ops;Trusted_Connection=True;TrustServerCertificate=True"
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