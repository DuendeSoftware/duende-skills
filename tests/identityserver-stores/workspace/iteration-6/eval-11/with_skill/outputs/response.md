**appsettings.json**
```json
{
  "ConnectionStrings": {
    "ConfigDb": "Server=localhost;Database=IdentityServerConfigDb;Trusted_Connection=True;MultipleActiveResultSets=true;TrustServerCertificate=True",
    "OpsDb": "Server=localhost;Database=IdentityServerOpsDb;Trusted_Connection=True;MultipleActiveResultSets=true;TrustServerCertificate=True"
  },
  "Redis": { "ConnectionString": "localhost:6379" },
  "Logging": { "LogLevel": { "Default": "Information", "Microsoft.AspNetCore": "Warning" } },
  "AllowedHosts": "*"
}
```

**Program.cs**
```csharp
var configConnection = builder.Configuration.GetConnectionString("ConfigDb");
var opsConnection = builder.Configuration.GetConnectionString("OpsDb");
var migrationsAssembly = typeof(Program).Assembly.GetName().Name;

builder.Services.AddIdentityServer()
    .AddConfigurationStore(options =>
    {
        options.DefaultSchema = "config";
        options.ConfigureDbContext = b =>
            b.UseSqlServer(configConnection, sql =>
            {
                sql.MigrationsAssembly(migrationsAssembly);
                sql.MigrationsHistoryTable("__ConfigMigrationsHistory", "config");
            });
    })
    .AddOperationalStore(options =>
    {
        options.DefaultSchema = "ops";
        options.ConfigureDbContext = b =>
            b.UseSqlServer(opsConnection, sql =>
            {
                sql.MigrationsAssembly(migrationsAssembly);
                sql.MigrationsHistoryTable("__OperationalMigrationsHistory", "ops");
            });
        options.EnableTokenCleanup = true;
    });
```

Migrations (in the host project):
```shell
dotnet ef migrations add InitialIdentityServerConfigurationDb \
  --context ConfigurationDbContext --output-dir Data/Migrations/IdentityServer/ConfigurationDb
dotnet ef migrations add InitialIdentityServerOperationalDb \
  --context PersistedGrantDbContext --output-dir Data/Migrations/IdentityServer/OperationalDb
```
Because the databases are separate, each context's migration history lives in its own database and schema. Apply each against its own connection (`dotnet ef database update --context ...`).
