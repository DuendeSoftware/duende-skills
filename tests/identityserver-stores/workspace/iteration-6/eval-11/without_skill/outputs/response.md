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
var configCs = builder.Configuration.GetConnectionString("ConfigDb");
var opsCs = builder.Configuration.GetConnectionString("OpsDb");
var asm = typeof(Program).Assembly.GetName().Name;

builder.Services.AddIdentityServer()
    .AddConfigurationStore(options =>
    {
        options.DefaultSchema = "config";
        options.ConfigureDbContext = b => b.UseSqlServer(configCs,
            sql => sql.MigrationsAssembly(asm)
                      .MigrationsHistoryTable("__EFMigrationsHistory", "config"));
    })
    .AddOperationalStore(options =>
    {
        options.DefaultSchema = "ops";
        options.ConfigureDbContext = b => b.UseSqlServer(opsCs,
            sql => sql.MigrationsAssembly(asm)
                      .MigrationsHistoryTable("__EFMigrationsHistory", "ops"));
    });
```

Migrations:
```bash
dotnet ef migrations add InitialConfig -c ConfigurationDbContext -o Migrations/ConfigurationDb
dotnet ef migrations add InitialGrants -c PersistedGrantDbContext -o Migrations/PersistedGrantDb
dotnet ef database update -c ConfigurationDbContext
dotnet ef database update -c PersistedGrantDbContext
```
